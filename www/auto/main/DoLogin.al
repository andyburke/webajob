package main;

sub DoLogin
{
  $session_id = AppserverCall( 'DoLogin', @$cgi_params{qw(email password)} );
  if (length $cgi_params->{webui_dest})
  {
    $headers{-location} = "index.pl?$cgi_params->{webui_dest}";
  }
  else
  {
    $headers{-location} = "index.pl?webui_view=MyPage";
  }
  $headers{-status}   = '303 See Other';
  my $session_cookie = $cgi->cookie(
    -name    => 'webajob_session',
    -value   => $session_id,
    -expires => '+30m'
  );
  $headers{-cookie} = $session_cookie;
}

1;
