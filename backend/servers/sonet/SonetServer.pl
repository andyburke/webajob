#!/usr/bin/perl

use strict;
use Data::Dumper;
use MIME::Base64;

my $server = Webajob::Sonet->new( { name => 'sonet' } );    
$server->Loop;

package Webajob::Sonet;

use BackendServer;
use base qw(BackendServer);

use Error;

sub Authenticate
{
  my $self  = shift;
  my $email = shift;
  my $key   = shift;

  my $userId = $self->Call( 'userinfo.GetIdFromEmail', $email );
  throw Error::Simple('Unknown user.') if ( $userId eq '' );    # id '' == unknown user

  return $self->Call( 'authentication.Authenticate', $userId, $key );
}

sub CreateAccount
{
  my $self = shift;
  my $emailAddress = shift;
  my $password = shift;

  my $userId = $self->Call( 'id.GetId', 'user' );
  
  if ( $self->Call( 'authentication.SetKey', $userId, $password ) )
  {
    return 1;
  }

  return 0;
}

sub GetUserInfo
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $userId        = shift || $currentUserId;

  return $self->Call( 'userinfo.GetInfo', $userId );
}

sub EditUserInfo
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $userinfoData  = shift;

  return $self->Call( 'userinfo.Edit', $currentUserId, $userinfoData );
}

sub GetUserPhoto
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $userId        = shift || $currentUserId;

  return $self->Call( 'userinfo.GetPhoto', $userId );
}

sub GetUserPhotoInfo
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $userId        = shift || $currentUserId;

  return $self->Call( 'userinfo.GetPhotoInfo', $userId );
}

sub EditUserPhoto
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $photoData     = shift;

  # FIXME: max dimension of 100 should be set in a global config or something
  return $self->Call( 'userinfo.EditPhoto', $currentUserId, encode_base64($photoData), 100 );
}

sub DeleteUserPhoto
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();

  return $self->Call( 'userinfo.DeletePhoto', $currentUserId );
}

sub GetUserIdFromSessionToken
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();

  return $currentUserId;
}

sub GetUserIdFromEmail
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $email         = shift;

  my $userId = $self->Call( 'userinfo.GetIdFromEmail', $email );

  if ( !$userId )
  {

    # FIXME return 0?
    throw Error::Simple("Invalid user email address.");
  }

  return $userId;
}

sub SearchUsers
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $parameters    = shift;
  my $pageNumber    = shift || 1;

  return $self->Call( 'userinfo.Search', $parameters, ( $pageNumber - 1 ) * 10, 10 );
}

sub BeginRelationship
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $targetId      = shift;
  my $typeId        = shift;
  my $sourceId      = shift || $currentUserId;

  return $self->Call( 'socialnetwork.BeginRelationship', $sourceId, $targetId, $typeId );
}

sub EndRelationship
{
  my $self           = shift;
  my $currentUserId  = $self->GetUserId(shift) or return InvalidSessionFault();
  my $relationshipId = shift;

  my $relationship = $self->Call( 'socialnetwork.GetRelationship', $relationshipId );

  if ( $currentUserId != $relationship->{source} )
  {
    throw Error::Simple("This isn't your relationship.");
  }

  return $self->Call( 'socialnetwork.EndRelationship', $relationshipId );
}

sub GetRelationship
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();

  return $self->Call( 'socialnetwork.GetRelationship', @_ );
}

sub GetRelatedEntities
{
  my $self            = shift;
  my $currentUserId   = $self->GetUserId(shift) or return InvalidSessionFault();
  my $sourceId        = shift;
  my $radius          = shift || 1;
  my $finalEntityType = shift;

  # If not asking for logged in user's relationships, ensure the requested
  # user has a relationship back to the logged in user.
  if ( $sourceId != $currentUserId )
  {
    my $hasRelationship = $self->Call( 'socialnetwork.HasRelationship', $sourceId, $currentUserId );
    if ( !$hasRelationship )
    {
      return {};
    }
  }

  return $self->Call( 'socialnetwork.GetRelatedEntities', $sourceId, $radius, $finalEntityType );
}

sub GetAllowedRelationshipTypes
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $sourceType    = shift;
  my $targetType    = shift;

  return $self->Call( 'socialnetwork.GetAllowedRelationshipTypes', $sourceType, $targetType );
}

sub GetRelationshipTypeName
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $typeId        = shift;

  return $self->Call( 'socialnetwork.GetRelationshipTypeName', $typeId );
}

sub GetPaths
{
  my $self = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my ( $sourceId, $destId, $reciprocal ) = @_;

  return $self->Call( 'socialnetwork.GetPaths', $sourceId, $destId, $reciprocal );
}

sub GetShortestPaths
{
  my $self = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my ( $sourceId, $destId, $reciprocal ) = @_;

  return $self->Call( 'socialnetwork.GetShortestPaths', $sourceId, $destId, $reciprocal );
}

# ==============================================================

sub GetUserId
{
  my $self      = shift;
  my $sessionId = shift;
  return $self->Call( 'authentication.GetUserIdFromSessionToken', $sessionId );
}

sub InvalidSessionFault
{
  throw Error::Simple("Invalid session");
}

