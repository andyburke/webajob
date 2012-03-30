package main;

sub ResumeManager
{
  $validUser or return $bad_user_error;

  my $resumes = AppserverCall( 'GetResumes' );

  my $count = 0;
  foreach my $resume (@$resumes)
  {
    foreach my $key ( keys(%$resume) )
    {
      $hdf->setValue( "resumes.$count.$key", $resume->{$key} );
    }
    $count++;
  }
}

1;
