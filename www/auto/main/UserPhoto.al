package main;

sub UserPhoto
{
  $validUser or return $bad_user_error;

  $output_content = AppserverCall( 'GetUserPhoto', $input_data->{user_id} );
  $headers{-type} = 'image/jpeg';
}

1;
