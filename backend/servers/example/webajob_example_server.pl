#!/usr/bin/perl
use strict;

my $server = Webajob::ExampleServer->new( { name => 'example' } );
$server->Loop;

package Webajob::ExampleServer;

use BackendServer;
use base qw(BackendServer);

sub HelloWorld
{
  my $self   = shift;
  my $param1 = shift;

  # ...

  return "hello world $param1";
}

1;    
