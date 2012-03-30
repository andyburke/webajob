package main;

sub EditUserInfo
{
  $validUser or return $bad_user_error;

  my $photoInfo = AppserverCall( 'GetUserPhotoInfo', $validUserInfo->{id} );
  $output_data->{validuser}{photoinfo} = $photoInfo; # FIXME is validuser the right place for this?
}

1;
