package UserInfoDB::Photo;

use strict;
use MIME::Base64;

use base qw(UserInfoDB::DBI);
__PACKAGE__->table('photo');
__PACKAGE__->columns(Primary => qw(userid));
__PACKAGE__->columns(Essential => qw(photodata));
__PACKAGE__->add_trigger(before_create => \&handle_before_create);


# ====
# FIXME: if DBD::SQLite starts handling blobs better, then these two methods can go away.
# we need to store the photo data base64-encoded for now, and this makes it transparent

sub handle_before_create
{
  my $self = shift;
  $self->{photodata} = encode_base64($self->{photodata}, '');
}

sub photodata
{
  my $self = shift;
  my ($photodata) = @_;

  if (@_)
  {
    $self->_photodata_accessor(encode_base64($photodata, ''));
    return $photodata;
  }
  else
  {
    return decode_base64($self->_photodata_accessor);
  }
}

# ====


1;
