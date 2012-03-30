package PermissionDB::Permission;

use strict;

use base qw(PermissionDB::DBI);
PermissionDB::Permission->table('permission');
PermissionDB::Permission->columns(Primary   => qw(sourceid targetid typeid));
PermissionDB::Permission->columns(Essential => qw(expiration_time));
PermissionDB::Permission->has_a(typeid => 'PermissionDB::Type');


sub is_expired
{
  my $self = shift;
  return (defined $self->expiration_time and $self->expiration_time < time());
}


1;
