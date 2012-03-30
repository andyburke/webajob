package CurrencyDB::TransactionType;

use strict;

use base qw(CurrencyDB::DBI);

__PACKAGE__->table('transaction_type');
__PACKAGE__->columns(All => qw(id name));


1;
