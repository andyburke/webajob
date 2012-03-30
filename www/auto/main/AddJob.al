package main;

sub AddJob
{
  $validUser or return $bad_user_error;

  $output_data->{price} = AppserverCall( 'GetPrice', 'ListJob' );
  $output_data->{company} = AppserverCall( 'GetCompanyInfo', $input_data->{company_id} );;
  $output_data->{company}{credits} = AppserverCall( 'GetAccountBalance', $input_data->{company_id} );

}

1;