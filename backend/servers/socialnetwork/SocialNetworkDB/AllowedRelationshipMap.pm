package SocialNetworkDB::AllowedRelationshipMap;

use strict;

use base qw(SocialNetworkDB::DBI);
__PACKAGE__->table('allowed_relationship_map');
__PACKAGE__->columns(Primary => qw(sourcetype targettype relationshiptypeid));
__PACKAGE__->has_a(relationshiptypeid => 'SocialNetworkDB::RelationshipType');

1;
