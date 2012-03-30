#!/usr/bin/perl

use strict;

my $server = IdServer->new( { name => 'id' } );
$server->Loop();

package IdServer;

use BackendServer;
use base qw(BackendServer);

use Error;

use Data::UUID;

sub new
{
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  $self->{UUIDGenerator} = Data::UUID->new() or die("Could not create UUID generator!");

  # FIXME: if we ever have multiple id servers hitting one db, this needs to
  #   use a sequence and pull from the db every time. (now we just check
  #   'max(id)' at startup and increment $currentId ourselves)
  $self->{typeLookupStatement}     = $self->Dbh->prepare("select id_type_map.id, id_type_map.typeid, typelist.name from id_type_map inner join typelist on id_type_map.typeid = typelist.id where id_type_map.id = ?");
  $self->{typeIdLookupStatement}   = $self->Dbh->prepare("select * from typelist where id = ?");
  $self->{typeNameLookupStatement} = $self->Dbh->prepare("select * from typelist where name = ?");
  $self->{insertStatement}         = $self->Dbh->prepare("insert into id_type_map values (?, ?)");
  
  return $self;
}

sub GetId
{
  my $self = shift;
  my $typeId = shift || 0;    # 0 = unknown type

  my $type;
  if ( $typeId !~ /^\d+$/ )
  {
    $self->{typeNameLookupStatement}->execute($typeId);
    $type = $self->{typeNameLookupStatement}->fetchrow_hashref();
  }
  else
  {
    $self->{typeIdLookupStatement}->execute($typeId);
    $type = $self->{typeIdLookupStatement}->fetchrow_hashref();
  }

  throw Error::Simple( 'Invalid type!' ) if !$type;

  $typeId = $type->{id};

  my $uuid = $self->{UUIDGenerator}->create_str(); # eg: 4162F712-1DD2-11B2-B17E-C09EFE1DC403
  throw Error::Simple('Could not generate a unique id!' ) if !$uuid;

  $self->{insertStatement}->execute( $uuid, $typeId );

  return $uuid;
}

sub GetType
{
  my $self = shift;
  my $id = shift;

  $self->{typeLookupStatement}->execute($id);
  my $id_type_map = $self->{typeLookupStatement}->fetchrow_hashref();

  throw Error::Simple('Unknown id!' ) if !$id_type_map;

  return $id_type_map->{name};
}    
