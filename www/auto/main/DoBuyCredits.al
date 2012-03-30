package main;

sub DoBuyCredits
{

  $validUser or return $bad_user_error;

  my $dollars_in = $input_data->{amount};

  AppserverCall( 'BuyCredits', 'user', $dollars_in );
  $output_data->{message} = 'You have successfully added credits';
  $headers{-location} = "index.pl?webui_view=MyPage";

}

1;
