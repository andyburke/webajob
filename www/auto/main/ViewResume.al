package main;

sub ViewResume
{
  $validUser or return $bad_user_error;

  my $resume   = AppserverCall( 'GetResume',   $cgi_params->{resume_id} );
  my $userInfo = AppserverCall( 'GetUserInfo', $resume->{ownerid} );

  foreach my $key ( keys(%$resume) )
  {
    $hdf->setValue( "resume.$key", $resume->{$key} );
  }

  foreach my $key ( keys(%$userInfo) )
  {
    $hdf->setValue( "userinfo.$key", $userInfo->{$key} );
  }
}

1;