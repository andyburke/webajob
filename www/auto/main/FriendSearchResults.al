package main;

sub FriendSearchResults
{
  $validUser or return $bad_user_error;

  my $pageNumber = $cgi_params->{pageNumber} || 1;

  my $parameters = {};
  foreach my $param (qw(email firstname lastname))
  {
    $parameters->{$param} = $cgi_params->{$param} if length( $cgi_params->{$param} );
  }
  %$parameters or return ['You must enter some search criteria'];

  my $friends = AppserverCall( 'SearchUsers', $parameters, $pageNumber );

  for ( my $i = 0 ; $i < scalar( @{$friends} ) ; $i++ )
  {
    my $friend = $friends->[$i];
    foreach my $key ( keys( %{$friend} ) )
    {
      $hdf->setValue( "friends.$i.$key", $friend->{$key} );
    }
  }
}

1;