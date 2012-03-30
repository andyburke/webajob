package CurrencyDB::Account;

use strict;

use base qw(CurrencyDB::DBI);

__PACKAGE__->table('account');
__PACKAGE__->columns(All => qw(owner_id balance));
__PACKAGE__->has_many(transactions => [ 'CurrencyDB::Transaction' => 'owner_id' ]);



1;
