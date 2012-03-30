package main;

sub ConfirmDeleteJob
{
  $validUser or return $bad_user_error;

  my $job = AppserverCall( 'GetJob', $cgi_params->{job_id} );

  foreach my $key ( keys(%$job) )
  {
    $hdf->setValue( "job.$key", $job->{$key} );
  }
}

1;