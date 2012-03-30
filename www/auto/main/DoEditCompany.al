package main;

sub DoEditCompany
{
  $validUser or return $bad_user_error;

  my $success = AppserverCall(
                               'EditCompanyInfo',
                               $cgi_params->{company_id},
                               {
                                 name     => $cgi_params->{name},
                                 address1 => $cgi_params->{address1},
                                 address2 => $cgi_params->{address2},
                                 city     => $cgi_params->{city},
                                 state    => $cgi_params->{state},
                                 zipcode  => $cgi_params->{zipcode},
                                 country  => $cgi_params->{country},
                                 phone    => $cgi_params->{phone},
                                 webpage  => $cgi_params->{webpage},
                                 summary  => $cgi_params->{summary},
                               }
  );

  if ( !$success )
  {
    $hdf->setValue( 'failed', 1 );
  }
  else
  {
    my $companyInfo = AppserverCall( 'GetCompanyInfo', $cgi_params->{company_id} );

    foreach my $key ( keys(%$companyInfo) )
    {
      $hdf->setValue( "company.$key", $companyInfo->{$key} );
    }
  }
}

1;
