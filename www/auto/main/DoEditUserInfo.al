package main;

sub DoEditUserInfo
{
  $validUser or return $bad_user_error;

  AppserverCall(
    'EditUserInfo',
    {
      firstname 		   => $cgi_params->{firstname},
      middlename 		   => $cgi_params->{middlename},
      lastname 		   => $cgi_params->{lastname},
      address1 		   => $cgi_params->{address1},
      address2 		   => $cgi_params->{address2},
      city	  	 		   => $cgi_params->{city},
      state	 		   => $cgi_params->{state},
      zipcode	 		   => $cgi_params->{zipcode},
      country	 		   => $cgi_params->{country},
      phone	 		   => $cgi_params->{phone},
      birthdate 		   => $cgi_params->{birthdate},
      webpage	 		   => $cgi_params->{webpage},
      im		 		   => $cgi_params->{im},
      summary	 		   => $cgi_params->{summary},
    }
  );

  my $photoDataHandle = $cgi->upload('photo');
  if ($photoDataHandle)
  {
    AppserverCall(
      'EditUserPhoto',
      RPC::XML::base64->new(join('', <$photoDataHandle>)),
    );
  }
  elsif ($input_data->{delete_photo})
  {
    AppserverCall('DeleteUserPhoto');
  }
  $output_data->{message} = 'User info updated';
  $headers{-location} = "index.pl?webui_view=MyPage";

}

1;
