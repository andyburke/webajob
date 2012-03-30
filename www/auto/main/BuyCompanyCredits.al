package main;

sub BuyCompanyCredits
{
    $validUser or return $bad_user_error;
    
    $output_data->{company}{id} = $input_data->{company_id};
	$output_data->{rates} = AppserverCall( 'GetPurchaseRates', 'company' );
    print STDERR $output_data; # FIXME we need to print output_data to prevent errors?
}

1;
