#!/usr/bin/perl
use strict;

my $server = Webajob::NotificationServer->new( { name => 'notification' } );
$server->Loop;

package Webajob::NotificationServer;

use BackendServer;
use base qw(BackendServer);

use Error;
use MIME::Lite;
use Data::Dumper;

my $fromAddr = 'support@webajob.com';

# Notify is used for entities we know about, who may have some
# preferred method of contact.
sub Notify
{
  my $self        = shift;
  my $targetId    = shift;
  my $messageData = shift;

  print "notification.Notify: ", Dumper( [ $targetId, $messageData ] );

  if ( -e 'NONOTIFICATION' )
  {
    print "WARNING: Skipping notification due to presence of a 'NONOTIFICATION' file!\n";
    return 1;
  }

  # FIXME support something other than users?
  my $userInfo = $self->Call( 'userinfo.GetInfo', $targetId );

  my $mimeMsg = MIME::Lite->new(
                                 From    => $fromAddr,
                                 To      => $userInfo->{email},
                                 Subject => $messageData->{subject},
                                 Data    => $messageData->{body},
                               );

  $mimeMsg->send();
  return 1;
}

# Email just blazes an email out to the given address
sub Email
{
  my $self         = shift;
  my $emailAddress = shift;
  my $messageData  = shift;

  if ( -e 'NONOTIFICATION' )
  {
    print "WARNING: Skipping email due to presence of a 'NONOTIFICATION' file!\n";
    return 1;
  }

  my $mimeMsg = MIME::Lite->new(
                                 From    => $fromAddr,
                                 To      => $emailAddress,
                                 Subject => $messageData->{subject},
                                 Data    => $messageData->{body},
                               );

  return $mimeMsg->send();
}

1;    
