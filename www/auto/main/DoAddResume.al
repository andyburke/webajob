package main;

sub DoAddResume
{
  $validUser or return $bad_user_error;

  AppserverCall(
                 'AddResume',
                 {
                   name                => $cgi_params->{name},
                   goal                => $cgi_params->{goal},
                   skillset            => $cgi_params->{skillset},
                   education           => $cgi_params->{education},
                   previous_experience => $cgi_params->{previous_experience},
                 }
  );
  $output_data->{message} = 'You have added a resume to your account';
  $headers{-location} = "index.pl?webui_view=MyPage";

}

1;
