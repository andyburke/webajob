#!/usr/bin/perl

use strict;

$| = 1;

use RPC::Lite::Server;
use RPC::Lite::Client;
use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

use Getopt::Long;
use Config::IniFiles;
use Carp;
use File::Spec;
use IO::Socket::INET;

$SIG{INT} = \&HandleSigInt;
$SIG{DIE} = \&HandleSigInt;

my $masterServerAddress = 'localhost';
my $masterServerPort    = 10000;
my $configFilename      = File::Spec->rel2abs('../config/default.ini');
my $doProfiling         = 0;
my $startServers        = 0;

GetOptions(
            'host=s'       => \$masterServerAddress,
            'port=s'       => \$masterServerPort,
            'config=s'     => \$configFilename,
            'profile'      => \$doProfiling,
            'startServers' => \$startServers,
          );

my $masterServer = MasterServer->new(
                                      {
                                        Transport  => RPC::Lite::Transport::TCP->new( { LocalAddr => $masterServerAddress, ListenPort => $masterServerPort } ),
                                        Serializer => RPC::Lite::Serializer::JSON->new(),
                                        Threading => 1,
                                      },
                                      $configFilename,
                                      $doProfiling,
                                    );

my $serverCheckInterval = 3;    # 3 second server status check
my $lastServerCheckTime = 0;

if ($startServers)
{
  $masterServer->StartAllServers();
}

while (1)
{
  my $timeSinceLastServerCheck = time() - $lastServerCheckTime;
  if ( $timeSinceLastServerCheck > $serverCheckInterval )
  {
    $masterServer->CheckServers();
    $lastServerCheckTime = time();
  }

  $masterServer->HandleRequest();
}

sub HandleSigInt
{
  print "Caught sigint, shutting down...\n";
  $masterServer->Shutdown();
  exit;
}

package MasterServer;

use base qw(RPC::Lite::Server);

use Socket;
use Sys::Hostname;
use Time::HiRes qw(sleep);
use POSIX;

sub Servers       { $_[0]->{servers}       = $_[1] if @_ > 1; $_[0]->{servers} }
sub Config        { $_[0]->{config}        = $_[1] if @_ > 1; $_[0]->{config} }
sub Profiling     { $_[0]->{profiling}     = $_[1] if @_ > 1; $_[0]->{profiling} }
sub ServerClients { $_[0]->{serverclients} = $_[1] if @_ > 1; $_[0]->{serverclients} }

sub new
{
  my $class          = shift;
  my $rpcLiteArgs    = shift;
  my $configFilename = shift;
  my $doProfiling    = shift;

  my $self = $class->SUPER::new( $rpcLiteArgs, 1 );    # debug on

  -f $configFilename or die("Config file $configFilename doesn't exist");
  $self->Config( Config::IniFiles->new( -file => $configFilename ) );
  $self->Config or die("Some serious problem creating a Config::IniFiles object: $!");

  $ENV{PERL5LIB} = $self->Config->val( 'global', 'perl5lib' ) . ":$ENV{PERL5LIB}";

  $self->Servers(       {} );
  $self->ServerClients( {} );

  my $port = 10001;                                    # start with the arbitrary port 10001
  foreach my $serverName ( grep { $_ ne 'global' } $self->Config->Sections )
  {
    my $directory = $self->Config->val( $serverName, 'directory' );
    if ( !length($directory) )
    {
      print STDERR "No directory specified in config section\n";
      next;
    }
    $directory = File::Spec->rel2abs($directory);
    if ( !( -d $directory and -r $directory ) )
    {
      print STDERR "Can't access $directory\n";
      next;
    }

    my $executable = $self->Config->val( $serverName, 'executable' );
    if ( !length $executable )
    {
      print STDERR "No executable specified in config section\n";
      next;
    }
    my $exeFullPath = File::Spec->catfile( $directory, $executable );
    if ( !-x $exeFullPath )
    {
      print STDERR "$exeFullPath doesn't exist or isn't executable\n";
      next;
    }

    $self->Servers->{$serverName}->{directory} = $directory;
    $self->Servers->{$serverName}->{exeFullPath} = $exeFullPath;

    my @options;

    my $rpcTransportType = $self->Config->val( $serverName, 'rpcTransportType' );
    $rpcTransportType ||= 'RPC::Lite::Transport::TCP';
    $self->Servers->{$serverName}->{transportType} = $rpcTransportType;
    push @options, "--transportType", $rpcTransportType;
    $self->Servers->{$serverName}->{transportArgs} = {};

    my $rpcSerializerType = $self->Config->val( $serverName, 'rpcSerializerType' );
    $rpcSerializerType ||= 'RPC::Lite::Serializer::JSON';
    $self->Servers->{$serverName}->{serializerType} = $rpcSerializerType;
    push @options, "--serializerType", $rpcSerializerType;
    $self->Servers->{$serverName}->{serializerArgs} = {};

    my $socket;
    do
    {
      $socket = IO::Socket::INET->new(
                                       Proto     => 'tcp',
                                       Listen    => 5,
                                       LocalPort => $port++,
                                     );
    } until ($socket);
    $socket->close;
    $self->Servers->{$serverName}->{port} = $port;

    if ( $rpcTransportType eq 'RPC::Lite::Transport::TCP' )
    {

      # give the transport a port if it's TCP, this might have to be different for HTTP, etc.
      $self->Servers->{$serverName}->{transportArgs}->{ListenPort} = $port;
      push @options, "--transportArg", "ListenPort=" . $self->Servers->{$serverName}->{transportArgs}->{ListenPort};

      $self->Servers->{$serverName}->{transportArgs}->{LocalAddr} = 'localhost';    # FIXME proper hostname...
      push @options, "--transportArg", "LocalAddr=" . $self->Servers->{$serverName}->{transportArgs}->{LocalAddr};
    }

    push @options, "--masterAddress", $masterServerAddress;
    push @options, "--masterPort",    $masterServerPort;

    # dump all of this server's config settings into the arg list
    foreach my $parameter ( $self->Config->Parameters($serverName) )
    {
      my $value = $self->Config->val( $serverName, $parameter );
      push @options, "--$parameter=$value";
    }

    $self->Servers->{$serverName}->{options} = \@options;
    $self->Servers->{$serverName}->{pid}     = 0;

  }

  return $self;
}

sub CheckServers
{
  my $self = shift;

  #  print "Checking server status...\n";

  foreach my $serverName ( keys( %{ $self->Servers } ) )
  {

    #    print "  Checking server: $serverName\n";
    if ( $self->Servers->{$serverName}->{pid} )
    {

      #      print "    Server should be up...(".$self->Servers->{$serverName}->{pid}.")\n";
      waitpid($self->Servers->{$serverName}->{pid}, POSIX::WNOHANG);
      my $alive = kill( 0, $self->Servers->{$serverName}->{pid} );
      if ( !$alive )
      {
        #        print "    Server was down!\n";
        # server crashed...
        $self->Servers->{$serverName}->{pid} = 0;
        next;
      }

      if ( !$self->ServerClients->{$serverName} )
      {

        #        print "  Creating RPC::Lite::Client for queries...\n";
        # a little hairy, we play with the Host/Port vs. LocalAddr/ListenPort that we got to run it as a server...
        $self->ServerClients->{$serverName} = RPC::Lite::Client->new(
          {
            Transport => $self->Servers->{$serverName}->{transportType}->new(
              {
                Host    => $self->Servers->{$serverName}->{transportArgs}->{LocalAddr},
                Port    => $self->Servers->{$serverName}->{transportArgs}->{ListenPort},
                Timeout => 1,                                                              
              }
            ),
            Serializer => $self->Servers->{$serverName}->{serializerType}->new( $self->Servers->{$serverName}->{serializerArgs} ),
          }
        );

        eval { $self->ServerClients->{$serverName}->Connect(); };
        if($@)
        {
          delete $self->ServerClients->{$serverName};
          print STDERR "Failed to connect to server: $serverName\n  Error: $@\n";
          next;
        }
      }

      #      print "  Getting server info...\n";
      #      print "    Getting uptime...\n";
      $self->Servers->{$serverName}->{info}->{uptime} = $self->ServerClients->{$serverName}->Request('system.Uptime');

      #      print "    Getting requestCount\n";
      $self->Servers->{$serverName}->{info}->{requestCount} = $self->ServerClients->{$serverName}->Request('system.RequestCount');

      #      print "    Getting systemRequestCount\n";
      $self->Servers->{$serverName}->{info}->{systemRequestCount} = $self->ServerClients->{$serverName}->Request('system.SystemRequestCount');

      #      print "  Done\n";
    }
  }

  #  print "Done\n";
}

sub GetServerNames
{
  my $self = shift;

  #  print "GetServerNames\n";

  my @serverNames = keys( %{ $self->Servers } );
  return \@serverNames;
}

sub StartServer
{
  my $self       = shift;
  my $serverName = shift;

  return 0 if !$self->Servers->{$serverName};          # unknown server
  return 1 if $self->Servers->{$serverName}->{pid};    # already up

  print "Starting server: $serverName ... ";

  # clear out all the old info we had on this server...
  delete $self->Servers->{$serverName}->{info};

  my $pid = fork();
  if ($pid)
  {

    # in parent
    $self->Servers->{$serverName}->{pid}       = $pid;
    $self->Servers->{$serverName}->{startTime} = time();
    sleep(0.1); # give it a moment to fork and try to exec the process
    if ( waitpid($pid, POSIX::WNOHANG) == $pid )
    {
      print "failed to exec\n";
      return 0;
    }
    print "done [$pid]\n";
    return 1;
  }
  else
  {

    # in child
    # note: don't need to worry about sigint handler here because exec
    #   overwrites parent process's memory space
    open( STDOUT, ">${serverName}.out.log" );
    open( STDERR, ">${serverName}.err.log" );
    $ENV{PERL5LIB} = $self->Servers->{$serverName}->{directory} . ':' . $ENV{PERL5LIB};
    my $command = $self->Servers->{$serverName}->{exeFullPath};
    if ( $self->Profiling )
    {
      if ( $self->Servers->{$serverName}->{executable} =~ /\.pl$/ )
      {
        $ENV{PERL_DPROF_OUT_FILE_NAME} = "profile_${serverName}.out";
        unshift( @{ $self->Servers->{$serverName}->{options} }, '-d:DProf', $self->Servers->{$serverName}->{exeFullPath} );
        $command = "perl";
      }
    }
    exec( $command, @{ $self->Servers->{$serverName}->{options} } );
    # exec should never return. if it returns, then it totally failed to
    # execute the server thus we must exit to terminate the child.
    exit(-1);
  }
}

sub StopServer
{
  my $self       = shift;
  my $serverName = shift;

  return 0 if !$self->Servers->{$serverName};           # unknown server
  return 1 if !$self->Servers->{$serverName}->{pid};    # already down

  print "Stopping server: $serverName ... ";

  if ( $self->ServerClients->{$serverName} )
  {

    #erg, need to figure out how to have all the servers have a Shutdown method
    #$self->ServerClients->{$serverName}->Request('Shutdown');
    #sleep(1);
  }

  if ( kill( 0, $self->Servers->{$serverName}->{pid} ) )    # it survived...
  {
    if ( kill( 2, $self->Servers->{$serverName}->{pid} ) )    # send the SIGINT to child
    {
      waitpid( $self->Servers->{$serverName}->{pid}, 0 );     # wait for child to die...
      $self->Servers->{$serverName}->{pid} = 0;
    }
    else
    {
      print "failed!\n";
      return 0;                                               # failed to kill it
    }
  }

  # the server's gone, we can't keep this client around...
  delete $self->ServerClients->{$serverName};

  print "done\n";
  return 1;
}

sub RestartServer
{
  my $self       = shift;
  my $serverName = shift;

  print "Restarting server: $serverName\n";
  return $self->StopServer($serverName) && $self->StartServer($serverName);
}

sub StartAllServers
{
  my $self = shift;

  print "Starting all servers...\n";

  my $result = 1;
  foreach my $serverName ( keys %{ $self->Servers } )
  {
    $result = $self->StartServer($serverName) && $result;
  }

  return $result;
}

sub StopAllServers
{
  my $self = shift;

  print "Stopping all servers...\n";

  my $result = 1;
  foreach my $serverName ( keys %{ $self->Servers } )
  {
    $result = $self->StopServer($serverName) && $result;
  }

  return $result;
}

sub RestartAllServers
{
  my $self = shift;

  print "Restarting all servers...\n";
  return $self->StopAllServers() && $self->StartAllServers();
}

sub GetInfo
{
  my $self       = shift;
  my $serverName = shift;

  return $self->Servers->{$serverName};
}

sub Shutdown
{
  my $self = shift;

  print "Shutting down...\n";
  foreach my $serverName ( keys %{ $self->Servers } )
  {
    $self->StopServer($serverName);
  }

  exit;
}

1;
