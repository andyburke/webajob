#!/usr/bin/perl

use strict;

use RPC::XML;
use RPC::XML::Client;
use Data::Dumper;

print qq{

Notes:
-------------------------------------------

};

my $logServer = RPC::XML::Client->new('http://localhost:10002/RPCSERV');

################################
print "List methods:\n\n";
my $response = $logServer->simple_request('system.listMethods');
print Dumper $response;
print "\n\n";
################################

################################
print "Create Channel (defaultchannel):\n\n";
my $response = $logServer->simple_request('log.CreateChannel', "defaultchannel");
print Dumper $response;
print "\n\n";
################################

################################
print "Create Level (defaultlevel):\n\n";
my $response = $logServer->simple_request('log.CreateLevel', "defaultlevel");
print Dumper $response;
print "\n\n";
################################

################################
print "Create Level (taco):\n\n";
my $response = $logServer->simple_request('log.CreateLevel', "taco");
print Dumper $response;
print "\n\n";
################################


################################
print "Create Channel (hello):\n\n";
my $response = $logServer->simple_request('log.CreateChannel', "hello");
print Dumper $response;
print "\n\n";
################################


################################
print "Log Message (Insufficient Memory at this Time):\n\n";
my $response = $logServer->simple_request('log.Log', "Insufficient Memory at this Time");
print Dumper $response;
print "\n\n";
################################


################################
print "Log Message (channel hello, level taco, Ellian?):\n\n";
my $response = $logServer->simple_request('log.Log',"Ellian?", "hello", "taco");
print Dumper $response;
print "\n\n";
################################

################################
print "Log Message (channel wee, level taco, Ellian?):\n\n";
my $response = $logServer->simple_request('log.Log',"Ellian?", "wee", "taco");
print Dumper $response;
print "\n\n";
################################

################################
print "Log Message (channel hello, level pee, Ellian?):\n\n";
my $response = $logServer->simple_request('log.Log',"Ellian?", "hello", "pee");
print Dumper $response;
print "\n\n";
################################

################################
print "Log Message (channel hello, level taco, Ellian?):\n\n";
my $response = $logServer->simple_request('log.Log',"Ellian?", "hello");
print Dumper $response;
print "\n\n";
################################

