package UserInfoDB::User;

use strict;

use base qw(UserInfoDB::DBI);
__PACKAGE__->table('user');
__PACKAGE__->columns(Primary => qw(id));
__PACKAGE__->columns(Essential => qw(
  email firstname middlename lastname address1 address2
  city state zipcode country phone birthdate webpage im summary
));
__PACKAGE__->might_have(photo => 'UserInfoDB::Photo' => 'photodata');

1;
