package Class::Accessor::Init;

use base qw(Class::Accessor);

use strict;
use Carp;



our $VERSION = '0.02';



sub new {
  my ($class, $fields) = @_;

  my $self = bless {}, $class;

  # only set fields for which we have a defined method
  #   (either via Class::Accessor or explicit definition)
  if (ref($fields) eq 'HASH') {
    while (my ($accessor, $value) = each %$fields) {
      $self->$accessor($value) if $self->can($accessor);
    }
  }

  # pass $fields to initialize() too, to allow passing temporary values
  # that don't correspond to actual accessors
  $self->initialize($fields);

  return $self;
}


sub initialize {
  my $self = shift;

  if (ref($self) eq __PACKAGE__) {
    croak(__PACKAGE__." is a virtual class which may not be instantiated");
  }
}



1;
