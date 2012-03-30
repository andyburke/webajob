package main;

sub ConfirmEndRelationship
{
  $validUser or return $bad_user_error;

  my $otherUserInfo = AppserverCall( 'GetUserInfo', $cgi_params->{user_id} );
  foreach my $key ( keys %$otherUserInfo )
  {
    $hdf->setValue( "otheruser.$key", $otherUserInfo->{$key} );
  }

  $hdf->setValue( 'currentRelationshipId', $cgi_params->{relationship_id} );

}

1;