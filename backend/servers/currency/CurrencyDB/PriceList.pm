package CurrencyDB::PriceList;

use strict;

use base qw(CurrencyDB::DBI);

__PACKAGE__->table('price_list');
__PACKAGE__->columns(Primary => qw(product price));



1;
