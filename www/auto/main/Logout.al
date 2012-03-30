package main;

sub Logout
{
  $validUser or return $bad_user_error;

  $session_id         = undef;
  $headers{-Status}   = '302 Moved';
  $headers{-Location} = 'index.pl';
  my $session_cookie = $cgi->cookie(
                                     -name    => 'webajob_session',
                                     -value   => '',
                                     -expires => '+0m'
  );
  $headers{-cookie} = $session_cookie;
}

1;