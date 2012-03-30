#!/usr/bin/perl
use strict;

my $server = Webajob::PermissionServer->new( {name => 'permission' });
$server->Loop;

package Webajob::PermissionServer;

use BackendServer;
use base qw(BackendServer);

use Error;
use PermissionDB::DBI;
use PermissionDB::Permission;
use PermissionDB::Type;

sub new
{
  my $class = shift;
  
  my $self = $class->SUPER::new(@_);

  PermissionDB::DBI->set_db( 'Main', @{ $self->dbConfig } );

  return $self;
}

sub Check
{
  my $self = shift;
  my $sourceId       = shift;
  my $targetId       = shift;
  my $permissionType = shift;

  # FIXME super user's uuid is just encoded here... lame.
  if ( $sourceId == '63EE5C90-4734-11DA-A62D-F099B7EBB437' )    # superuser can do anything...
  {
    return 1;
  }

  my $validType = 0;
  if ( $permissionType =~ /^\d+$/ )
  {
    $validType = PermissionDB::Type->retrieve($permissionType);
  }
  else
  {
    ($validType) = PermissionDB::Type->search( { name => $permissionType } );
  }

  if ( !$validType )
  {
    throw Error::Simple('Invalid permission type.' );
  }

  my ($permission) = PermissionDB::Permission->search(
                                                       {
                                                         sourceid => $sourceId,
                                                         targetid => $targetId,
                                                         typeid   => $validType->id,
                                                       }
  );

  if ( !$permission )
  {
    return 0;
  }

  if ( $permission->is_expired )
  {
    $permission->delete;
    return 0;
  }

  return 1;
}

sub Search
{
  my $self = shift;
  my $sourceId       = shift;
  my $targetId       = shift;
  my $permissionType = shift;

  if ( length $permissionType and $permissionType )
  {
    if ( $permissionType =~ /^\d+$/ )
    {
      $permissionType = PermissionDB::Type->retrieve($permissionType);
    }
    else
    {
      ($permissionType) = PermissionDB::Type->search( { name => $permissionType } );
    }

    if ( !$permissionType )
    {
      throw Error::Simple('Invalid permission type.' );
    }

    $permissionType = $permissionType->id;
  }

  my $criteria;
  $criteria->{sourceid} = $sourceId       if $sourceId;
  $criteria->{targetid} = $targetId       if $targetId;
  $criteria->{typeid}   = $permissionType if $permissionType;

  my @permissions = PermissionDB::Permission->search($criteria);
  foreach my $permission (@permissions)
  {
    if ( $permission->is_expired )
    {
      $permission->delete;
      $permission = undef;
    }
  }
  @permissions = grep { $_ } @permissions;

  foreach my $permission (@permissions)
  {
    my $permissionHash = {};
    foreach my $field ($permission->columns())
    {
      $permissionHash->{$field} = $permission->{$field};
      $permissionHash->{$field} = $permission->{$field}->{id} if $field eq 'typeid';
    }
    $permission = $permissionHash;
  }

  return \@permissions;
}

sub Grant
{
  my $self = shift;
  my $sourceId       = shift;
  my $targetId       = shift;
  my $permissionType = shift;
  my $expirationTime = shift;

  my $validType = 0;
  if ( $permissionType =~ /^\d+$/ )
  {
    $validType = PermissionDB::Type->retrieve($permissionType);
  }
  else
  {
    ($validType) = PermissionDB::Type->search( { name => $permissionType } );
  }

  if ( !$validType )
  {
    throw Error::Simple( 'Invalid persmission type.' );
  }

  my $permission = PermissionDB::Permission->create(
                                                     {
                                                       sourceid        => $sourceId,
                                                       targetid        => $targetId,
                                                       typeid          => $validType->id,
                                                       expiration_time => $expirationTime,
                                                     }
  );
  $permission->update();    # commit

  if ( !$permission )
  {
    throw Error::Simple('Could not create a new permission entry!' );
  }

  return 1;
}

sub Revoke
{
  my $self = shift;
  my $sourceId       = shift;
  my $targetId       = shift;
  my $permissionType = shift;

  my $validType = 0;
  if ( $permissionType =~ /^\d+$/ )
  {
    $validType = PermissionDB::Type->retrieve($permissionType);
  }
  else
  {
    ($validType) = PermissionDB::Type->search( { name => $permissionType } );
  }

  if ( !$validType )
  {
    throw Error::Simple( 'Invalid permission type.' );
  }

  my ($permission) = PermissionDB::Permission->search(
                                                       {
                                                         sourceid => $sourceId,
                                                         targetid => $targetId,
                                                         typeid   => $validType->id,
                                                       }
  );

  if ( !$permission )
  {
    return 0;
  }

  $permission->delete();    # FIXME assume this works? docs don't say what its return value is
  return 1;
}

sub GetType
{
  my $typeName = shift;

  my ($validType) = PermissionDB::Type->search( { name => $typeName } );

  if ( !$validType )
  {
    throw Error::Simple('Invalid permission type.');
  }

  $validType->get('id');
  return $validType->id;
}

1;
