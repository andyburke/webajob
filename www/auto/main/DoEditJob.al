package main;

sub DoEditJob
{
  $validUser or return $bad_user_error;

  AppserverCall(
                 'EditJob',
                 $cgi_params->{job_id},
                 {
                   title       => $cgi_params->{title},
                   location    => $cgi_params->{location},
                   skillset    => $cgi_params->{skillset},
                   education   => $cgi_params->{education},
                   description => $cgi_params->{description},
                 }
  );

}

1;
