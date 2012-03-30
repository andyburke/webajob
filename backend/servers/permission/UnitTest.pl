#!/usr/bin/perl

use strict;

use RPC::XML;
use RPC::XML::Client;
use Data::Dumper;

print qq{

Notes:
-------------------------------------------
- requires valid permission types of '300' and 'login' already in the database

};

my $permissionServer = RPC::XML::Client->new('http://localhost:10001/RPCSERV');

################################
## List methods
print "List methods:\n\n";
my $response = $permissionServer->simple_request('system.listMethods');
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (Check)\n";
$response = $permissionServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('Check'));
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (Grant)\n";
$response = $permissionServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('Grant'));
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (Revoke)\n";
$response = $permissionServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('Revoke'));
print Dumper $response;
print "\n\n";
################################

################################
## Grant permission
print "Calling Grant(100, 200, 300)\n";
$response = $permissionServer->simple_request('Grant',
                                              RPC::XML::int->new(100),
                                              RPC::XML::int->new(200),
                                              RPC::XML::int->new(300));
print Dumper $response;
print "\n\n";
################################

################################
## Grant permission
print "Calling Grant(100, 200, 'login')\n";
$response = $permissionServer->simple_request('Grant',
                                              RPC::XML::int->new(100),
                                              RPC::XML::int->new(200),
                                              RPC::XML::string->new('login'));
print Dumper $response;
print "\n\n";
################################

################################
## Check permission
print "Calling Check(100, 200, 300)\n";
$response = $permissionServer->simple_request('Check',
                                              RPC::XML::int->new(100),
                                              RPC::XML::int->new(200),
                                              RPC::XML::int->new(300));
print Dumper $response;
print "\n\n";
################################

################################
## Check permission
print "Calling Check(100, 200, 'login')\n";
$response = $permissionServer->simple_request('Check',
                                              RPC::XML::int->new(100),
                                              RPC::XML::int->new(200),
                                              RPC::XML::string->new('login'));
print Dumper $response;
print "\n\n";
################################


################################
## Revoke permission
print "Calling Revoke(100, 200, 300)\n";
$response = $permissionServer->simple_request('Revoke',
                                              RPC::XML::int->new(100),
                                              RPC::XML::int->new(200),
                                              RPC::XML::int->new(300));
print Dumper $response;
print "\n\n";
################################

################################
## Revoke permission
print "Calling Revoke(100, 200, 'login')\n";
$response = $permissionServer->simple_request('Revoke',
                                              RPC::XML::int->new(100),
                                              RPC::XML::int->new(200),
                                              RPC::XML::string->new('login'));
print Dumper $response;
print "\n\n";
################################




