#!/usr/bin/perl

use strict;
use Data::Dumper;
use MIME::Base64;

my $server = Webajob::ApplicationServer->new( { name => 'application' } );    
$server->Loop;

package Webajob::ApplicationServer;

use BackendServer;
use base qw(BackendServer);

use Error;

sub DoLogin
{
  my $self  = shift;
  my $email = shift;
  my $key   = shift;

  my $userId = $self->Call( 'userinfo.GetIdFromEmail', $email );
  throw Error::Simple('Unknown user.') if ( $userId eq '' );    # id '' == unknown user

  return $self->Call( 'authentication.Authenticate', $userId, $key );
}

sub DoCreateAccount
{
  my $self = shift;
  my $data = shift;

  throw Error::Simple('Password invalid.') if ( !length( $data->{password} ) or ( $data->{password} ne $data->{password_verify} ) );

  $self->Call( 'userinfo.Add', $data );

  my $userId           = $self->Call( 'userinfo.GetIdFromEmail', $data->{email} );
  my $currencyResponse = $self->Call( 'currency.CreateAccount',  $userId );

  # FIXME move to the UI layer?
  $self->Call( 'notification.Notify', $userId, { subject => 'Welcome to webajob!', body => "Hi, welcome to webajob!\n\nHope you like dying." } );
  $self->Call( 'authentication.SetKey', $userId, $data->{password} );

  return 1;
}

sub BuyCredits
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $user_class    = shift;
  my $dollars_in    = shift;
  my $companyId     = shift;

  if ( $user_class eq 'company' )
  {
    if ( $self->Call( 'permission.Check', $currentUserId, $companyId, 'ManageCompany' ) )
    {
      return $self->Call( 'currency.AddCredits', $companyId, $user_class, $dollars_in );
    }
    else
    {
      throw Error::Simple( 'You do not have permission to manage this company' );
    }
  }
  else
  {
    return $self->Call( 'currency.AddCredits', $currentUserId, $user_class, $dollars_in );
  }

}

sub GetPurchaseRates
{
  my $self = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $user_class = shift;

  return $self->Call( 'currency.GetPurchaseRates', $user_class );
}

sub GetPrice
{
  my $self = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $product = shift;
  
  return $self->Call( 'currency.GetPrice', $product);
}

sub GetAccountBalance
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $entityId      = shift || $currentUserId;
  
  if ( $entityId != $currentUserId )
  {
    my $permission = $self->Call( 'permission.Check', $currentUserId, $entityId, 'ManageCompany' );
    throw Error::Simple( 'Permission denied' ) if !$permission;
  }
  
  return $self->Call( 'currency.GetAccountBalance', $entityId );
}

sub GetUserInfo
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift);
  my $userId        = shift || $currentUserId;

  return $self->Call( 'userinfo.GetInfo', $userId );
}

sub EditUserInfo
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $userinfoData  = shift;

  return $self->Call( 'userinfo.Edit', $currentUserId, $userinfoData );
}

sub GetUserPhoto
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift);
  my $userId        = shift || $currentUserId;

  return $self->Call( 'userinfo.GetPhoto', $userId );
}

sub GetUserPhotoInfo
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift);
  my $userId        = shift || $currentUserId;

  return $self->Call( 'userinfo.GetPhotoInfo', $userId );
}

sub EditUserPhoto
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $photoData     = shift;

  # FIXME: max dimension of 100 should be set in a global config or something
  return $self->Call( 'userinfo.EditPhoto', $currentUserId, encode_base64($photoData), 100 );
}

sub DeleteUserPhoto
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();

  return $self->Call( 'userinfo.DeletePhoto', $currentUserId );
}

sub GetUserIdFromSessionToken
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();

  return $currentUserId;
}

sub GetUserIdFromEmail
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $email         = shift;

  my $userId = $self->Call( 'userinfo.GetIdFromEmail', $email );

  if ( !$userId )
  {

    # FIXME return 0?
    throw Error::Simple("Invalid user email address.");
  }

  return $userId;
}

sub SearchUsers
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $parameters    = shift;
  my $pageNumber    = shift || 1;

  return $self->Call( 'userinfo.Search', $parameters, ( $pageNumber - 1 ) * 10, 10 );
}

sub BeginRelationship
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $targetId      = shift;
  my $typeId        = shift;
  my $sourceId      = shift || $currentUserId;

  return $self->Call( 'socialnetwork.BeginRelationship', $sourceId, $targetId, $typeId );
}

sub EndRelationship
{
  my $self           = shift;
  my $currentUserId  = $self->GetUserId(shift) or return InvalidSessionFault();
  my $relationshipId = shift;

  my $relationship = $self->Call( 'socialnetwork.GetRelationship', $relationshipId );

  if ( $currentUserId != $relationship->{source} )
  {
    throw Error::Simple("This isn't your relationship.");
  }

  return $self->Call( 'socialnetwork.EndRelationship', $relationshipId );
}

sub GetRelationship
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();

  return $self->Call( 'socialnetwork.GetRelationship', @_ );
}

sub GetRelatedEntities
{
  my $self            = shift;
  my $currentUserId   = $self->GetUserId(shift) or return InvalidSessionFault();
  my $sourceId        = shift;
  my $radius          = shift || 1;
  my $finalEntityType = shift;

  # If not asking for logged in user's relationships, ensure the requested
  # user has a relationship back to the logged in user.
  if ( $sourceId != $currentUserId )
  {
    my $hasRelationship = $self->Call( 'socialnetwork.HasRelationship', $sourceId, $currentUserId );
    if ( !$hasRelationship )
    {
      return {};
    }
  }

  return $self->Call( 'socialnetwork.GetRelatedEntities', $sourceId, $radius, $finalEntityType );
}

sub GetAllowedRelationshipTypes
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $sourceType    = shift;
  my $targetType    = shift;

  return $self->Call( 'socialnetwork.GetAllowedRelationshipTypes', $sourceType, $targetType );
}

sub GetRelationshipTypeName
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $typeId        = shift;

  return $self->Call( 'socialnetwork.GetRelationshipTypeName', $typeId );
}

sub GetResume
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $resumeId      = shift;

  # FIXME only allowed to access own resume, or anything allowed by permission server
  return $self->Call( 'resume.Get', $resumeId );
}

sub GetResumes
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $ownerId       = shift || $currentUserId;

  # FIXME only allowed to access own resume, or anything allowed by permission server
  return $self->Call( 'resume.GetAllByOwner', $ownerId );
}

sub AddResume
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $resumeData    = shift;
  my $ownerId       = shift || $currentUserId;

  # FIXME check if the current user has permission to add a resume for the given ownerId
  return $self->Call( 'resume.Add', $ownerId, $resumeData );
}

sub EditResume
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $resumeId      = shift;
  my $resumeData    = shift;

  my $resume = $self->Call( 'resume.Get', $resumeId );
  if ( $resume->{ownerid} != $currentUserId )
  {
    throw Error::Simple('You do not own this resume.');
  }

  return $self->Call( 'resume.Edit', $resumeId, $resumeData );
}

sub DeleteResume
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $resumeId      = shift;

  my $resume = $self->Call( 'resume.Get', $resumeId );
  if ( $resume->{ownerid} != $currentUserId )
  {
    throw Error::Simple('You do not own this resume.');
  }

  return $self->Call( 'resume.Delete', $resumeId );
}

sub AddCompany
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $companyData   = shift;
  my $managerId     = shift || $currentUserId;

  my $companyId = $self->Call( 'companyinfo.Add', $companyData );

  $self->Call( 'permission.Grant',                $managerId, $companyId, 'ManageCompany' );
  $self->Call( 'socialnetwork.BeginRelationship', $managerId, $companyId, 'business.employee' );
  $self->Call( 'socialnetwork.BeginRelationship', $companyId, $managerId, 'business.employer' );
  $self->Call( 'currency.CreateAccount', $companyId );

  return $companyId;
}

sub GetCompanyInfo
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $companyId     = shift;

  return $self->Call( 'companyinfo.GetInfo', $companyId );
}

sub EditCompanyInfo
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $companyId     = shift;
  my $companyData   = shift;

  if ( !$self->Call( 'permission.Check', $currentUserId, $companyId, 'ManageCompany' ) )    # they don't have permission...
  {
    throw Error::Simple("Permission denied.");
  }

  return $self->Call( 'companyinfo.Edit', $companyId, $companyData );
}

sub GetManagedCompanyIds
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();

  my $permissions = $self->Call( 'permission.Search', $currentUserId, 0, 'ManageCompany' );

  my @managedCompanyIds;
  foreach my $permission (@$permissions)
  {
    push( @managedCompanyIds, $permission->{targetid} );
  }

  return \@managedCompanyIds;
}

sub CanManageCompany
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $companyId     = shift;

  return $self->Call( 'permission.Check', $currentUserId, $companyId, 'ManageCompany' );
}

sub AddJob
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $companyId     = shift;
  my $jobData       = shift;

  my $company = $self->Call( 'companyinfo.GetInfo', $companyId );

  if ( !$self->Call( 'permission.Check', $currentUserId, $companyId, 'ManageCompany' ) )
  {
    throw Error::Simple('You cannot manage this company');
  }

  my $credits = $self->Call( 'currency.GetAccountBalance', $companyId );
  my $price = $self->Call( 'currency.GetPrice', 'ListJob' );
  
  # FIXME could we do this by just giving the super user unlimited credits?
  # We do not want to check the super user's credits during dataspoofing
  # FIXME super user's uuid is just encoded here
  if ( $currentUserId != '63EE5C90-4734-11DA-A62D-F099B7EBB437' )
  {  
    if ( $credits < $price )
    {
      throw Error::Simple("You do not have enough credits to create this job listing");
    }
    else
    {
      $self->Call( 'currency.SubtractCredits', $companyId, $price );
    }
  }

  return $self->Call( 'job.Add', $companyId, $jobData );
}

sub GetJob
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $jobId         = shift;

  # FIXME must be related to company in social network (R3?)
  return $self->Call( 'job.Get', $jobId );
}

sub GetJobsByCompany
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $companyId     = shift;

  $self->Call( 'companyinfo.GetInfo', $companyId );

  if ( !$self->Call( 'permission.Check', $currentUserId, $companyId, 'ManageCompany' ) )
  {
    throw Error::Simple('You cannot manage this company');
  }

  return $self->Call( 'job.GetByCompany', $companyId );
}

sub EditJob
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $jobId         = shift;
  my $jobData       = shift;

  my $job = $self->Call( 'job.Get', $jobId );

  if ( !$self->Call( 'permission.Check', $currentUserId, $job->{ownerid}, 'ManageCompany' ) )
  {
    throw Error::Simple('You do not have permission to edit this job.');
  }

  return $self->Call( 'job.Edit', $jobId, $jobData );
}

sub DeleteJob
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $jobId         = shift;

  my $job = $self->Call( 'job.Get', $jobId );

  if ( !$self->Call( 'permission.Check', $currentUserId, $job->{ownerid}, 'ManageCompany' ) )
  {
    throw Error::Simple('You do not have permission to delete this job.');
  }

  return $self->Call( 'job.Delete', $jobId );
}

sub SearchJobs
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $jobCriteria   = shift;

  # FIXME check with currency server

  # FIXME hard code radius to R4.  is this an OK limit?  allow user to constrain radius to less than that?
  my @relatedCompanyIds = keys( %{ $self->Call( 'socialnetwork.GetRelatedEntities', $currentUserId, 4, 'company' ) } );

  my @jobs;
  foreach my $companyId (@relatedCompanyIds)
  {
    $jobCriteria->{ownerid} = $companyId;
    my $result = $self->Call( 'job.Search', $jobCriteria );
    push(@jobs, @{$result}) if(@{$result});
  }

  return \@jobs;
}

sub SearchResumes
{
  my $self           = shift;
  my $currentUserId  = $self->GetUserId(shift) or return InvalidSessionFault();
  my $resumeCriteria = shift;

  # FIXME must be related to user in social network (R4?)
  # FIXME check with currency server
  return $self->Call( 'resume.Search', $resumeCriteria );
}

sub SendEmail
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $emailAddress  = shift;
  my $emailData     = shift;

  return $self->Call( 'notification.Email', $emailAddress, $emailData );
}

sub Notify
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $targetId      = shift;
  my $messageData   = shift;

  return $self->Call( 'notification.Notify', $targetId, $messageData );
}

sub ApplyForJob
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $jobId         = shift;
  my $resumeId      = shift;

  #FIXME notify companies when they're applied to...

  my $user = $self->Call( 'userinfo.GetInfo', $currentUserId );
  my $job  = $self->Call( 'job.Get',          $jobId );
  my $companyId = $job->{ownerid};

  my $credits = $self->Call( 'currency.GetAccountBalance', $currentUserId );
  my $price = $self->Call( 'currency.GetPrice', 'ApplyForJob' );
  
  if ( $credits < $price )
  {
    throw Error::Simple("You do not have enough credits to apply for this job");
  }
  else
  {
    $self->Call( 'currency.SubtractCredits', $currentUserId, $price );
  }
  
  my $shortestPath = $self->Call( 'socialnetwork.GetShortestPath', $currentUserId, $job->{ownerid}, 1 );
  if ( !@$shortestPath )
  {
    throw Error::Simple("You have no relationship with this job!");
  }

  return $self->Call( 'job.Apply', $jobId, $currentUserId, $resumeId );
}

sub GetJobApplications
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $jobId         = shift;

  my $jobApplications = $self->Call( 'job.GetApplications', $jobId );

  foreach my $jobApplication ( @{$jobApplications} )
  {
    my $applicant = $self->Call( 'userinfo.GetInfo', $jobApplication->{applicant_id} );
    $jobApplication->{applicant} = $applicant;
  }

  return $jobApplications;
}

sub GetJobApplication
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $applicationId = shift;

  return $self->Call( 'job.GetApplication', $applicationId );
}

sub SetApplicationPaths
{
  my $self             = shift;
  my $currentUserId    = $self->GetUserId(shift) or return InvalidSessionFault();
  my $applicationId    = shift;
  my $applicationPaths = shift;

  my $user        = $self->Call( 'userinfo.GetInfo',   $currentUserId );
  my $application = $self->Call( 'job.GetApplication', $applicationId );
  my $job         = $self->Call( 'job.Get',            $application->{job_id} );
  $self->Call( 'job.SetApplicationPaths', $application->{id}, $applicationPaths );

  foreach my $applicationPath ( split( ';', $applicationPaths ) )
  {
    my $relatedEntity = ( split( ',', $applicationPath ) )[0];
    my $url = "http://www.webajob.com/index.pl?webui_view=RateJobApplicant&application_id=$applicationId";
    my $messageData = {
                        subject => qq{$user->{firstname} needs your help},
                        body    => qq{$user->{firstname} $user->{lastname} is applying for a job as a $job->{title} in $job->{location}.  Please take a few seconds to let us know how well $user->{firstname} would fit in this position by clicking below.\n\n$url},
                      };
    $self->Call( 'notification.Notify', $relatedEntity, $messageData );
  }
}

sub RateJobApplicant
{
  my $self          = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my $applicationId = shift;
  my $rating        = shift;

  my $user        = $self->Call( 'userinfo.GetInfo',   $currentUserId );
  my $application = $self->Call( 'job.GetApplication', $applicationId );
  my $job         = $self->Call( 'job.Get',            $application->{job_id} );

  my $ratedApplicant = 0;
  foreach my $path ( split( ';', $application->{paths} ) )
  {
    my @relatedEntities = split( ',', $path );

    for ( my $i = 0 ; $i < @relatedEntities ; ++$i )
    {

      # if we get to the current user, and there's someone else in the chain...
      if ( $relatedEntities[$i] == $currentUserId )
      {
        my $rating = $self->Call( 'job.RateApplication', $applicationId, $currentUserId, $rating );
        $ratedApplicant = 1;

        if ( $relatedEntities[ $i + 1 ] )
        {
          my $url = "http://www.webajob.com/index.pl?webui_view=CreateTrustRelationship&source_id=" . $relatedEntities[ $i + 1 ] . "&dest_id=$currentUserId";
          my $messageData = {
                              subject => qq{A job applicant has been referred to you by $user->{firstname}},
                              body    => qq{$user->{firstname} $user->{lastname} has rated someone applying for the job $job->{title} in $job->{location}.  Please take a few seconds to let us know how well you think $user->{firstname}'s recommendation applies.\n\n$url},
                            };
          $self->Call( 'notification.Notify', $relatedEntities[ $i + 1 ], $messageData );
        }
        last;
      }
    }
  }

  return $ratedApplicant;
}

sub GetPaths
{
  my $self = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my ( $sourceId, $destId, $reciprocal ) = @_;

  return $self->Call( 'socialnetwork.GetPaths', $sourceId, $destId, $reciprocal );
}

sub GetShortestPaths
{
  my $self = shift;
  my $currentUserId = $self->GetUserId(shift) or return InvalidSessionFault();
  my ( $sourceId, $destId, $reciprocal ) = @_;

  return $self->Call( 'socialnetwork.GetShortestPaths', $sourceId, $destId, $reciprocal );
}

# ==============================================================

sub GetUserId
{
  my $self      = shift;
  my $sessionId = shift;
  return $self->Call( 'authentication.GetUserIdFromSessionToken', $sessionId );
}

sub InvalidSessionFault
{
  throw Error::Simple("Invalid session");
}

