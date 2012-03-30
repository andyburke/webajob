package main;

sub FeedbackResults
{
  $validUser or return $bad_user_error;

  my $parameters = {};
  foreach my $param (qw(subject body))
  {
    $parameters->{$param} = $cgi_params->{$param} if length( $cgi_params->{$param} );
  }

  %$parameters or return ['Invalid feedback.'];

  use Data::Dumper;
  my $fullUserInfo = Dumper ( $validUserInfo );

  my $mailData = { subject => "Website feedback",
                   body    => "User: $validUserInfo->{lastname}, $validUserInfo->{firstname}\n\nSubject: '$parameters->{subject}'\n\nBody:\n'$parameters->{body}'\n\nFull User Info: $fullUserInfo\n" };

  my $sent = AppserverCall( 'SendEmail', "webajob\@webajob.com", $mailData );
}

1;
