package main;

sub SelectPathsForApplication
{
  $validUser or return $bad_user_error;

  $output_data->{application} = AppserverCall( 'GetJobApplication', $cgi_params->{application_id});
  $output_data->{job} = AppserverCall( 'GetJob', $output_data->{application}->{job_id} );
#  $output_data->{company} = AppserverCall( 'GetCompanyInfo', $output_data->{job}->{ownerid} );
  $output_data->{paths} = AppserverCall('GetShortestPaths', $validUserInfo->{id}, $output_data->{job}->{ownerid}, 1); # get reciprocal paths...

  foreach my $path (@{$output_data->{paths}})
  {
    for(my $i = @$path - 1; $i >= 1; $i -= 2)
    {
      splice(@$path, $i, 1);
    }
    $path = { pathname => join(',', @$path) };
    $path->{users} = AppserverCall('GetUserInfo', [split(',', $path->{pathname})]);
  }  
}

1;