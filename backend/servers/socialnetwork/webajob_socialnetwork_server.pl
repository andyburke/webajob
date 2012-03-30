#!/usr/bin/perl
use strict;

my $server = Webajob::SocialNetworkServer->new( { name => 'socialnetwork' } );
$server->Loop;

package Webajob::SocialNetworkServer;

use BackendServer;
use base qw(BackendServer);

use Error;
use Cache::Memory;
use Data::Dumper;

use SocialNetworkDB::DBI;
use SocialNetworkDB::Relationship;
use SocialNetworkDB::RelationshipType;
use SocialNetworkDB::AllowedRelationshipMap;

sub new
{
  my $class = shift;
  
  my $self = $class->SUPER::new(@_);

  SocialNetworkDB::DBI->set_db( 'Main', @{ $self->dbConfig } );

  $self->{searchCacheSizeLimit} = 10_000_000; # 10MB
  $self->{searchCache} = Cache::Memory->new(size_limit => $self->{searchCacheSizeLimit}); # use default LRU expiry

  return $self;
}

sub BeginRelationship
{
  my $self = shift;
  my $sourceId         = shift;
  my $destinationId    = shift;
  my $relationshipType = shift;

  if ( $sourceId eq $destinationId )
  {
    throw Error::Simple('You cannot add a relationship to yourself.' );
  }

  if ( $relationshipType !~ /^\d+$/ )
  {
    ($relationshipType) = SocialNetworkDB::RelationshipType->search( { name => $relationshipType } );
    if ( !$relationshipType )
    {
      throw Error::Simple('Invalid relationship type.' );
    }
    $relationshipType = $relationshipType->id;
  }

  my ($relationship) = SocialNetworkDB::Relationship->search(
                                                              {
                                                                source      => $sourceId,
                                                                destination => $destinationId,
                                                                type        => $relationshipType,
                                                                end_date    => undef,
                                                              }
  );

  if ( defined $relationship )
  {
    throw Error::Simple('This relationship already exists!' );
  }

  my $sourceType = $self->Call( 'id.GetType', $sourceId );
  my $targetType = $self->Call( 'id.GetType', $destinationId );

  my ($allowed) = SocialNetworkDB::AllowedRelationshipMap->search(
                                                                   {
                                                                     sourcetype         => $sourceType,
                                                                     targettype         => $targetType,
                                                                     relationshiptypeid => $relationshipType,
                                                                   }
  );

  if ( !$allowed )
  {
    throw Error::Simple('This is a disallowed type of relationship between these entity types.' );
  }

  my $relationshipId = $self->Call( 'id.GetId', 'relationship' );

  my $new_relationship = SocialNetworkDB::Relationship->create(
    {
      id          => $relationshipId,
      source      => $sourceId,
      destination => $destinationId,
      type        => $relationshipType,
      start_date  => time(),
    }
  );

  $new_relationship->update();

  return $new_relationship->id;

}

sub EndRelationship
{
  my $self = shift;
  my $relationshipId = shift;

  my $relationship = SocialNetworkDB::Relationship->retrieve($relationshipId);
  if ( !defined $relationship )
  {
    throw Error::Simple('No such relationship.' );
  }

  $relationship->end_date( time() );
  $relationship->update();
  return 1;
}

sub GetRelationshipType
{
  my $self = shift;
  my $typeName = shift;

  my ($relationshipType) = SocialNetworkDB::RelationshipType->search( { name => $typeName } );
  if ( !defined $relationshipType )
  {
    throw Error::Simple("Could not find the given relationship type: $typeName" );
  }

  return $relationshipType->id;
}

sub GetRelationshipTypeName
{
  my $self = shift;
  my $typeId = shift;

  my $relationshipType = SocialNetworkDB::RelationshipType->retrieve($typeId);
  if ( !defined $relationshipType )
  {
    throw Error::Simple("Could not find the name for the relationship type with id: $typeId" );
  }

  return $relationshipType->name;
}

sub GetAllowedRelationshipTypes
{
  my $self = shift;
  my $sourceType = shift;
  my $targetType = shift;

  my @allowedRelationshipTypes = SocialNetworkDB::AllowedRelationshipMap->search( sourcetype => $sourceType, targettype => $targetType );
  if ( !@allowedRelationshipTypes )
  {
    throw Error::Simple("Could not retrieve any allowed relationship types!" );
  }

  my @relationshipTypes;
  foreach my $allowedRelationshipType (@allowedRelationshipTypes)
  {
    push(
          @relationshipTypes,
          {
            id   => $allowedRelationshipType->relationshiptypeid->id,
            name => $allowedRelationshipType->relationshiptypeid->name
          }
    );
  }

  return \@relationshipTypes;
}

sub GetRelationship
{
  my $self = shift;
  my $relationshipId;
  my $sourceId;
  my $destinationId;
  my $relationshipType;

  my $relationship;

  if ( @_ == 3 )
  {
    $sourceId         = shift;
    $destinationId    = shift;
    $relationshipType = shift;

    if ( $relationshipType !~ /^\d+$/ )
    {
      ($relationshipType) = SocialNetworkDB::RelationshipType->search( { name => $relationshipType } );
      if ( !$relationshipType )
      {
        throw Error::Simple('Invalid relationship type.' );
      }
      $relationshipType = $relationshipType->id;
    }

    ($relationship) = SocialNetworkDB::Relationship->search(
                                                             {
                                                               source      => $sourceId,
                                                               destination => $destinationId,
                                                               type        => $relationshipType,
                                                               end_date    => undef,
                                                             }
    );

  }
  else
  {
    $relationshipId = shift;
    $relationship   = SocialNetworkDB::Relationship->retrieve($relationshipId);
  }

  if ( !$relationship )
  {
    throw Error::Simple("No such relationshipId: $relationshipId" );
  }


  # FIXME all this to avoid problems with JSON serializing objects...
  my $relationshipData = {};
  foreach my $column ($relationship->columns)
  {
    $relationshipData->{$column} = $relationship->{$column};
    if($column eq 'type')
    {
      $relationshipData->{$column} = { id => $relationship->{$column}->{id} };
    }
  }

  return $relationshipData;
}

sub GetRelatedEntities
{
  my $self = shift;
  my $sourceId        = shift;
  my $radius          = shift;
  my $finalEntityType = shift;
  my $reciprocal      = shift;

  # FIXME this is all just sort of ugly

  if ( $radius > 4 )
  {
    throw Error::Simple('Radius for relationship search too large!' );
  }

  # check for this search being cached
  my $cacheKey = "$sourceId:$radius:$finalEntityType";
  if (my $searchResult = $self->{searchCache}->thaw($cacheKey))
  {
    printf "Cache hit: size=%d count=%d\n", $self->{searchCache}->size, $self->{searchCache}->count;
    return $searchResult;
  }
  
  printf "Cache miss: size=%d count=%d\n", $self->{searchCache}->size, $self->{searchCache}->count;
  
  # here we build a hash of the valid 'last hop' relationship types based on the
  # entity type they gave us...
  my %validFinalRelationshipTypes;
  if ( defined $finalEntityType )
  {
    my @validFinalRelationshipTypesArray = SocialNetworkDB::AllowedRelationshipMap->search( targettype => $finalEntityType );
    foreach my $validFinalRelationshipType (@validFinalRelationshipTypesArray)
    {
      $validFinalRelationshipTypes{ $validFinalRelationshipType->relationshiptypeid->name } = 1;
    }
  }

  # we get the graph
  my %relatedEntities;
  $self->GetRelatedEntitiesRecursive( $sourceId, [], \%relatedEntities, 0, $radius, undef, \%validFinalRelationshipTypes, $reciprocal );

  # now we have to cull out relationships that were shorter than the max distance, but end
  # with the wrong relationship type.  We can't prevent this in our search because we don't
  # know about the next step in the graph, we have no idea when we're at the leaves.
  if ( defined $finalEntityType )
  {
    # FIXME only look at ones where the path isn't the full length?
    foreach my $relatedEntityId (keys(%relatedEntities))
    {
      foreach my $path (@{$relatedEntities{$relatedEntityId}})
      {
        if(!$validFinalRelationshipTypes{$path->[@{$path} - 1]})
        {
          $path = undef;
        }
      }
      @{$relatedEntities{$relatedEntityId}} = grep { defined($_) } @{$relatedEntities{$relatedEntityId}};
      
      if(!@{$relatedEntities{$relatedEntityId}})
      {
       delete $relatedEntities{$relatedEntityId};
      }
    }
  }

  $self->{searchCache}->freeze($cacheKey, \%relatedEntities);

  return \%relatedEntities;

}

sub GetRelatedEntitiesRecursive
{
  my $self = shift;
  my $sourceId                    = shift;
  my $curPath                     = shift;
  my $curResults                  = shift;
  my $curDepth                    = shift;
  my $maxDepth                    = shift;
  my $previousEntityId            = shift;
  my $validFinalRelationshipTypes = shift;
  my $reciprocal                  = shift;

  return if ( $curDepth == $maxDepth );    # to be safe

  # get back the relationships for this entity
  my @relationships = SocialNetworkDB::Relationship->search( source => $sourceId, end_date => undef );
  if($reciprocal)
  {
    foreach my $relationship (@relationships)
    {
      my $reciprocity = SocialNetworkDB::Relationship->search( source => $relationship->{destination}, destination => $relationship->{source}, end_date => undef);
      if(!$reciprocity)
      {
        $relationship = undef;
      }
    }
    @relationships = grep { defined($_) } @relationships;
  }

  if (@relationships)
  {
    foreach my $relationship (@relationships)
    {

      # prevent backtracking
      next if ( defined($previousEntityId) and $relationship->{destination} eq $previousEntityId );

      # limit the final relationship type to one of our valid ones for this entity type
      next if ( ( $curDepth == $maxDepth - 1 ) and %$validFinalRelationshipTypes and !$validFinalRelationshipTypes->{ $relationship->type->name } );

      # tack some more crap onto the path
      my @path = ( @{$curPath}, $sourceId, $relationship->type->name );
      if(!exists($curResults->{$relationship->{destination}}))
      {
        $curResults->{$relationship->{destination}} = [\@path];
      }
      else
      {
        push(@{$curResults->{$relationship->{destination}}}, \@path);
      }

      # recurse on this entity
      if ( $curDepth + 1 < $maxDepth )    # avoid unnecessary calls
      {
        $self->GetRelatedEntitiesRecursive( $relationship->{destination}, \@path, $curResults, $curDepth + 1, $maxDepth, $sourceId, $validFinalRelationshipTypes );
      }
    }
  }
}

sub HasRelationship
{
  my $self = shift;
  my $sourceId         = shift;
  my $destinationId    = shift;
  my $relationshipType = shift;

  if ( defined($relationshipType) )
  {
    if ( $relationshipType !~ /^\d+$/ )
    {
      ($relationshipType) = SocialNetworkDB::RelationshipType->search( { name => $relationshipType } );
      if ( !$relationshipType )
      {
        throw Error::Simple('Invalid relationship type.' );
      }
      $relationshipType = $relationshipType->id;
    }
  }

  my ($relationship) = SocialNetworkDB::Relationship->search(
                                                              {
                                                                source      => $sourceId,
                                                                destination => $destinationId,
                                                                ( $relationshipType ? ( type => $relationshipType ) : () ),
                                                                end_date => undef,
                                                              }
  );

  return defined $relationship;
}    


# FIXME this isn't going to hit the cache so well, as the finalrelationshiptype is unconstrained
sub GetPaths
{
  my $self = shift;
  my $sourceId        = shift;
  my $destId          = shift;
  my $reciprocal      = shift;

  # FIXME "4" should be configurable/global/etc
  my $relatedEntities = $self->GetRelatedEntities($sourceId, 4, undef, $reciprocal);

  my $paths = $relatedEntities->{$destId};
  $paths ||= [];

  return $paths;
}


# FIXME this isn't going to hit the cache so well, as the finalrelationshiptype is unconstrained
sub GetShortestPath
{
  my $self = shift;
  my $sourceId        = shift;
  my $destId          = shift;
  my $reciprocal      = shift;

  my $paths = $self->GetShortestPaths($sourceId, $destId, $reciprocal);

  if(@$paths)
  {
    return $paths->[0];
  }

  return [];
}

# FIXME this isn't going to hit the cache so well, as the finalrelationshiptype is unconstrained
sub GetShortestPaths
{
  my $self = shift;
  my $sourceId        = shift;
  my $destId          = shift;
  my $reciprocal      = shift;

  my $paths = $self->GetPaths($sourceId, $destId, undef, $reciprocal);

  # iterate to find shortest path
  my $shortestPathLength;
  foreach my $path (@$paths)
  {
    $shortestPathLength = scalar(@$path) if !defined($shortestPathLength) or @$path < $shortestPathLength;
  }
  
  my @shortestPaths;
  foreach my $path (@$paths)
  {
    push(@shortestPaths, $path) if @$path == $shortestPathLength;
  }

  return \@shortestPaths;
}

1;
