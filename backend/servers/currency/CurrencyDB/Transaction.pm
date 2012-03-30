package CurrencyDB::Transaction;

use strict;

use base qw(CurrencyDB::DBI);

__PACKAGE__->table('transaction_log');
__PACKAGE__->columns(All => qw(id owner_id type_id amount entry_time notes));
__PACKAGE__->has_a(type_id => 'CurrencyDB::TransactionType');

*type = \&type_id; # alias type_id to type so we can say $transaction->type



1;
