package JobDB::Rating;

use strict;

use base qw(JobDB::DBI);
__PACKAGE__->table('rating');
__PACKAGE__->columns(Primary => qw(application_id));
__PACKAGE__->columns(Essential => qw(user_id rating date));

1;
