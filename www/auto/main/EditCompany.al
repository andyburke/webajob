package main;

sub EditCompany
{
  $validUser or return $bad_user_error;

  my $companyInfo = AppserverCall( 'GetCompanyInfo', $cgi_params->{company_id} );

  foreach my $key ( keys(%$companyInfo) )
  {
    $hdf->setValue( "company.$key", $companyInfo->{$key} );
  }

}

1;