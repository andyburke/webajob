package main;

sub RateJobApplicant
{
  $validUser or return $bad_user_error;

  my $applicationId = $input_data->{application_id};
  
  $output_data->{application} = AppserverCall('GetJobApplication', $applicationId);
  $output_data->{applicant} = AppserverCall('GetUserInfo', $output_data->{application}->{applicant_id});
  $output_data->{job} = AppserverCall('GetJob', $output_data->{application}->{job_id});
}

1;