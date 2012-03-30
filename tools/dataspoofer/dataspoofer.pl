#!/usr/bin/perl

use strict;

use RPC::Lite::Client;
use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

use Getopt::Long;
use Config::IniFiles;
use File::Spec;
use IO::Handle;
use Data::Dumper;

# NOTE this is not an effecient script by any stretch of the imagination,
#      it's not meant to import a great deal of data...

my $masterAddress = 'localhost';
my $masterPort    = 10000;
my $configFilename;
my %people;
my %companies;
my %relationships;

if (
     !GetOptions(
                  'config=s'        => \$configFilename,
                  'masterAddress=s' => \$masterAddress,
                  'masterPort=s'    => \$masterPort,
                )
   )
{
  die("Failed to understand command line options!");
}

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
    Transport  => $serverInfo->{transportType}->new( { Host => $serverInfo->{transportArgs}->{LocalAddr}, Port => $serverInfo->{transportArgs}->{ListenPort} } ),
    Serializer => $serverInfo->{serializerType}->new( $serverInfo->{serializerArgs} ),
  }
);
die("Could not connect to application server!") if !defined($applicationClient);

if ( !defined $configFilename )
{
  $configFilename = File::Spec->rel2abs('../config/fakeuserdata.dat');
}

if ( !-f $configFilename )
{
  die("Config file $configFilename doesn't exist!");
}

if ( !open( CONFIGFILE, "<$configFilename" ) )
{
  die("Failed to open config file: $configFilename");
}

STDOUT->autoflush(1);

my $curMode;
while ( my $line = <CONFIGFILE> )
{
  chomp($line);

  next if $line =~ /^\s*\#/o;
  next if !length($line);

  if ( $line =~ /^\s*\[(.*?)\]\s*$/o )
  {
    $curMode = lc($1);
    print "\n  ====== Switched to mode: $1 ======\n\n";
    next;
  }

  if ( length($curMode) )
  {
    no strict 'refs';
    &$curMode( split( /\|/, $line ) );
    use strict 'refs';
  }
  else
  {
    print "Got a line but had no current mode?\n";
  }

}

sub people
{
  my ( $email, $firstname, $middlename, $lastname, $address1, $address2, $city, $state, $zipcode, $country, $phone, $birthdate, $webpage, $im, $summary ) = @_;

  $applicationClient->Request(
                               'DoCreateAccount',
                               {
                                 email           => $email,
                                 firstname       => $firstname,
                                 middlename      => $middlename,
                                 lastname        => $lastname,
                                 address1        => $address1,
                                 address2        => $address2,
                                 city            => $city,
                                 state           => $state,
                                 zipcode         => $zipcode,
                                 country         => $country,
                                 phone           => $phone,
                                 birthdate       => $birthdate,
                                 webpage         => $webpage,
                                 im              => $im,
                                 summary         => $summary,
                                 password        => 'test',
                                 password_verify => 'test',
                               }
                             );

  my $userId = $applicationClient->Request( 'GetUserIdFromEmail', 'superuser', $email );

  if ( !exists( $people{$email} ) )
  {
    $people{$email} = $userId;
  }
  else
  {
    print "Added user [$email] twice?\n";
  }

  print "Added user [$email] ($people{$email})\n";
}

sub companies
{
  my ( $manager, $name, $address1, $address2, $city, $state, $zipcode, $country, $phone, $webpage, $summary ) = @_;

  if ( exists( $people{$manager} ) )
  {
    my $companyId = $applicationClient->Request(
      'AddCompany',
      'superuser',
      {
        name     => $name,
        address1 => $address1,
        address2 => $address2,
        city     => $city,
        state    => $state,
        zipcode  => $zipcode,
        country  => $country,
        phone    => $phone,
        webpage  => $webpage,
        summary  => $summary,
      },
      $people{$manager},    # manager's id
                                               );

    $companies{$name} = $companyId;
    print "Added company [$name] ($companyId)\n";
  }
  else
  {
    print "[$manager] is not a valid user!\n";
  }
}

sub relationships
{
  my ( $source, $target, $type, $bidirectional ) = @_;

  if ( !exists( $people{$source} ) and !exists( $companies{$source} ) )
  {
    print "Could not find a known user or company for relationship source [$source]!\n";
    return;
  }
  my $sourceId = exists( $people{$source} ) ? $people{$source} : $companies{$source};    # FIXME there are lots of issues with this line, i just don't care right now...

  if ( !exists( $people{$target} ) and !exists( $companies{$target} ) )
  {
    print "Could not find a known user or company for relationship target [$target]!\n";
    return;
  }
  my $targetId = exists( $people{$target} ) ? $people{$target} : $companies{$target};

  my $relationshipId = $applicationClient->Request( 'BeginRelationship', 'superuser', $targetId, $type, $sourceId );    # careful, tricky call, sourceId is an optional last param

  print "Added relationship [$source - $type -> $target] ($relationshipId)\n";
  $relationships{ $source . $type . $target } = $relationshipId;

  if ( defined($bidirectional) and $bidirectional )
  {
    $relationshipId = $applicationClient->Request( 'BeginRelationship', 'superuser', $sourceId, $type, $targetId );

    print "Added relationship [$target - $type -> $source] ($relationshipId)\n";
    $relationships{ $target . $type . $source } = $relationshipId;
  }
}

sub jobs
{
  my ( $company, $title, $location, $description ) = @_;

  if ( !exists( $companies{$company} ) )
  {
    print "Could not find company [$company] to add job!\n";
    return;
  }

  my $jobId = $applicationClient->Request(
                                           'AddJob',
                                           'superuser',
                                           $companies{$company},
                                           {
                                             title       => $title,
                                             location    => $location,
                                             description => $description,
                                           }
                                         );

  print "Added job [$title] for company [$company] ($jobId)\n";

}

sub resumes
{
  my ( $owner, $name, $description ) = @_;

  if ( !exists( $people{$owner} ) )
  {
    print "Error adding resume [$name]: Unknown user [$owner]\n";
    return;
  }

  my $resumeId = $applicationClient->Request(
                                              'AddResume',
                                              'superuser',
                                              {
                                                name        => $name,
                                                description => $description,
                                              },
                                              $people{$owner}
                                            );

  print "Added resume [$name] for user [$owner] ($resumeId)\n";
}

