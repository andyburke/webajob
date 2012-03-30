#!/usr/bin/perl

BEGIN
{
  # assume we're running in the staging dir...
  $ENV{PERL5LIB} = "../lib/perl:$ENV{PERL5LIB}";    # we put our crap first in case we override installed libs
  use lib '../lib/perl';
}

use strict;
use Curses::UI;
use Term::ReadKey;
use Getopt::Long;
use IO::Handle;
use IO::File;
use Data::Dumper;
use RPC::Lite::Client;
use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

my $serverListFormat = "%-30.30s %-5.5s %-4.4s %-4.4s";

my $masterAddress     = 'localhost';
my $masterPort        = 10000;
my $startMasterServer = 0;
GetOptions(
            'masterAddress=s' => \$masterAddress,
            'masterPort=s'    => \$masterPort,
            'startMaster'     => \$startMasterServer,
          );

my $masterClient;
my $masterServerPid = 0;

my $currentLogFilename;
my $currentLogFile;

open(STDERR, '>Console.err.log'); # curses keeps us from seeing this on-screen

my $cui = Curses::UI->new( -color_support => 1 );

my @menu = (
             {
               -label   => 'File',
               -submenu => [ { -label => 'Connect to Master Server  ^O', -value => \&ConnectHandler }, { -label => 'Start Master Server  ^A', -value => \&StartMasterServerHandler }, { -label => 'Stop Master Server', -value => \&StopMasterServerHandler }, { -label => '--------------', }, { -label => 'Exit      ^Q', -value => \&QuitHandler } ]
             },
             {
               -label   => 'Server',
               -submenu => [ { -label => 'Start        T', -value => \&StartServerHandler }, { -label => 'Stop         P', -value => \&StopServerHandler }, { -label => 'Restart      R', -value => \&RestartServerHandler }, { -label => '--------------', }, { -label => 'Start All   ^T', -value => \&StartAllServersHandler }, { -label => 'Stop All    ^P', -value => \&StopAllServersHandler }, { -label => 'Restart All ^R', -value => \&RestartAllServersHandler }, ]
             },
             {
               -label   => 'Development',
               -submenu => [ { -label => 'Reinitialize Databases', -value => \&ReinitializeDatabasesHandler }, { -label => 'Load Test Data', -value => \&LoadTestDataHandler } ],
             },
           );

$cui->set_binding( \&ConnectHandler,           "\cO" );
$cui->set_binding( \&StartMasterServerHandler, "\cA" );
$cui->set_binding( \&QuitHandler,              "\cQ" );
$cui->set_binding( \&StartServerHandler,       "t" );
$cui->set_binding( \&StopServerHandler,        "p" );
$cui->set_binding( \&RestartServerHandler,     "r" );
$cui->set_binding( \&StartAllServersHandler,   "\cT" );
$cui->set_binding( \&StopAllServersHandler,    "\cP" );
$cui->set_binding( \&RestartAllServersHandler, "\cR" );

my $menubar = $cui->add( 'menu', 'Menubar', -menu => \@menu );

my $mainWindow = $cui->add(
                            'mainWindow', 'Window',
                            -border => 0,
                            '-y'    => 1,
                          );

my $serverListHeight = int( $cui->height / 4 );
$serverListHeight = 10 if $serverListHeight > 10;
my $serverList = $mainWindow->add(
                                   'serverList', 'Listbox',
                                   -height       => $serverListHeight,
                                   -border       => 1,
                                   -vscrollbar   => 1,
                                   -title        => sprintf( $serverListFormat, 'Server', 'Stat', 'Out', 'Err' ),
                                   -titlereverse => undef,
                                   -onselchange  => \&ServerListSelectionChangeHandler,
                                 );

# FIXME: should be a flock of labels instead
#my $infoTextHeight = int( $cui->height / 5 );
my $infoTextHeight = 4;    # if $infoTextHeight > 8;
my $infoTextViewer = $mainWindow->add(
                                       'infoTextViewer', 'TextViewer',
                                       -border       => 1,
                                       -vscrollbar   => 1,
                                       -title        => 'Server Info',
                                       -titlereverse => undef,
                                       '-y'          => $serverListHeight,
                                       -height       => $infoTextHeight,
                                     );

my $outputTextViewer = $mainWindow->add(
                                         'outputTextViewer', 'TextViewer',
                                         -border       => 1,
                                         -vscrollbar   => 1,
                                         -hscrollbar   => 1,
                                         -title        => 'Server Output',
                                         -titlereverse => undef,
                                         '-y'          => $serverListHeight + $infoTextHeight,
                                       );

RefreshServerList();
$cui->set_timer( 'RefreshServerList', \&RefreshServerList, 5 );
$cui->set_timer( 'RefreshLogWindow', \&RefreshLogWindow, 1); # FIXME fractional seconds not supported (rounds to 0)
$cui->set_read_timeout(.25);

if ($startMasterServer)
{
  StartMasterServerHandler();
  StartAllServersHandler();
}

$serverList->focus;
$cui->MainLoop();

#===========================================

sub ConnectHandler
{
  $cui->status('Connecting to master server...');

  $masterClient = RPC::Lite::Client->new( { Transport => RPC::Lite::Transport::TCP->new( { Host => $masterAddress, Port => $masterPort } ), Serializer => RPC::Lite::Serializer::JSON->new() } );

  if ( !$masterClient )
  {
    $cui->dialog(
                  -message => "Could not connect to master server!",
                  -title   => "Connection Failure",
                  -buttons => ['ok'],
                );
  }

  $cui->nostatus;
}

sub StartMasterServerHandler
{
  if ($masterServerPid)
  {
    $cui->dialog(
                  -message => "Master server is already running!",
                  -title   => "Error",
                  -buttons => ['ok'],
                );
    return;
  }

  StartMasterServer();
}

sub StopMasterServerHandler
{
  if ($masterServerPid)
  {

    $cui->status("Stopping Master Server...");

    my $masterServerKilled = kill( 2, $masterServerPid );
    if ( !$masterServerKilled )
    {

      # FIXME kill -9?
      $cui->dialog(
                    -message => "Could not stop master server! (Crashed?)",
                    -title   => "Master Server Failure",
                    -buttons => ['ok'],
                  );
    }
    waitpid($masterServerPid, 0);
    $masterServerPid = 0;
    $masterClient    = undef;

    $cui->nostatus();
    RefreshServerList();
  }
}

sub QuitHandler
{

  my $return = $cui->dialog(
                             -message => "Do you really want to quit?",
                             -title   => "Quit?",
                             -buttons => [ 'yes', 'no' ],
                           );

  Shutdown() if $return;
}

sub StartServerHandler
{
  my $widget     = shift;
  my $keyPressed = shift;
  my $serverName = $serverList->get_active_value;

  if ( !StartServer($serverName) )
  {
    $cui->dialog(
                  -message => "Failed to start server: $serverName",
                  -title   => "Start Failure",
                  -buttons => ['ok'],
                );
  }
  RefreshServerList();
}

sub StopServerHandler
{
  my $widget     = shift;
  my $keyPressed = shift;
  my $serverName = $serverList->get_active_value;

  if ( !StopServer($serverName) )
  {
    $cui->dialog(
                  -message => "Failed to stop server: $serverName",
                  -title   => "Stop Failure",
                  -buttons => ['ok'],
                );
  }
  RefreshServerList();
}

sub RestartServerHandler
{
  my $widget     = shift;
  my $keyPressed = shift;
  my $serverName = $serverList->get_active_value;

  StopServer($serverName);
  my $result = StartServer($serverName);

  if ( !$result )
  {
    $cui->dialog(
                  -message => "Failed to restart server: $serverName",
                  -title   => "Restart Failure",
                  -buttons => ['ok'],
                );
  }
  RefreshServerList();
}

sub StartAllServersHandler
{
  return 0 if !$masterClient;
  my $serverNames = $masterClient->Request('GetServerNames');

  if ($serverNames)
  {
    my @failures;
    my $serverIndex = 1;
    my $serverCount = @$serverNames;
    foreach my $serverName (@$serverNames)
    {
      $cui->status(sprintf('Starting all servers... %3d/%3d: %-20.20s',
                           $serverIndex, $serverCount, $serverName));
      my $ok = StartServer($serverName);
      push @failures, $serverName if !$ok;
      ++$serverIndex;
    }
    $cui->nostatus();

    if ( @failures )
    {
      $cui->dialog(
                    -message => "Failed to start the following servers:\n  @failures",
                    -title   => 'Failure',
                    -buttons => ['ok'],
                  );
    }

  }
  else
  {
    $cui->dialog(
                  -message => "Could not obtain server name list!",
                  -title   => "Failure",
                  -buttons => ['ok'],
                );
  }

  RefreshServerList();
}

sub StopAllServersHandler
{
  return 0 if !$masterClient;
  my $serverNames = $masterClient->Request('GetServerNames');

  if ($serverNames)
  {
    $cui->status("Stopping all servers...");
    my $ok = 1;
    foreach my $serverName (@$serverNames)
    {
      $ok = StopServer($serverName) && $ok;    # zero $ok on any failure
    }

    # FIXME crubbed.  should check on the server status until they're all down (or timeout surpassed)
    foreach my $delay ( 1 .. 2 )
    {
      $cui->status( 'Waiting for servers to shut down... (' . ( 3 - $delay ) . ')' );
      sleep(1);
    }
    $cui->nostatus();

    if ( !$ok )
    {
      $cui->dialog(
                    -message => 'Some servers failed to stop',
                    -title   => 'Failure',
                    -buttons => ['ok'],
                  );
    }

  }
  else
  {
    $cui->dialog(
                  -message => "Could not obtain server name list!",
                  -title   => "Failure",
                  -buttons => ['ok'],
                );
  }

  RefreshServerList();
}

sub RestartAllServersHandler
{

  # FIXME: maybe startall/stopall should be refactored out of the handlers and then
  #  we would call them here instead
  StopAllServersHandler();
  StartAllServersHandler();
}

sub RefreshServerList
{

  # get the user's current selection so we can re-instate it after refreshing
  my @oldServerNames = @{$serverList->values};

  my @newServerNames;

  # if we're not connected, we'll just have an empty array of servers
  if ($masterClient)
  {
    @newServerNames = sort @{ $masterClient->Request('GetServerNames') };
  }
  my $listsDiffer = (@newServerNames == @oldServerNames);
  for (my $i = 0; $i < @newServerNames; $i++ && !$listsDiffer)
  {
    $listsDiffer = ($newServerNames[$i] ne $oldServerNames[$i]);
  }
  if ($listsDiffer)
  {
    $serverList->values( \@newServerNames );
  }

  my %labels;
  foreach my $serverName (@newServerNames)
  {
    my $serverInfo = $masterClient->Request( 'GetInfo', $serverName );
    $labels{$serverName} = sprintf( ' ' . $serverListFormat, $serverName, $serverInfo->{pid} ? 'up' : 'down', '', '' );
  }
  $serverList->labels( \%labels );

  $serverList->intellidraw;
}

sub ServerListSelectionChangeHandler
{

  # FIXME so dirty, should handle the lack of a masterClient more cleanly
  if ( !$masterClient )
  {
    $infoTextViewer->text('');
    return;
  }

  my $widget = shift;    # we ignore this for now

  my $text;

  my $serverName = $serverList->get_active_value;
  my $serverInfo = $masterClient->Request( 'GetInfo', $serverName );

  if ( defined($serverInfo) )
  {
    if ( $serverInfo->{pid} )
    {
      $text = sprintf( "[Name: %-26.26s]  [Location: %s:%d]\n", $serverName, $serverInfo->{transportArgs}{LocalAddr}, $serverInfo->{transportArgs}{ListenPort} );
      $text .= sprintf( "[Uptime: %8.8s]  [Reqs: %-6d]  [SysReqs: %-6d]  [Reqs/Sec: %5.5f]", ReadableTimeDelta( $serverInfo->{info}->{uptime} ), $serverInfo->{info}->{requestCount}, $serverInfo->{info}->{systemRequestCount}, ( $serverInfo->{info}->{uptime} > 0 ? ( $serverInfo->{info}->{requestCount} / $serverInfo->{info}->{uptime} ) : 0 ), );
    }
    else
    {
      $text = "Server down.";
    }
  }
  else
  {
    $text = "Could not retrieve info for server: $serverName";
  }

  $infoTextViewer->text($text);
#  RefreshLogWindow();
}

sub ReinitializeDatabasesHandler
{
  my $yes = $cui->dialog(
                             -message => 'This will delete all data and stop all servers, are you sure?',
                             -title   => 'Confirm',
                             -buttons => [ 'yes', 'no' ],
                           );
  return if !$yes;

  StopAllServersHandler();
  $cui->status("Reinitializing databases...");
  `../tools/dbadmin/dbadmin.pl --server all --drop --create`;
  sleep(1);
  $cui->nostatus();
}

sub LoadTestDataHandler
{

  my $yes = $cui->dialog(
                             -message => 'This will start all servers and load the test data, are you sure?',
                             -title   => 'Confirm',
                             -buttons => [ 'yes', 'no' ],
                           );
  return if !$yes;

  StartMasterServer();
  StartAllServersHandler();
  $cui->status("Loading test data...");
  # FIXME show this output on the screen
  `../tools/dataspoofer/dataspoofer.pl`;
  $cui->nostatus();

}

#==================================

sub StartServer
{
  return 0 if !$masterClient;
  my $serverName = shift;

  return $masterClient->Request( 'StartServer', $serverName );
}


sub StopServer
{
  return 0 if !$masterClient;
  my $serverName = shift;

  return $masterClient->Request( 'StopServer', $serverName );
}


sub StartMasterServer
{
  return 1 if $masterServerPid;

  $cui->status("Starting Master Server...");

  $masterServerPid = fork();
  if (!$masterServerPid)    # child
  {
    open( STDOUT, '>MasterServer.out.log' );
    open( STDERR, '>MasterServer.err.log' );
    exec('../tools/MasterServer/MasterServer.pl');
    # FIXME exec failed! somehow report this to the user, tough because of fork and curses...
    exit(-1);
  }

  # parent

  # FIXME schedule the connecthandler call
  sleep(1);
  $cui->nostatus();
  ConnectHandler();      # try to connect to the server we just started in the child
  RefreshServerList();

  return 1; # FIXME return undef on fork failure?
}


# FIXME revisit this to see if there is some less expensive way of detecting more shit to read
sub RefreshLogWindow
{
  my $serverName = $serverList->get_active_value;
  $serverName or return;

  # FIXME handle log files being re-opened beneath us

  my $newLogFilename = "${serverName}.out.log";
  if (($newLogFilename ne $currentLogFilename) or !$currentLogFile)
  {
    # we've selected a new server
    $currentLogFilename = $newLogFilename;
    $currentLogFile = IO::File->new("<$currentLogFilename");
    $outputTextViewer->text('');
  }

  return if !$currentLogFile; # you might not have ever started this server

  my $oldPosition = $currentLogFile->tell;
  $currentLogFile->seek(0, 2); # to the end
  if ($currentLogFile->tell != $oldPosition)
  {
    $currentLogFile->seek($oldPosition, 0);
    $outputTextViewer->text($outputTextViewer->text . join('', $currentLogFile->getlines));
    $outputTextViewer->{-ypos} = $outputTextViewer->number_of_lines - 1;
    $outputTextViewer->intellidraw;
  }
}


sub Shutdown
{
  if ($masterServerPid)
  {
    if ( !kill( 2, $masterServerPid ) )
    {
      $cui->dialog(
                    -message => "Could not shut down master server!",
                    -title   => "Master Server Failure",
                    -buttons => ['ok'],
                  );
    }
  }
  exit(0);
}

#==================================

sub ReadableTimeDelta
{
  my $timeDelta = shift;

  $timeDelta =~ /\d+/ or return 'unknown';

  my $hours = sprintf( "%02d", int( $timeDelta / 3600 ) );
  $timeDelta = $timeDelta % 3600;
  my $minutes = sprintf( "%02d", int( $timeDelta / 60 ) );
  $timeDelta = $timeDelta % 60;
  my $seconds = sprintf( "%02d", $timeDelta );

  return "$hours:$minutes:$seconds";
}


sub Debug
{
  my $message = shift;
  my $time = shift || 1;
  
  $cui->status("DEBUG: $message");
  sleep($time);
  $cui->nostatus;
}

