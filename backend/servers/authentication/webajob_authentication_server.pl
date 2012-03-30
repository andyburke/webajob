#!/usr/bin/perl

use strict;

my $server = Webajob::AuthenticationServer->new( { name => 'authentication' } );
$server->Loop;

package Webajob::AuthenticationServer;

use BackendServer;
use base qw(BackendServer);

use AuthenticationDB::DBI;
use AuthenticationDB::Credential;
use AuthenticationDB::Session;

use Error;
use Digest::SHA qw(sha512_base64);

use constant SESSION_LENGTH => 30 * 60;    # 30 minutes, in seconds

sub new
{
  my $class = shift;
  
  my $self = $class->SUPER::new(@_);

  AuthenticationDB::DBI->set_db( 'Main', @{ $self->dbConfig } );

  return $self;
}


sub Authenticate
{
  my $self     = shift;
  my $sourceid = shift;
  my $password = shift;

  my $hashedPassword = sha512_base64($password);

  my ($credential) = AuthenticationDB::Credential->search( sourceid => $sourceid,
                                                           key      => $hashedPassword );

  if ( !$credential )
  {
    throw Error::Simple('Bad password.');
  }

  my $sessionToken = sha512_base64( $sourceid . $hashedPassword . scalar( localtime() ) );
  my $session = AuthenticationDB::Session->create(
    {
      token     => $sessionToken,
      sourceid  => $sourceid,
      starttime => 0,               # starttime and endtime are set in refresh_time below
      endtime   => 0,
    }
  );

  if ( !$session )
  {
    throw Error::Simple('Could not create session.');
  }

  $session->refresh_time(SESSION_LENGTH);

  return $sessionToken;
}

sub SetKey
{
  my $self     = shift;
  my $sourceid = shift;
  my $password = shift;

  my $hashedPassword = sha512_base64($password);

  my ($credential) = AuthenticationDB::Credential->retrieve( sourceid => $sourceid,
                                                             key      => $hashedPassword );

  if ( !$credential )
  {
    $credential = AuthenticationDB::Credential->create(
                                                        {
                                                          sourceid => $sourceid,
                                                          key      => $hashedPassword,
                                                        }
                                                      );
  }
  else
  {
    $credential->key($hashedPassword);
  }

  $credential->update();
  return 1;
}

sub GetUserIdFromSessionToken
{
  my $self  = shift;
  my $token = shift;

  my ($session) = AuthenticationDB::Session->retrieve($token);
  if ( !defined($session) or time() > $session->endtime or time() < $session->starttime )
  {
    throw Error::Simple('Could not locate valid session.');
  }

  $session->refresh_time(SESSION_LENGTH);

  return $session->{sourceid};    
}

1;
