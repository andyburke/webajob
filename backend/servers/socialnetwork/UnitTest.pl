#!/usr/bin/perl -w

use strict;

use RPC::XML;
use RPC::XML::Client;
use Data::Dumper;

print qq{

Notes:
};

my $socialNetworkServer = RPC::XML::Client->new('http://localhost:11101/RPCSERV');

################################
## List methods
print "List methods:\n\n";
my $response = $socialNetworkServer->simple_request('system.listMethods');
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (socialnetwork.BeginRelationship)\n";
$response = $socialNetworkServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('socialnetwork.BeginRelationship'));
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (socialnetwork.EndRelationship)\n";
$response = $socialNetworkServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('socialnetwork.EndRelationship'));
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (socialnetwork.QueryRelationships)\n";
$response = $socialNetworkServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('socialnetwork.QueryRelationships'));
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (socialnetwork.HasRelationship)\n";
$response = $socialNetworkServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('socialnetwork.HasRelationship'));
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (socialnetwork.FindOrCreateRelationshipType)\n";
$response = $socialNetworkServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('socialnetwork.FindOrCreateRelationshipType'));
print Dumper $response;
print "\n\n";
################################

################################
## Begin Relationship
print "Calling socialnetwork.BeginRelationship( 0, 1, 0 )\n";
$response = $socialNetworkServer->simple_request('socialnetwork.BeginRelationship',
                                              RPC::XML::int->new(0),
                                              RPC::XML::int->new(1),
                                              RPC::XML::int->new(0));
print Dumper $response;
print "\n\n";
################################

################################
## End Relationship
print "Calling socialnetwork.EndRelationship( 0, 1, 0 )\n";
$response = $socialNetworkServer->simple_request('socialnetwork.EndRelationship',
                                              RPC::XML::int->new(0),
                                              RPC::XML::int->new(1),
                                              RPC::XML::int->new(0));
print Dumper $response;
print "\n\n";
################################

################################
## End Relationship
print "Calling socialnetwork.EndRelationship( 0 )\n";
$response = $socialNetworkServer->simple_request('socialnetwork.EndRelationship',
                                              RPC::XML::int->new(0));

print Dumper $response;
print "\n\n";
################################

################################
## Query Relationships
print "Calling socialnetwork.QueryRelationships( 0, 0, 1 )\n";
$response = $socialNetworkServer->simple_request('socialnetwork.QueryRelationships',
                                              RPC::XML::int->new(0),
                                              RPC::XML::int->new(0),
                                              RPC::XML::int->new(1));
print Dumper $response;
print "\n\n";
################################

################################
## Query Relationships
print "Calling socialnetwork.QueryRelationships( 0, ( 0 ) )\n";
$response = $socialNetworkServer->simple_request('socialnetwork.QueryRelationships',
                                              RPC::XML::int->new(0),
                                              RPC::XML::array->new( RPC::XML::int->new(0) ) );
print Dumper $response;
print "\n\n";
################################

################################
## Has Relationship
print "Calling socialnetwork.HasRelationship( 0, 1, 0 )\n";
$response = $socialNetworkServer->simple_request('socialnetwork.HasRelationship',
                                              RPC::XML::int->new(0),
                                              RPC::XML::int->new(1),
                                              RPC::XML::int->new(0));

print Dumper $response;
print "\n\n";
################################

################################
## Find or Create Relationship Type
print "Calling socialnetwork.FindOrCreateRelationshipType( \"test\" )\n";
$response = $socialNetworkServer->simple_request('socialnetwork.FindOrCreateRelationshipType',
                                                 RPC::XML::string->new( "test" ) );

print Dumper $response;
print "\n\n";
################################

