package main;

sub BuyCredits
{
    $validUser or return $bad_user_error;
    
	$output_data->{rates} = AppserverCall( 'GetPurchaseRates', 'user' );
    print STDERR $output_data; # FIXME we need to print output_data to prevent errors?
}

1;
