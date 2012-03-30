package CurrencyDB::PurchaseRate;

use strict;

use base qw(CurrencyDB::DBI);

__PACKAGE__->table('purchase_rate');
__PACKAGE__->columns(Primary => qw(user_class dollars_in credits_out));



1;
