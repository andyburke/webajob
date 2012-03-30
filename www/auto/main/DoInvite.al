package main;

sub DoInvite
{
  $validUser or return $bad_user_error;

  my $serverName = $cgi->server_name();
  my @addresses = split("\0", $cgi_params->{address});

  foreach my $address (@addresses)
  {
    next if !length($address);

    print "inviting: $address\n";
    AppserverCall('SendEmail',
                  $address,
                  {
                    subject => "$validUserInfo->{firstname} $validUserInfo->{lastname} has invited you to join webajob.com!",
                    body    => qq{
Hi,

  $validUserInfo->{firstname} $validUserInfo->{lastname} has invited you to join webajob.com.

    http://$serverName/index.pl?webui_view=CreateAccount

  Sign up now or there will be consequences.

  Thanks,
  The Chrome Sphere
},
                  });
  }
  $output_data->{message} = 'Invites sent';
  $headers{-location} = "index.pl?webui_view=MyPage";
  
}

1;
