package main;

sub ConfirmDeleteResume
{
  $validUser or return $bad_user_error;

  my $resume = AppserverCall( 'GetResume', $cgi_params->{resume_id} );

  foreach my $key ( keys(%$resume) )
  {
    $hdf->setValue( "resume.$key", $resume->{$key} );
  }
}

1;