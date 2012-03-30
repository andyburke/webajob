package main;

sub JobSearchResults
{
  $validUser or return $bad_user_error;

  my $parameters = {};
  foreach my $param (qw(title location description))
  {
    $parameters->{$param} = $cgi_params->{$param} if length( $cgi_params->{$param} );
  }

  %$parameters or return ['You must enter some search criteria'];

  my $jobs = AppserverCall( 'SearchJobs', $parameters );

  use Data::Dumper;
  print STDERR Dumper($jobs);
  
  my $jobCount = 0;
  foreach my $job (@$jobs)
  {
    foreach my $key ( keys(%$job) )
    {
      $hdf->setValue( "jobs.$jobCount.$key", $job->{$key} );
    }
    $jobCount++;
  }
}

1;