package JobDB::JobApplication;

use strict;

use base qw(JobDB::DBI);
__PACKAGE__->table('application');
__PACKAGE__->columns(Primary => qw(id));
__PACKAGE__->columns(Essential => qw(job_id applicant_id resume_id paths date));

1;
