package PermissionDB::Type;

use strict;

use base qw(PermissionDB::DBI);
PermissionDB::Type->table('permission_type');
PermissionDB::Type->columns(Primary => qw(id));
PermissionDB::Type->columns(Essential => qw(name));

1;
