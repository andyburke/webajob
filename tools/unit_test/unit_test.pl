#!/usr/bin/perl

use strict;

use RPC::Lite::Client;
use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

use Test::More tests => 53;
use Getopt::Long;
use Config::IniFiles;
use File::Spec;
use IO::Handle;
use Data::Dumper;

my $masterAddress = 'localhost';
my $masterPort    = 10000;

my @digits = (0..9);
my @alphaNumeric = ('a'..'z', 'A'..'Z', @digits);

#################################################################
## set up appserver connection...

my $masterServerClient = RPC::Lite::Client->new(
                                                 {
                                                   Transport => RPC::Lite::Transport::TCP->new(
                                                                                                {
                                                                                                  Host => $masterAddress,
                                                                                                  Port => $masterPort,
                                                                                                }
                                                                                              ),
                                                   Serializer => RPC::Lite::Serializer::JSON->new(),
                                                 }
                                               );
die("Could not connect to master server!") if !defined($masterServerClient);

my $serverInfo = $masterServerClient->Request( 'GetInfo', 'application' );
die("Could not get application server info!") if !defined($serverInfo);

my $applicationClient = RPC::Lite::Client->new(
                                                {
                                                  Transport => $serverInfo->{transportType}->new(
                                                                                                  {
	Host => $serverInfo->{transportArgs}->{LocalAddr},
	Port => $serverInfo->{transportArgs}->{ListenPort}
                                                                                                  }
                                                                                                ),
                                                  Serializer => $serverInfo->{serializerType}->new( $serverInfo->{serializerArgs} ),
                                                }
                                              );
die("Could not connect to application server!") if !defined($applicationClient);

my @methods = qw{
  BuyCredits
  GetPurchaseRates
  GetPrice
  GetAccountBalance
  EditUserInfo
  EditUserPhoto
  DeleteUserPhoto
  GetUserIdFromSessionToken
  GetUserIdFromEmail
  SearchUsers
  BeginRelationship
  EndRelationship
  GetRelationship
  GetRelatedEntities
  GetAllowedRelationshipTypes
  GetRelationshipTypeName
  GetResume
  GetResumes
  AddResume
  EditResume
  DeleteResume
  AddCompany
  GetCompanyInfo
  EditCompanyInfo
  GetManagedCompanyIds
  CanManageCompany
  AddJob
  GetJob
  GetJobsByCompany
  EditJob
  DeleteJob
  SearchJobs
  SearchResumes
  SendEmail
  Notify
  ApplyForJob
  GetJobApplications
  GetJobApplication
  SetApplicationPaths
  RateJobApplicant
  GetPaths
  GetShortestPaths};

foreach my $methodName (@methods)
{
  check_invalidSession($methodName);
}

my $sessionId;

### DoLogin
eval { $sessionId = $applicationClient->Request( 'DoLogin', 'aburke@bitflood.org', 'test' ) };
ok( !$@, 'DoLogin' );

eval { $applicationClient->Request( 'DoLogin', 'invalid email@example.com' ) };
isa_exception( 'Unknown user.', 'DoLogin invalid email' );

eval { $applicationClient->Request( 'DoLogin', 'aburke@bitflood.org', 'invalid password' ) };
isa_exception( 'Bad password.', 'DoLogin invalid password' );

### DoCreateAccount
my $newEmailAddress = GenerateRandomAlphaNumeric(8) . '@test.com';
my $success = $applicationClient->Request(
  'DoCreateAccount',
  {
    password        => 'test',
    password_verify => 'test',                
    email           => $newEmailAddress,
    firstname       => GenerateRandomAlphaNumeric(),
    middlename      => GenerateRandomAlphaNumeric(),
    lastname        => GenerateRandomAlphaNumeric(),
    address1        => GenerateRandomInteger(3) . ' ' . GenerateRandomAlphaNumeric(),
    address2        => GenerateRandomAlphaNumeric(),
    city            => GenerateRandomAlphaNumeric(),
    state           => GenerateRandomAlphaNumeric(),
    zipcode         => GenerateRandomInteger(5),
    country         => GenerateRandomAlphaNumeric(2),
    phone           => GenerateRandomInteger(10),
    birthdate       => GenerateRandomInteger(20),
    webpage         => 'http://' . GenerateRandomAlphaNumeric() . '.com',
    im              => GenerateRandomAlphaNumeric(),
    summary         => join(' ', map { GenerateRandomAlphaNumeric() } 0..20),
  }
);
ok( $success, 'DoCreateAccount' );

### BuyCredits

### GetPurchaseRates

### GetPrice
my $testPrice = $applicationClient->Request( 'GetPrice', $sessionId, 'ListJob' );

# matching digits only
like( $testPrice, qr/^\d+$/, 'GetPrice' );

eval { $applicationClient->Request( 'GetPrice', $sessionId, 'invalid type' ) };
isa_exception( 'Unable to find a price for product:[invalid type]', 'GetPrice invalid type' );

### GetAccountBalance
eval { $applicationClient->Request( 'GetAccountBalance', $sessionId ) };
ok( !$@, 'GetAccountBalance' );

### GetUserInfo
eval { $applicationClient->Request( 'GetUserInfo', $sessionId ) };
ok( !$@, 'GetUserInfo' );

eval { $applicationClient->Request( 'GetUserInfo', 'invalid user' ) };
isa_exception( 'Could not locate valid session.', 'GetUserInfo invalid user' );

### EditUserInfo

### GetUserPhoto
eval { $applicationClient->Request( 'GetUserPhoto', $sessionId ) };
ok( !$@, 'GetUserPhoto' );

### GetUserPhotoInfo
eval { $applicationClient->Request( 'GetUserPhotoInfo', $sessionId ) };
ok( !$@, 'GetUserPhotoInfo' );

### EditUserPhoto

### DeleteUserPhoto

### GetUserIdFromSessionToken
eval { $applicationClient->Request( 'GetUserIdFromSessionToken', $sessionId ) };
ok( !$@, 'GetUserIdFromSessionToken' );

### GetUserIdFromEmail

### SearchUsers

### BeginRelationship

### EndRelationship

### GetRelationship
#eval { $applicationClient->Request( 'GetRelationship', $sessionId, '?') };
#ok ( !$@, 'GetRelationship' );

### GetRelatedEntities

### GetAllowedRelationshipTypes

### GetRelationshipTypeName

### GetResume

### GetResumes

### AddResume

### EditResume

### DeleteResume

### AddCompany

### GetCompanyInfo

### EditCompanyInfo

### GetManagedCompanyIds

### CanManageCompany

### AddJob

### GetJob

### GetJobsByCompany

### EditJob

### DeleteJob

### SearchJobs

### Helper functions
sub check_invalidSession
{
  my $methodName = shift;
  eval { $applicationClient->Request( $methodName, 'invalid user' ) };
  isa_exception( 'Could not locate valid session.', "$methodName invalid session" );
}

sub isa_exception
{
  my $string    = shift;
  my $test_name = shift;
  isa_exception_match( qr/\Q$string\E/, $test_name );
}

sub isa_exception_match
{
  my $match     = shift;
  my $test_name = shift;
  ok( UNIVERSAL::isa( $@, 'Error::Simple' ) && $@ =~ $match, $test_name );
}

sub GenerateRandomAlphaNumeric
{
  my $length = shift || rand(20);
  return join('', map { $alphaNumeric[rand @alphaNumeric] } 0..$length-1); 
}

sub GenerateRandomInteger
{
  my $length = shift || rand(20);
  return join('', map { $digits[rand @digits] } 0..$length-1);;
}