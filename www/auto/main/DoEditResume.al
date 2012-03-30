package main;

sub DoEditResume
{
  $validUser or return $bad_user_error;

  AppserverCall(
                 'EditResume',
                 $cgi_params->{resume_id},
                 {
                   name                => $cgi_params->{name},
                   description         => $cgi_params->{description},
                 }
  );
  $output_data->{message} = 'Resume updated';
  $headers{-location} = "index.pl?webui_view=MyPage";

}

1;
