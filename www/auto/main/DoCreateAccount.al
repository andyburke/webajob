package main;

sub DoCreateAccount
{

  # FIXME on error, fill back in form for them...

  if($cgi_params->{password} ne $cgi_params->{password_verify})
  {
    return ["Passwords do not match!", 'CreateAccount'];
  }
  elsif($cgi_params->{email} ne $cgi_params->{email_verify})
  {
    return ["Email addresses do not match!", 'CreateAccount'];
  }

  # FIXME don't pass raw cgi_params -- be explicit about allowed params.  i hate you so much.
  AppserverCall( 'DoCreateAccount', $cgi_params );
}

1;
