#!/usr/bin/perl

use strict;

use RPC::XML;
use RPC::XML::Client;
use Data::Dumper;

print qq{

Notes:
-------------------------------------------

};

my $authenticationServer = RPC::XML::Client->new('http://localhost:10005/RPCSERV');

################################
## List methods
print "List methods:\n\n";
my $response = $authenticationServer->simple_request('system.listMethods');
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (Authenticate)\n";
$response = $authenticationServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('Authenticate'));
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (SetKey)\n";
$response = $authenticationServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('SetKey'));
print Dumper $response;
print "\n\n";
################################

################################
## Set Key
print "Calling SetKey(41, 'blahblah')\n";
$response = $authenticationServer->simple_request('SetKey',
                                              RPC::XML::int->new(45),
                                              RPC::XML::string->new('blahblah'),
                                            );
print Dumper $response;
print "\n\n";
################################


################################
## Authenticate user
print "Calling Authenticate(41, 'blahblah')\n";
$response = $authenticationServer->simple_request('Authenticate',
                                              RPC::XML::int->new(41),
                                              RPC::XML::string->new('blahblah'),
					    );
print Dumper $response;
print "\n\n";
################################

