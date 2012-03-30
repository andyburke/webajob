package AuthenticationDB::Session;

use strict;

use base qw(AuthenticationDB::DBI);
AuthenticationDB::Session->table('session');
AuthenticationDB::Session->columns(Primary => qw(token));
AuthenticationDB::Session->columns(Essential => qw(sourceid starttime endtime));


sub refresh_time
{
  # session_length is in seconds
  my ($self, $session_length) = @_;

  my $now = time();
  $self->starttime($now);
  $self->endtime($now + $session_length);
  $self->update;
}


1;
