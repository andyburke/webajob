package main;

sub ViewJob
{
  $validUser or return $bad_user_error;

  my $resumes = AppserverCall('GetResumes');
  my $job = AppserverCall( 'GetJob', $cgi_params->{job_id} );
  my $canManageCompany = AppserverCall( 'CanManageCompany', $job->{ownerid});
  
  if($canManageCompany)
  {
	my @jobApplications = AppserverCall( 'GetJobApplications', $job->{id} );

	encode_hdf("jobApplications", @jobApplications);
  }

  encode_hdf("canManageCompany", $canManageCompany);
  encode_hdf("job", $job);
  $output_data->{resumes} = $resumes;
  $output_data->{hasResume} = @$resumes ? 1 : 0;
}

1;