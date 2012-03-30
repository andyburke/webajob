package main;

sub ResumeSearchResults
{
  $validUser or return $bad_user_error;

  my $parameters = {};
  
  # there used to be more parameters here
  # leaving in case we ever want to have more
  foreach my $param (qw(description))
  {
    $parameters->{$param} = $cgi_params->{$param} if length( $cgi_params->{$param} );
  }

  %$parameters or return ['You must enter some search criteria'];

  my $resumes = AppserverCall( 'SearchResumes', $parameters );

  my $resumeCount = 0;
  foreach my $resume (@$resumes)
  {
    foreach my $key ( keys(%$resume) )
    {
      $hdf->setValue( "resumes.$resumeCount.$key", $resume->{$key} );
    }
    $resumeCount++;
  }
}

1;
