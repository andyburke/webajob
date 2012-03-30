package main;

sub DoBuyCompanyCredits
{

  $validUser or return $bad_user_error;

  my $dollars_in = $input_data->{amount};
  my $company_id = $input_data->{company_id};

  AppserverCall( 'BuyCredits', 'company', $dollars_in, $company_id );
  $output_data->{message} = 'You have successfully added credits';
  $headers{-location} = "index.pl?webui_view=MyPage";
    

}

1;
