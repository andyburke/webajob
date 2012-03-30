#!/usr/bin/perl

use strict;

use Getopt::Long;
use RPC::Lite::Client;
use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

use Data::Dumper;

print qq{

Notes:
-------------------------------------------

};

my ( $host, $port );
GetOptions( 'host=s' => \$host,
            'port=s' => \$port, );    

my $idServer = RPC::Lite::Client->new(
                                       {
                                         Transport  => RPC::Lite::Transport::TCP->new( { Host => $host, Port => $port } ),
                                         Serializer => RPC::Lite::Serializer::JSON->new(),
                                       }
                                     );
die("Could not connect to id server.") if ( !$idServer );

################################
## Get ID
print "Calling GetID()\n";
my $response = $idServer->Request( 'GetId', 0 );
print Dumper $response;
print "\n\n";
################################

################################
## Get multiple IDs
print "Calling GetID mulitple times\n";
my @ids;
for ( 1 .. 3 )
{
  push( @ids, $idServer->Request( 'GetId', 0 ) );
}
print Dumper \@ids;
print "\n\n";
################################

################################
## Get type id
print "Calling id.GetType() on previously obtained ids\n";
foreach my $id (@ids)
{
  my $type = $idServer->Request( 'GetType', $id );
  print "$id: $type\n";
}
################################
