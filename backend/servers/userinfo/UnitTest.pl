#!/usr/bin/perl

use strict;

use RPC::XML;
use RPC::XML::Client;
use Data::Dumper;

print qq{

Notes:
-------------------------------------------

};

my $userInfoServer = RPC::XML::Client->new('http://localhost:10004/RPCSERV');

################################
## List methods
print "List methods:\n\n";
my $response = $userInfoServer->simple_request('system.listMethods');
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (GetID)\n";
$response = $userInfoServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('GetID'));
print Dumper $response;
print "\n\n";
################################

################################
## Method signature
print "Method signature (Add)\n";
$response = $userInfoServer->simple_request('system.methodSignature',
                                              RPC::XML::string->new('Add'));
print Dumper $response;
print "\n\n";
################################

################################
## Add user
# email firstname middlename lastname address1 address2 city state zipcode country phone birthdate webpage im summary
print q{Calling Add('burke@bitflood.org', 'Andrew', 'James', 'Burke', '10 University Rd Apt 1', '', 'Brookline', 'MA', '02445', 'US', '585-503-7988', '09/04/1978', 'http://www.andrewburke.org/', 'giantgearz', 'Hi! This is my summary, a little about me!'} . "\n";
$response = $userInfoServer->simple_request('Add',
                                              RPC::XML::string->new('burke@bitflood.org'),
                                              RPC::XML::string->new('Andrew'),
                                              RPC::XML::string->new('James'),
                                              RPC::XML::string->new('Burke'),
                                              RPC::XML::string->new('10 Unversity Rd Apt 1'),
                                              RPC::XML::string->new(''),
                                              RPC::XML::string->new('Brookline'),
                                              RPC::XML::string->new('MA'),
                                              RPC::XML::string->new('02445'),
                                              RPC::XML::string->new('US'),
                                              RPC::XML::string->new('585-503-7988'),
                                              RPC::XML::string->new('09/04/1978'),
                                              RPC::XML::string->new('http://www.andrewburke.org/'),
                                              RPC::XML::string->new('giantgearz'),
                                              RPC::XML::string->new('Hi! This is my summary, a little about me!'),
					    );
print Dumper $response;
print "\n\n";
################################

################################
## GetID
print q{Calling GetID('burke@bitflood.org')} . "\n";
$response = $userInfoServer->simple_request('GetID',
                                            RPC::XML::string->new('burke@bitflood.org'),
					    );
print Dumper $response;
print "\n\n";
################################




