package main;

sub ManageJobs
{
  $validUser or return $bad_user_error;

  $output_data->{company} = AppserverCall( 'GetCompanyInfo', $input_data->{company_id} );
  $output_data->{company}{jobs} = AppserverCall( 'GetJobsByCompany', $input_data->{company_id} );

  my $managedCompanyIds = AppserverCall( 'GetManagedCompanyIds' );
  my $companyCount = 0;

  # FIXME assumes we're going to get same order of managed company ids as way at the top
  foreach my $managedCompanyId (@$managedCompanyIds)
  {
    my $jobs = AppserverCall( 'GetJobsByCompany', $managedCompanyId);
    my $jobCount = 0;
    foreach my $job (@$jobs)
    {
      foreach my $key (keys(%$job))
      {
        $hdf->setValue("managedcompanies.$companyCount.jobs.$jobCount.$key", $job->{$key});
      }
      $jobCount++;
    }
  }
}

1;
