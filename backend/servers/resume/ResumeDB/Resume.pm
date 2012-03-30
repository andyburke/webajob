package ResumeDB::Resume;

use strict;

use base qw(ResumeDB::DBI);
ResumeDB::Resume->table('resume');
ResumeDB::Resume->columns(Primary => qw(id));
ResumeDB::Resume->columns(Essential => qw(ownerid name description));

1;
