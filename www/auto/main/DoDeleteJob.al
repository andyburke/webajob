package main;

sub DoDeleteJob
{
  $validUser or return $bad_user_error;

  AppserverCall( 'DeleteJob', $cgi_params->{job_id} );
}

1;