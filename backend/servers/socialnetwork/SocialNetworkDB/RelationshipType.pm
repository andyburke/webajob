package SocialNetworkDB::RelationshipType;

use strict;

use base qw(SocialNetworkDB::DBI);
__PACKAGE__->table('relationship_type');
__PACKAGE__->columns(Primary => qw(id));
__PACKAGE__->columns(Essential => qw(name));

1;
