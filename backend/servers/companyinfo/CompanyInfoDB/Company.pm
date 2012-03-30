package CompanyInfoDB::Company;

use strict;

use base qw(CompanyInfoDB::DBI);
CompanyInfoDB::Company->table('company');
CompanyInfoDB::Company->columns(Primary => qw(id));
CompanyInfoDB::Company->columns(Essential => qw(name address1 address2 city state zipcode country phone webpage summary));

1;
