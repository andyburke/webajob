package JobDB::Job;

use strict;

use base qw(JobDB::DBI);
__PACKAGE__->table('job');
__PACKAGE__->columns(Primary => qw(id));
__PACKAGE__->columns(Essential => qw(ownerid title location description));

1;
