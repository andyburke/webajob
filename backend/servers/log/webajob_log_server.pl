#!/usr/bin/perl
use strict;

my $server = Webajob::LogServer->new( { name => 'log' } );
$server->Loop;

package Webajob::LogServer;

use BackendServer;
use base qw(BackendServer);

use Data::Dumper;

sub new
{
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  $self->{sth_insert_channel} = $self->Dbh->prepare("INSERT into log_channel(name) values (?);");
  $self->{sth_insert_level}   = $self->Dbh->prepare("INSERT into log_level(name) values (?);");
  $self->{sth_insert_message} = $self->Dbh->prepare("INSERT into log_entry (channelid, levelid, time, entry) values (?,?,?,?);");

  $self->{sth_select_channel_id} = $self->Dbh->prepare("SELECT id from log_channel where name = ?;");
  $self->{sth_select_level_id}   = $self->Dbh->prepare("SELECT id from log_level where name = ?;");

  return $self;
}

sub CreateChannel
{
  my $self        = shift;
  my $channelName = shift;

  $self->{sth_select_channel_id}->execute($channelName);
  my ($result) = $self->{sth_select_channel_id}->fetchrow_array;

  if ($result)
  {
    throw Error::Simple("Channel name, [$channelName] already exists in database.");
  }

  $self->{sth_insert_channel}->execute($channelName);

  return 1;
}

sub CreateLevel
{
  my $self      = shift;
  my $levelName = shift;

  ## Todo ## - Check to see if levelName already exists in table
  $self->{sth_select_level_id}->execute($levelName);
  my ($result) = $self->{sth_select_level_id}->fetchrow_array;

  if ($result)
  {
    throw Error::Simple("Level name, [$levelName] already exists in database. ");
  }
  $self->{sth_insert_level}->execute($levelName);

  return 1;
}

sub Log
{
  my ( $self, $message, $channelName, $levelName ) = @_;

  #Set default channel and level names
  if ( not defined $channelName ) { $channelName = 'defaultchannel' }
  if ( not defined $levelName )   { $levelName   = 'defaultlevel' }

  #Check to see if channelName and levelName exists in db and get their id's
  $self->{sth_select_channel_id}->execute($channelName);

  my ($channelId) = $self->{sth_select_channel_id}->fetchrow_array;
  if ( !$channelId )
  {
    throw Error::Simple("Channel name, [$channelName] does not exists in database. ");
  }

  $self->{sth_select_level_id}->execute($levelName);

  my ($levelId) = $self->{sth_select_level_id}->fetchrow_array;
  if ( !$levelId )
  {
    throw Error::Simple("Level name, [$levelName] does not exists in database. ");
  }

  
  $self->{sth_insert_message}->execute( $channelId, $levelId, time, $message );

  return 1;
}

1;
