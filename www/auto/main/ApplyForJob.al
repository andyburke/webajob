package main;

sub ApplyForJob
{
  $validUser or return $bad_user_error;

  my $job = AppserverCall('GetJob', $cgi_params->{job_id});
  my $resume = AppserverCall('GetResume', $cgi_params->{resume_id});
  my $company = AppserverCall('GetCompanyInfo', $cgi_params->{company_id});
  
  AppserverCall('ApplyForJob', $job->{id}, $resume->{id}, $cgi_params->{});
  
  encode_hdf("job", $job);
  encode_hdf("company", $company);
  encode_hdf("resume", $resume);

}

1;