#!/usr/bin/perl

use strict;
use Getopt::Long;

use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

my ($port);
GetOptions( "port=s", \$port, );

$port ||= 10000;

my $server = ServerLocator->new(
                                 {
                                   Transport  => RPC::Lite::Transport::TCP->new( { ListenPort => $port } ),
                                   Serializer => RPC::Lite::Serializer::JSON->new(),
                                 }
                               );
$server->Loop;    

package ServerLocator;

use base qw(RPC::Lite::Server);

use Data::Dumper;
use Error;

sub Servers { $_[0]->{servers} = $_[1] if @_ > 1; $_[0]->{servers} }

sub Initialize
{
  my $self = shift;

  $self->Servers( {} );

}

sub Register
{
  my $self       = shift;
  my $serverName = shift;
  my $serverInfo = shift;

  print "Registering server: $serverName\n";
  print "  ", Dumper($serverInfo);
  print "\n\n";

  $self->Servers->{$serverName} = $serverInfo;
  return 1;
}

sub UnRegister
{
  my $self       = shift;
  my $serverName = shift;

  delete $self->Servers->{$serverName};
}

sub GetInfo
{
  my $self       = shift;
  my $serverName = shift;

  return $self->Servers->{$serverName};
}

sub GetServerNames
{
  my $self = shift;

  return [ keys %{ $self->Servers } ];
}

1;
