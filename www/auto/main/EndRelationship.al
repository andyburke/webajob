package main;

sub EndRelationship
{
  $validUser or return $bad_user_error;

  AppserverCall( 'EndRelationship', $cgi_params->{relationship_id} );    # error handled by AppserverCall()

  my $otherUserInfo = AppserverCall( 'GetUserInfo', $cgi_params->{user_id} );
  foreach my $key ( keys %$otherUserInfo )
  {
    $hdf->setValue( "otheruser.$key", $otherUserInfo->{$key} );
  }

}

1;