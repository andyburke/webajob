package main;

sub DoRateJobApplicant
{
  $validUser or return $bad_user_error;

  $output_data->{application} = AppserverCall('GetJobApplication', $cgi_params->{application_id});
  $output_data->{applicant} = AppserverCall('GetUserInfo', $output_data->{application}->{applicant_id});
  
  $output_data->{ratedApplicant} = AppserverCall('RateJobApplicant', $output_data->{application}->{id}, $cgi_params->{rating}) ? 1 : 0;
}

1;