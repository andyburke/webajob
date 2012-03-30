package main;

sub DoAddJob
{
  $validUser or return $bad_user_error;

  if($input_data->{doAddJob} eq 'Cancel')
  {
    $headers{-location} = "index.pl?webui_view=MyPage";
    return;
  }

  my $jobId = AppserverCall(
    'AddJob',
    $input_data->{company_id},
    {
      title       => $cgi_params->{title},
      location    => $cgi_params->{location},
      description => $cgi_params->{description},
    }
  );

  my $job = AppserverCall( 'GetJob', $jobId );

  foreach my $key ( keys(%$job) )
  {
    $hdf->setValue( "job.$key", $job->{$key} );
  }

  $output_data->{message} = 'Job added to your listings';
  $headers{-location} = "index.pl?webui_view=MyPage";

}

1;