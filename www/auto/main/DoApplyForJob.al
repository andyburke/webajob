package main;

sub DoApplyForJob
{
  $validUser or return $bad_user_error;

  if($cgi_params->{doApplication} eq 'Cancel')
  {
    $headers{-location} = "index.pl?webui_view=JobSearch";
    return;
  }
  
  my $applicationId = AppserverCall('ApplyForJob', $cgi_params->{job_id}, $cgi_params->{resume_id});
    
  $headers{-location} = "index.pl?webui_view=SelectPathsForApplication&application_id=" . $applicationId;
}

1;