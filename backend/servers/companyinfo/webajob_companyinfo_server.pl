#!/usr/bin/perl

use strict;

my $server = Webajob::CompanyInfoServer->new( { name => 'companyinfo' } );
$server->Loop;

package Webajob::CompanyInfoServer;

use BackendServer;
use base qw(BackendServer);

use Error;
use CompanyInfoDB::DBI;
use CompanyInfoDB::Company;

sub new
{
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  CompanyInfoDB::DBI->set_db( 'Main', @{ $self->dbConfig } );

  return $self;
}

sub Add
{
  my $self = shift;
  my $data = shift;

  my $companyId = $self->Call( 'id.GetId', 'company' );

  my $company = CompanyInfoDB::Company->create(
                                                {
                                                  id       => $companyId,
                                                  name     => $data->{name},
                                                  address1 => $data->{address1},
                                                  address2 => $data->{address2},
                                                  city     => $data->{city},
                                                  state    => $data->{state},
                                                  zipcode  => $data->{zipcode},
                                                  country  => $data->{country},
                                                  phone    => $data->{phone},
                                                  webpage  => $data->{webpage},
                                                  summary  => $data->{summary},
                                                }
                                              );

  if ( !$company )
  {
    throw Error::Simple("Could not create database entry for new company: $!");
  }

  return $companyId;
}

sub Edit
{
  my $self        = shift;
  my $companyId   = shift;
  my $companyData = shift;

  my $company = CompanyInfoDB::Company->retrieve($companyId);

  if ( !$company )
  {
    throw Error::Simple('Could not locate company for editing.');
  }

  my @columns = $company->columns();

  foreach my $column (@columns)
  {
    if ( exists( $companyData->{$column} ) )
    {
      $company->set( $column => $companyData->{$column} );
    }
  }

  $company->update();
  return 1;
}

sub Delete
{
  my $self      = shift;
  my $companyId = shift;

  my $company = CompanyInfoDB::Company->retrieve($companyId);

  if ( !$company )
  {
    throw Error::Simple('Could not locate company for deletion.');
  }

  $company->delete();
  return 1;
}

sub GetInfo
{
  my $self      = shift;
  my $companyId = shift;

  my $company = CompanyInfoDB::Company->retrieve($companyId);
  if ( !defined($company) )
  {
    throw Error::Simple('Invalid company.');    
  }

  my $companyInfo = {};
  foreach my $field ($company->columns())
  {
    $companyInfo->{$field} = $company->{$field};
  }

  return $companyInfo;
}

sub Search
{
  my $self       = shift;
  my $parameters = shift;
  my $maxResults = shift;
  my $offset     = shift || 0;

  # FIXME caching
  my @companies = CompanyInfoDB::Company->search_like($parameters);
  if ($maxResults)
  {
    @companies = splice( @companies, $offset, $maxResults );
  }

  return \@companies;
}

1;

