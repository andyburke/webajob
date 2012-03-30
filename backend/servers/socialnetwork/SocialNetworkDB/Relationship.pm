package SocialNetworkDB::Relationship;

use strict;

use base qw(SocialNetworkDB::DBI);
SocialNetworkDB::Relationship->table('relationship');
SocialNetworkDB::Relationship->columns(Primary => qw(id));
SocialNetworkDB::Relationship->columns(Essential => qw(source destination type start_date end_date));
SocialNetworkDB::Relationship->has_a( type => 'SocialNetworkDB::RelationshipType');

1;
