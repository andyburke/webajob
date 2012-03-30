package main;

sub EditJob
{
  $validUser or return $bad_user_error;

  my $job = AppserverCall( 'GetJob', $cgi_params->{job_id} );

  # FIXME should be company
  my $userInfo = AppserverCall( 'GetUserInfo', $job->{ownerid} );

  foreach my $key ( keys(%$job) )
  {
    $hdf->setValue( "job.$key", $job->{$key} );
  }

  foreach my $key ( keys(%$userInfo) )
  {
    $hdf->setValue( "userinfo.$key", $userInfo->{$key} );
  }
}

1;