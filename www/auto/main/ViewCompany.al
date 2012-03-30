package main;

sub ViewCompany
{
  $validUser or return $bad_user_error;

  my $companyInfo = AppserverCall( 'GetCompanyInfo', $cgi_params->{company_id} );

  foreach my $key ( keys(%$companyInfo) )
  {
    $hdf->setValue( "company.$key", $companyInfo->{$key} );
  }

  my $jobs = AppserverCall( 'GetJobsByCompany', $cgi_params->{company_id} );

  my $jobCount = 0;
  foreach my $job (@$jobs)
  {
    foreach my $key (keys(%$job))
    {
      $hdf->setValue("company.jobs.$jobCount.$key", $job->{$key});
    }
    $jobCount++;
  }
}

1;
