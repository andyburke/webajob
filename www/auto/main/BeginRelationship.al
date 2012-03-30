package main;

sub BeginRelationship
{
  $validUser or return $bad_user_error;

  my $addedRelationship = AppserverCall( 'BeginRelationship', $cgi_params->{user_id}, $cgi_params->{type_id} );

  $hdf->setValue( 'addedRelationship', $addedRelationship);

  if($addedRelationship)
  {

    my $sourceName       = $validUserInfo->{firstname} . ' ' . $validUserInfo->{lastname};
    my $serverName = $cgi->server_name();

    my $notificationSubject = "$sourceName has added you to their relationship network!";
    my $notificationBody = qq{
Hi,

  $sourceName has added you to their relationship network.  You should probably
kill them as soon as you can.

  You can do so by going here:
  
    http://$serverName/index.pl?webui_view=MyPage
    
  Thanks,
  The Webajob Future Squad
};

    AppserverCall('Notify',
                  $cgi_params->{user_id},
                  {
                    subject => $notificationSubject,
                    body    => $notificationBody,
                  },
    );
  }

  my $relationshipTypeName = AppserverCall( 'GetRelationshipTypeName', $cgi_params->{type_id} );
  $hdf->setValue( 'relationshipTypeName', $relationshipTypeName );

  my $userInfo = AppserverCall( 'GetUserInfo', $cgi_params->{user_id} );
  foreach my $key ( keys %$userInfo )
  {
    $hdf->setValue( "otheruser.$key", $userInfo->{$key} );
  }
}

1;
