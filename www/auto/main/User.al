package main;

sub User
{
  $validUser or return $bad_user_error;

  # check whether logged in user has a relationship to this user
  my $validUserRelatedEntities = AppserverCall( 'GetRelatedEntities', $validUserInfo->{id}, 1, 'user' );    # r1

  # FIXME we assume the only path to the related entity is the current path... ?
  if (defined($validUserRelatedEntities->{$cgi_params->{user_id}}))
  {
    my $relationship = AppserverCall( 'GetRelationship', $validUserInfo->{id}, $cgi_params->{user_id}, $validUserRelatedEntities->{$cgi_params->{user_id}}->[0]->[1]);
    $hdf->setValue( 'currentRelationshipId', $relationship->{id} );
  }

  # get all the relationships this user has to others (possibly including the logged in user).
  # note that this is subject to the business rules governing relationship visibility.
  # FIXME there should perhaps be a 'GetRelatedUsers' call
  my $relatedEntities = AppserverCall( 'GetRelatedEntities', $cgi_params->{user_id}, 1, 'user' );           # r1
  my $userInfo = AppserverCall( 'GetUserInfo', [keys %$relatedEntities] );
  foreach my $user (@$userInfo)
  {
    # ->[1] is each path's relationship type (all paths are to the same entity,
    #   but may be of different relationship type)
    $user->{typenames} = [ map { GetRelationshipTypeDisplayString($_->[1]) } @{$relatedEntities->{$user->{id}}} ];
  }
  $output_data->{relationships} = $userInfo;

  # get this user's info
  my $userInfo = AppserverCall( 'GetUserInfo', $cgi_params->{user_id} );
  foreach my $key ( keys %$userInfo )
  {
    $hdf->setValue( "user.$key", $userInfo->{$key} );
  }
  my $photoInfo = AppserverCall( 'GetUserPhotoInfo', $cgi_params->{user_id} );
  $output_data->{user}{photoinfo} = $photoInfo;

  # get data to fill in type dropdown for creating new relationship to this user
  # FIXME only do this if there's no relationship already (check is up above)
  if($validUserInfo->{id} != $cgi_params->{user_id})
  {
    my $relationshipTypes = AppserverCall('GetAllowedRelationshipTypes', 'user', 'user');
	my $count             = 0;
	foreach my $relationshipType (@$relationshipTypes)
	{
	  $hdf->setValue( "relationshiptypes.$count.id",   $relationshipType->{id} );
	  $hdf->setValue( "relationshiptypes.$count.name", GetRelationshipTypeDisplayString($relationshipType->{name}) );
	  $count++;
	}
  }
}

1;
