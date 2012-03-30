package main;

sub CreateAccount
{
  !$validUser or return ['You are already logged in.  Log out first to create a new account.'];
}

1;