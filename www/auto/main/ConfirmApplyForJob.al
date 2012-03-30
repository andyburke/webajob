package main;

sub ConfirmApplyForJob
{
  $validUser or return $bad_user_error;

  $output_data->{job} = AppserverCall( 'GetJob', $cgi_params->{job_id} );
  $output_data->{company} = AppserverCall( 'GetCompanyInfo', $output_data->{job}->{ownerid} );
  $output_data->{resume} = AppserverCall( 'GetResume', $cgi_params->{resumeid} );
  $output_data->{price} = AppserverCall( 'GetPrice', 'ApplyForJob' );
}

1;