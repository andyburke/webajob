package main;

sub MyPage
{
  $validUser or return $bad_user_error;

  my $photoInfo = AppserverCall( 'GetUserPhotoInfo', $validUserInfo->{id} );
  $output_data->{validuser}{photoinfo} = $photoInfo; # FIXME is validuser the right place for this?

  my $relatedEntities = AppserverCall( 'GetRelatedEntities', $validUserInfo->{id}, 1, 'user' );    # r1
  my $userInfo = AppserverCall( 'GetUserInfo', [keys %$relatedEntities] );
  foreach my $user (@$userInfo)
  {
    # ->[1] is each path's relationship type (all paths are to the same entity,
    #   but may be of different relationship type)
    $user->{typenames} = [ map { GetRelationshipTypeDisplayString($_->[1]) } @{$relatedEntities->{$user->{id}}} ];
  }
  $output_data->{relationships} = $userInfo;

  $output_data->{credits} = AppserverCall('GetAccountBalance');
}

1;
