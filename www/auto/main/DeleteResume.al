package main;

sub DeleteResume
{
  $validUser or return $bad_user_error;

  AppserverCall( 'DeleteResume', $cgi_params->{resume_id} );
}

1;