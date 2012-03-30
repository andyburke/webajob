#!/usr/bin/perl
use strict;

my $server = Webajob::UserInfoServer->new( { name => 'userinfo' } );
$server->Loop;

package Webajob::UserInfoServer;

use BackendServer;
use base qw(BackendServer);

use Error;
use GD;
use MIME::Base64;
use Data::Dumper;

use UserInfoDB::DBI;
use UserInfoDB::User;
use UserInfoDB::Photo;

sub new
{
  my $class = shift;
  
  my $self = $class->SUPER::new(@_);
  UserInfoDB::DBI->set_db( 'Main', @{ $self->dbConfig } );

  return $self;
}

sub GetIdFromEmail
{
  my $self  = shift;
  my $email = shift;

  my ($user) = UserInfoDB::User->search( { email => $email } );
  if ( !defined($user) )
  {
    return '';
  }
  return $user->{id};
}

sub Add
{
  my $self = shift;
  my $data = shift;

  my $userId = $self->Call( 'id.GetId', 'user' );

  my $user = UserInfoDB::User->create(
                                       {
                                         id         => $userId,
                                         email      => $data->{email},
                                         firstname  => $data->{firstname},
                                         middlename => $data->{middlename},
                                         lastname   => $data->{lastname},
                                         address1   => $data->{address1},
                                         address2   => $data->{address2},
                                         city       => $data->{city},
                                         state      => $data->{state},
                                         zipcode    => $data->{zipcode},
                                         country    => $data->{country},
                                         phone      => $data->{phone},
                                         birthdate  => $data->{birthdate},
                                         webpage    => $data->{webpage},
                                         im         => $data->{im},
                                         summary    => $data->{summary},
                                       }
                                     );

  if ( !$user )
  {
    throw Error::Simple("Could not create database entry for new user: $!");
  }

  return $userId;
}

sub Edit
{
  my $self     = shift;
  my $userId   = shift;
  my $userData = shift;

  my $user = UserInfoDB::User->retrieve($userId);
  if ( !$user )
  {
    throw Error::Simple('Could not locate user for editing.');
  }

  my @columns = $user->columns();

  foreach my $column (@columns)
  {
    if ( exists( $userData->{$column} ) )
    {
      $user->set( $column => $userData->{$column} );
    }
  }

  $user->update();
  return 1;
}

sub Delete
{
  my $userId = shift;

  my $user = UserInfoDB::User->retrieve($userId);
  if ( !$user )
  {
    throw Error::Simple('Could not locate user for deletion.');
  }

  $user->delete();
  return 1;
}

sub GetInfo
{
  my $self      = shift;
  my $userId    = shift;
  my $wantArray = ref($userId) eq 'ARRAY' ? 1 : undef;

  my @userIds = $wantArray ? @$userId : ($userId);
  my @users;
  print Dumper(\@userIds);
  foreach my $id (@userIds)
  {
    my $user = UserInfoDB::User->retrieve($id);
    if ( !defined($user) )
    {
      throw Error::Simple("Invalid user id: $id");    #FIXME security?
    }
    push @users, $user;
  }

  foreach my $user (@users)
  {
    my $userHash = {};
    foreach my $field ($user->columns())
    {
      $userHash->{$field} = $user->{$field};
    }
    $user = $userHash;
  }


  return $wantArray ? \@users : $users[0];
}

sub Search
{
  my $self       = shift;
  my $parameters = shift;
  my $maxResults = shift;
  my $offset     = shift || 0;

  foreach my $key (keys(%$parameters))
  {
    $parameters->{$key} = '%' . $parameters->{$key} . '%';
  }

  # FIXME caching
  my @users = UserInfoDB::User->search_like($parameters);
  if ($maxResults)
  {
    @users = splice( @users, $offset, $maxResults );
  }

  foreach my $user (@users)
  {
    my $userHash = {};
    foreach my $field ($user->columns())
    {
      $userHash->{$field} = $user->{$field};
    }
    $user = $userHash;
  }

  return \@users;
}

sub EditPhoto
{
  my $self         = shift;
  my $userId       = shift;
  my $imageData    = shift;
  my $maxDimension = shift;

  my $user = UserInfoDB::User->retrieve($userId);
  if ( !$user )
  {
    throw Error::Simple('Could not locate user to set photo.');
  }

  # scale image down, if requested and image actually needs it
  if ( defined $maxDimension )
  {
    if ( $maxDimension <= 0 )
    {
      throw Error::Simple('Photo maximum dimension must be greater than zero.');
    }

    my $image = GD::Image->new($imageData);

    # set scale to maxDimension over largest image dimension
    my $scale = $maxDimension / ( $image->width > $image->height ? $image->width : $image->height );
    if ( $scale < 1 )    # image does actually need to be scaled down
    {
      my $scaledImage = GD::Image->new( $image->width * $scale, $image->height * $scale, 1 );
      $scaledImage->copyResampled( $image, 0, 0, 0, 0, $scaledImage->width, $scaledImage->height, $image->width, $image->height );
      $imageData = $scaledImage->jpeg;
    }
  }

  $user->photodata($imageData);
  $user->update;

  return 1;
}

sub GetPhoto
{
  my $self   = shift;
  my $userId = shift;

  my $user = UserInfoDB::User->retrieve($userId);
  if ( !$user )
  {
    throw Error::Simple('Could not locate user to get photo.');
  }

  return encode_base64($user->photodata);
}

sub GetPhotoInfo
{
  my $self   = shift;
  my $userId = shift;

  my $user = UserInfoDB::User->retrieve($userId);
  if ( !$user )
  {
    throw Error::Simple('Could not locate user to get photo.');
  }

  if ( $user->photo )
  {
    my $image = GD::Image->new( $user->photodata );
    return {
             exists      => 1,
             width       => $image->width,
             height      => $image->height,
             data_length => length( $user->photodata ),
           };
  }
  else
  {
    return {};
  }
}

sub DeletePhoto
{
  my $self   = shift;
  my $userId = shift;

  my $user = UserInfoDB::User->retrieve($userId);
  if ( !$user )
  {
    throw Error::Simple('Could not locate user to delete photo.');
  }

  $user->photo->delete;

  return 1;
}

1;    

