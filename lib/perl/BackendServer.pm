package BackendServer;

use strict;

$| = 1; # autoflush output

use RPC::Lite::Client;
use RPC::Lite::Server;

# FIXME stupid, these should be required in below, but that's causing issues for some reason
use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

use base qw(RPC::Lite::Server);

use Carp;
use Getopt::Long qw(:config pass_through);
use DBI;

$SIG{INT} = \&HandleSigInt;

sub Name               { $_[0]->{name}               = $_[1] if @_ > 1; $_[0]->{name} }
sub dbConfig           { $_[0]->{dbconfig}           = $_[1] if @_ > 1; $_[0]->{dbconfig} }
sub MasterServerClient { $_[0]->{masterserverclient} = $_[1] if @_ > 1; $_[0]->{masterserverclient} }
sub ServerInfo         { $_[0]->{serverinfo}         = $_[1] if @_ > 1; $_[0]->{serverinfo} }
sub RPCClients         { $_[0]->{rpcclients}         = $_[1] if @_ > 1; $_[0]->{rpcclients} }
sub RPCServer          { $_[0]->{rpcserver}          = $_[1] if @_ > 1; $_[0]->{rpcserver} }

sub new
{
  my $class = shift;
  my $args  = shift;

  my ( $dbDsn, $dbUsername, $dbPassword, $masterAddress, $masterPort, $threading, $transportType, $serializationType, %transportArgs, %serializerArgs );
  GetOptions(
              "dbDsn=s"             => \$dbDsn,
              "dbUsername=s"        => \$dbUsername,
              "dbPassword=s"        => \$dbPassword,
              "transportType=s"     => \$transportType,
              "transportArg=s"      => \%transportArgs,
              "serializationType=s" => \$serializationType,
              "serializerArgs=s"    => \%serializerArgs,
              "masterAddress=s"     => \$masterAddress,
              "masterPort=s"        => \$masterPort,
              "threading"           => \$threading,
            );

  $transportType ||= 'RPC::Lite::Transport::TCP';
  $serializationType ||= 'RPC::Lite::Serializer::JSON';

  my $self = $class->SUPER::new(
                                 {
                                   Transport  => $transportType->new( \%transportArgs ),
                                   Serializer => $serializationType->new( \%serializerArgs ),
                                   Threading  => $threading,
                                 }
                               );
  $self or croak("Failed to create server object");

  $self->Name( $args->{name} );
  $self->Name or croak("name not set");

  $self->dbConfig( [ $dbDsn, $dbUsername, $dbPassword ] );

  $masterAddress ||= 'localhost';
  $masterPort    ||= 10000;
  $self->MasterServerClient(
                             RPC::Lite::Client->new(
                                                     {
                                                       Transport  => RPC::Lite::Transport::TCP->new( { Host => $masterAddress, Port => $masterPort } ),
                                                       Serializer => RPC::Lite::Serializer::JSON->new(),
                                                     }
                                                   )
                           );
  die("Could not create master server client!") if !defined( $self->MasterServerClient );

  $self->ServerInfo( {} );
  $self->RPCClients( {} );

  return $self;
}

=head2 Dbh()

Returns a DBI database handle based on the db config options.

=cut

sub Dbh
{
  my $self = shift;

  my $dbh = DBI->connect_cached( @{ $self->dbConfig } );
  $dbh or carp( "Failed to connect to database [" . $self->dbConfig->[0] . "]" );

  return $dbh;
}

=head2 GetServerInfo($serverName)

Returns information for the server C<$serverName>.

=cut

sub GetServerInfo
{
  my $self       = shift;
  my $serverName = shift;

  defined $serverName or croak("Must specify server name!");

  if ( !exists $self->ServerInfo->{$serverName} )
  {
    my $serverInfo = $self->MasterServerClient->Request( 'GetInfo', $serverName );
    if ( !defined($serverInfo) )
    {
      die("Could not get info for server: $serverName");
    }
    $self->ServerInfo->{$serverName} = $serverInfo;
  }

  return $self->ServerInfo->{$serverName};
}

sub GetClient
{
  my $self       = shift;
  my $serverName = shift;

  if ( !defined( $self->RPCClients->{$serverName} ) )
  {

    # FIXME not reall suitable for in-memory transport
    my $serverInfo = $self->GetServerInfo($serverName);

    ###use Data::Dumper;
    ###print Dumper($serverInfo);

    # FIXME require the module for the transport type
    my $transportType  = $serverInfo->{transportType}  || 'RPC::Lite::Transport::TCP';
    my $serializerType = $serverInfo->{serializerType} || 'RPC::Lite::Serializer::JSON';

    my $client = RPC::Lite::Client->new(
                                         {
                                           Transport  => $transportType->new( { Host => $serverInfo->{transportArgs}->{LocalAddr}, Port => $serverInfo->{transportArgs}->{ListenPort} } ),
                                           Serializer => $serializerType->new( $serverInfo->{serializerArgs} ),
                                         }
                                       );

    if ( !defined($client) )
    {
      return undef;
    }

    $self->RPCClients->{$serverName} = $client;
  }

  return $self->RPCClients->{$serverName};
}

# -server blah={transport=> 'TCP'; transportArgs => { Port=> 10000, Host => 'localhost'}; serializer => 'JSON'; serializerArgs = {};}
sub Call
{
  my $self     = shift;
  my $callName = shift;

  my ( $serverName, $methodName ) = ( $callName =~ /^(.*?)\.(.*)/ );
  my $client = $self->GetClient($serverName);

  if ( !defined $client )
  {
    return RPC::Lite::Error->new("Could not connect to server: $serverName");
  }

  return $client->Request( $methodName, @_ );
}

sub Do
{
  my $self     = shift;
  my $callName = shift;

  my ($serverName) = ( $callName =~ /^(.*?)\./ );
  my $client = $self->GetClient($serverName);

  if ( !defined $client )
  {
    return RPC::Lite::Error->new("Could not connect to server: $serverName");
  }

  return $client->Notify( $callName, @_ );
}

sub Shutdown
{
  my $self = shift;
  exit;
}

sub HandleSigInt
{
  exit;
}

1;
