#!/usr/bin/perl

use strict;

use Getopt::Long;
use Config::IniFiles;
use Carp;
use File::Spec;
use IO::Socket::INET;

my %child_pids;    

my ( $config_filename, $do_profiling );
GetOptions( 'config=s' => \$config_filename,
            'profile'  => \$do_profiling, );
defined $config_filename or $config_filename = File::Spec->rel2abs('../config/default.ini');
-f $config_filename or croak("Config file $config_filename doesn't exist");

my $config = Config::IniFiles->new( -file => $config_filename );
$config or croak("Some serious problem creating a Config::IniFiles object");

$SIG{INT} = \&handle_sigint;

$ENV{PERL5LIB} = $config->val( 'global', 'perl5lib' ) . ":$ENV{PERL5LIB}";

my @server_names = grep { $_ ne 'global' } $config->Sections;

print "==== Probing for open ports ========================\n\n";

# NOTE: This isn't perfect; if two people run the harness in rapid succession,
# the port probing logic may get fooled.  This is because the harness closes
# the listen sockets before launching all the servers.  If the other harness
# probes ports in the interim, it could choose some or all of the same ports.

my $port = 10000;    # start with the arbitrary port 10000 (actually 10001 due to ++)
my %server_ports;
foreach my $server_name (@server_names)
{
  my $socket;
  do
  {
    $socket = IO::Socket::INET->new(
                                     Proto     => 'tcp',
                                     Listen    => 5,
                                     LocalPort => ++$port
                                   );
  } until ($socket);
  $socket->close;
  $server_ports{$server_name} = $port;
  print "$server_name: $port\n";
}

print "\n\n";
print "==== Starting servers ==============================\n\n";

foreach my $server_name (@server_names)
{

  print "--------------------------\n";
  print "Starting server: $server_name\n";

  my $directory = $config->val( $server_name, 'directory' );
  if ( !length $directory )
  {
    print_fail('No directory specified in config section');
    next;
  }
  $directory = File::Spec->rel2abs($directory);
  if ( !( -d $directory and -r $directory ) )
  {
    print_fail("Can't access $directory");
    next;
  }
  print "  server directory: $directory\n";

  my $executable = $config->val( $server_name, 'executable' );
  if ( !length $executable )
  {
    print_fail('No executable specified in config section');
    next;
  }
  my $executable_full_path = File::Spec->catfile( $directory, $executable );
  if ( !-x $executable_full_path )
  {
    print_fail("$executable_full_path doesn't exist or isn't executable");
    next;
  }

  my @options;

  # pass this server the rpc_port from the probed port list
  push @options, "--transportArg", "ListenPort=$server_ports{$server_name}";

  # dump all of this server's config settings into the arg list
  foreach my $parameter ( $config->Parameters($server_name) )
  {
    my $value = $config->val( $server_name, $parameter );
    push @options, "--$parameter=$value";
  }
  print "  command line: $executable_full_path @options\n";
  my $pid = fork();
  if ($pid)
  {

    # in parent
    $child_pids{$pid} = $executable;
  }
  else
  {

    # in child
    # note: don't need to worry about sigint handler here because exec
    #   overwrites parent process's memory space
    $ENV{PERL5LIB} = "$directory:$ENV{PERL5LIB}";
    if ($do_profiling)
    {
      if ( $executable =~ /\.pl$/ )
      {
        print "$executable: profiling enabled\n";
        $ENV{PERL_DPROF_OUT_FILE_NAME} = "profile_${server_name}.out";
        unshift( @options, '-d:DProf', $executable_full_path );
        $executable_full_path = "perl";
      }
    }
    exec( $executable_full_path, @options );
  }

  print "\n";
}

print "\n\n==== Running... ===================================\n\n";

while (1)
{
  sleep(1);
}

sub print_fail
{
  my $message = shift;

  print "  failure: $message\n";
}

sub handle_sigint
{
  print "\n\n==== Killing... ===================================\n\n";

  while ( my ( $pid, $executable ) = each %child_pids )
  {
    print "Shutting down $pid ($executable)\n";
    kill( 2, $pid );    # propagate the SIGINT to child
  }
  exit;
}
