package AuthenticationDB::Credential;

use strict;

use base qw(AuthenticationDB::DBI);
AuthenticationDB::Credential->table('credential');
AuthenticationDB::Credential->columns(Primary => qw(sourceid));
AuthenticationDB::Credential->columns(Others => qw(key));

1;
