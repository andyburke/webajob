#!/usr/bin/perl

use strict;

my $server = Webajob::CurrencyServer->new( { name => 'currency' } );
$server->Loop;

package Webajob::CurrencyServer;

use BackendServer;
use base qw(BackendServer);

use Error;
use CurrencyDB::DBI;
use CurrencyDB::Account;
use CurrencyDB::Transaction;
use CurrencyDB::TransactionType;
use CurrencyDB::PurchaseRate;
use CurrencyDB::PriceList;

sub new
{
  my $class = shift;
  
  my $self = $class->SUPER::new(@_);

  CurrencyDB::DBI->set_db( Main => @{ $self->dbConfig } );

  return $self;
}

sub CreateAccount
{
  my $self    = shift;
  my $user_id = shift;

  my $account = CurrencyDB::Account->retrieve($user_id);
  if ($account)
  {
    throw Error::Simple("Account for user_id $user_id already exists.");
  }
  $account = CurrencyDB::Account->create( { owner_id => $user_id, balance => 0 } );

  return 1;    # arbitrary -- this method just faults or it doesn't
}

sub GetAccountBalance
{
  my $self    = shift;
  my $user_id = shift;

  my $account = CurrencyDB::Account->retrieve($user_id);
  if ( !$account )
  {
    throw Error::Simple("Account for user_id $user_id doesn't exist.");
  }

  return $account->balance;
}

sub AddCredits
{
  my $self          = shift;
  my $user_id       = shift;
  my $user_class    = shift;
  my $dollar_amount = shift;

  my $account = CurrencyDB::Account->retrieve($user_id);
  if ( !$account )
  {
    throw Error::Simple("Account for user_id $user_id doesn't exist.");
  }

  my ($rate) = CurrencyDB::PurchaseRate->search(
                                                 {
                                                   user_class => $user_class,
                                                   dollars_in => $dollar_amount
                                                 }
                                               );
  if ( !$rate )
  {
    throw Error::Simple("Rate with user_class=$user_class and dollar_in=$dollar_amount does not exist.");
  }
  $account->balance( $account->balance + $rate->credits_out );
  $account->update;

  return $account->balance;
}

sub SubtractCredits
{
  my $self = shift;
  my $user_id = shift;
  my $credits = shift;
  
  my $account = CurrencyDB::Account->retrieve($user_id);
  if ( !$account )
  {
    throw Error::Simple("Account for user_id $user_id doesn't exist.");
  }
  
  $account->balance( $account->balance - $credits );
  $account->update;
  
  return $account->balance;
}

sub GetPurchaseRates
{
  my $self = shift;
  my $user_class = shift;
  
  my @purchaseRates = CurrencyDB::PurchaseRate->search({user_class => $user_class});

  foreach my $purchaseRate (@purchaseRates)
  {
    my $rateData = {};
    foreach my $column ($purchaseRate->columns)
    {
      $rateData->{$column} = $purchaseRate->{$column};
    }
    $purchaseRate = $rateData;
  }

  return \@purchaseRates;
}

sub GetPrice
{
  my $self = shift;
  my $product = shift;
  
  my ($listing) = CurrencyDB::PriceList->search({product => $product});
  
  if ( !$listing )
  {
    throw Error::Simple("Unable to find a price for product:[$product]");
  }
  
  return $listing->price;
}

1;

