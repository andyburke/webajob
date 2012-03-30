#!/usr/bin/perl

use strict;

my $server = Webajob::JobServer->new( { name => 'job' } );
$server->Loop;

package Webajob::JobServer;

use BackendServer;
use base qw(BackendServer);

use Error;
use JobDB::DBI;
use JobDB::Job;
use JobDB::JobApplication;
use JobDB::Rating;

sub new
{
  my $class = shift;
  
  my $self = $class->SUPER::new(@_);

  JobDB::DBI->set_db( 'Main', @{ $self->dbConfig } );

  return $self;
}

sub Add
{
  my $self    = shift;
  my $ownerId = shift;
  my $jobData = shift;

  my $jobId = $self->Call( 'id.GetId', 'job' );

  my $newJob = JobDB::Job->create(
                                   {
                                     id          => $jobId,
                                     ownerid     => $ownerId,
                                     title       => $jobData->{title},
                                     location    => $jobData->{location},
                                     description => $jobData->{description},
                                   }
                                 );

  $newJob->update();

  return $newJob->id;

}

sub Delete
{
  my $self  = shift;
  my $jobId = shift;

  my $job = JobDB::Job->retrieve($jobId);

  if ( !$job )
  {
    throw Error::Simple('Could not locate job for deletion.');
  }

  $job->delete();
  return 1;
}

sub Edit
{
  my $self    = shift;
  my $jobId   = shift;
  my $jobData = shift;

  my $job = JobDB::Job->retrieve($jobId);
  if ( !$job )
  {
    throw Error::Simple('Could not locate job for editing.');
  }

  my @columns = $job->columns();

  foreach my $column (@columns)
  {
    if ( exists( $jobData->{$column} ) )
    {
      $job->set( $column => $jobData->{$column} );
    }
  }

  $job->update();
  return 1;
}

sub Get
{
  my $self  = shift;
  my $jobId = shift;

  my $job = JobDB::Job->retrieve($jobId);
  if ( !$job )
  {
    throw Error::Simple('Could not locate job for retrieval.');
  }

  return $job;
}

sub GetByCompany
{
  my $self    = shift;
  my $ownerId = shift;

  return $self->Search( { ownerid => $ownerId } );
}

sub Search
{
  my $self        = shift;
  my $jobCriteria = shift;

  foreach my $key (keys(%$jobCriteria))
  {
    $jobCriteria->{$key} = '%' . $jobCriteria->{$key} . '%';
  }

  my @jobs = JobDB::Job->search_like($jobCriteria);

  return \@jobs;
}

sub Apply
{
  my $self        = shift;
  my $jobId       = shift;
  my $applicantId = shift;
  my $resumeId    = shift;

  my $jobApplicationId = $self->Call( 'id.GetId', 'jobApplication' );

  my $newJobApplication = JobDB::JobApplication->create(
                                                         {
                                                           id           => $jobApplicationId,
                                                           job_id       => $jobId,
                                                           applicant_id => $applicantId,
                                                           resume_id    => $resumeId,
                                                           date         => time(),
                                                         }
                                                       );

  $newJobApplication->update();

  return $newJobApplication->id;
}

sub GetApplications
{
  my $self  = shift;
  my $jobId = shift;

  my @jobApplications = JobDB::JobApplication->search( { job_id => $jobId } );

  foreach my $jobApplication (@jobApplications)
  {
    my @ratings = JobDB::Rating->search( { application_id => $jobApplication->{id} } );
    $jobApplication->{ratings} = \@ratings;
  }

  return \@jobApplications;
}

sub GetApplication
{
  my $self          = shift;
  my $applicationId = shift;

  my $jobApplication = JobDB::JobApplication->retrieve($applicationId);
  throw Error::Simple("No such job application.") if !$jobApplication;

  my @ratings = JobDB::Rating->search( { application_id => $jobApplication->{id} } );
  $jobApplication->{ratings} = \@ratings;

  return $jobApplication;
}

sub RateApplication
{
  my $self          = shift;
  my $applicationId = shift;
  my $userId        = shift;
  my $rating        = shift;

  my $jobApplication = JobDB::JobApplication->retrieve($applicationId);
  throw Error::Simple("No such job application.") if ( !$jobApplication );

  my $applicationRating = JobDB::Rating->create(
                                                 {
                                                   application_id => $applicationId,
                                                   user_id        => $userId,
                                                   rating         => $rating,
                                                   date           => time()
                                                 }
                                               );

  return 1;
}

sub SetApplicationPaths
{
  my $self             = shift;
  my $applicationId    = shift;
  my $applicationPaths = shift;

  my $jobApplication = JobDB::JobApplication->retrieve($applicationId);
  throw Error::Simple("No such job application.") if ( !$jobApplication );

  $jobApplication->set( paths => $applicationPaths );
  $jobApplication->update();

  return 1;    

}

1;
