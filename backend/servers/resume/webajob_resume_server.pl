#!/usr/bin/perl
use strict;

my $server = Webajob::ResumeServer->new( { name => 'resume' } );
$server->Loop;

package Webajob::ResumeServer;

use BackendServer;
use base qw(BackendServer);

use Error;

use ResumeDB::DBI;
use ResumeDB::Resume;

sub new
{
  my $class = shift;
  
  my $self = $class->SUPER::new(@_);

  ResumeDB::DBI->set_db( 'Main', @{ $self->dbConfig } );

  return $self;
}

sub Add
{
  my $self       = shift;
  my $ownerId    = shift;
  my $resumeData = shift;

  my @resumes = ResumeDB::Resume->search( { ownerid => $ownerId } );

  if ( @resumes > 2 )
  {
    throw Error::Simple('Adding another resume would exceed the maximum allowed.');
  }

  my $resumeId = $self->Call( 'id.GetId', 'resume' );

  my $newResume = ResumeDB::Resume->create(
                                            {
                                              id                  => $resumeId,
                                              ownerid             => $ownerId,
                                              name                => $resumeData->{name},
                                              description         => $resumeData->{description},
                                            }
                                          );

  $newResume->update();

  return $newResume->id;

}

sub Delete
{
  my $self     = shift;
  my $resumeId = shift;

  my $resume = ResumeDB::Resume->retrieve($resumeId);

  if ( !$resume )
  {
    throw Error::Simple('Could not locate resume for deletion.');
  }

  $resume->delete();
  return 1;
}

sub Edit
{
  my $self       = shift;
  my $resumeId   = shift;
  my $resumeData = shift;

  my $resume = ResumeDB::Resume->retrieve($resumeId);
  if ( !$resume )
  {
    throw Error::Simple('Could not locate resume for editing.');
  }

  my @columns = $resume->columns();

  foreach my $column (@columns)
  {
    if ( exists( $resumeData->{$column} ) )
    {
      $resume->set( $column => $resumeData->{$column} );
    }
  }

  $resume->update();
  return 1;
}

sub Get
{
  my $self     = shift;
  my $resumeId = shift;

  my $resume = ResumeDB::Resume->retrieve($resumeId);
  if ( !$resume )
  {
    throw Error::Simple('Could not locate resume for retrieval.');
  }

  my $resumeData = {};
  foreach my $column ($resume->columns)
  {
    $resumeData->{$column} = $resume->{$column};
  }

  return $resumeData;
}

sub GetAllByOwner
{
  my $self    = shift;
  my $ownerId = shift;

  my @resumes = ResumeDB::Resume->search( { ownerid => $ownerId } );

  foreach my $resume (@resumes)
  {
    my $resumeData = {};
    foreach my $column ($resume->columns)
    {
      $resumeData->{$column} = $resume->{$column};
    }
    $resume = $resumeData;
  }

  return \@resumes;
}

sub Search
{
  my $self           = shift;
  my $resumeCriteria = shift;

  foreach my $key (keys(%$resumeCriteria))
  {
    $resumeCriteria->{$key} = '%' . $resumeCriteria->{$key} . '%';
  }
  
  my @resumes = ResumeDB::Resume->search_like($resumeCriteria);

  foreach my $resume (@resumes)
  {
    my $resumeData = {};
    foreach my $column ($resume->columns)
    {
      $resumeData->{$column} = $resume->{$column};
    }
    $resume = $resumeData;
  }

  return \@resumes;
}

1;    
