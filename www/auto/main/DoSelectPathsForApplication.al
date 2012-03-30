package main;

sub DoSelectPathsForApplication
{
  $validUser or return $bad_user_error;

  $output_data->{application} = AppserverCall( 'GetJobApplication', $cgi_params->{application_id});
  $output_data->{job} = AppserverCall( 'GetJob', $output_data->{application}->{job_id});
  $output_data->{resume} = AppserverCall( 'GetResume', $output_data->{application}->{resume_id});

  my @paths;
  foreach my $key (keys(%$cgi_params))
  {
    next if $key !~ /^path-/;
    my ($pathName) = ($key =~ /^path-(.*)$/);
    my @path = split(',', $pathName);
    shift @path; # eat the applicant
    push(@paths, join(',', @path));
  }
  
  AppserverCall( 'SetApplicationPaths', $output_data->{application}->{id}, join(';', @paths));
  $output_data->{message} = 'You have applied for a job';
  $headers{-location} = "index.pl?webui_view=MyPage";
  
}

1;