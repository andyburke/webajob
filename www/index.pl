#!/usr/bin/perl
##!/usr/bin/env PERLDB_OPTS=TTY=/dev/pts/1 perl -d

use strict;

BEGIN
{
  push( @INC, '../lib/perl' );
}

use CGI qw(-private_tempfiles);
use ClearSilver;
use URI;
use URI::QueryParam;
use Data::Dumper;

use RPC::Lite::Client;
use RPC::Lite::Transport::TCP;
use RPC::Lite::Serializer::JSON;

use AutoLoader 'AUTOLOAD';

our $cgi = CGI->new;
our $hdf = ClearSilver::HDF->new();
our $cs  = ClearSilver::CS->new($hdf);

#################################################################
## set up appserver connection...

# FIXME configgable locator address
our $masterServerClient = RPC::Lite::Client->new(
                                                  {
                                                    Transport => RPC::Lite::Transport::TCP->new(
                                                                                                 {
                                                                                                   Host => 'localhost',
                                                                                                   Port => 10000,
                                                                                                 }
                                                                                               ),
                                                    Serializer => RPC::Lite::Serializer::JSON->new(),
                                                  }
                                                );
complain("Could not connect to master server!") if ( !defined($masterServerClient) );

our $applicationServerInfo = $masterServerClient->Request( 'GetInfo', 'application' );    
complain("Could not retrieve application server info!") if ( !defined($applicationServerInfo) );

our $applicationClient = RPC::Lite::Client->new(
                                                 {
                                                   Transport  => $applicationServerInfo->{transportType}->new( { Host => $applicationServerInfo->{transportArgs}->{LocalAddr}, Port => $applicationServerInfo->{transportArgs}->{ListenPort} } ),
                                                   Serializer => $applicationServerInfo->{serializerType}->new( $applicationServerInfo->{serializerArgs} )
                                                 }
                                               );
complain("Could not retrieve application server info!") if ( !defined($applicationServerInfo) );

## end setting up appserver connection...
###################################################################

our $bad_user_error = [ 'You must be logged in to proceed.', 'Login' ];

# FIXME will we need to store more than a single scalar in here?
our $session_id = $cgi->cookie('webajob_session');
our $cgi_params = $cgi->Vars;
our $view_name  = $cgi_params->{webui_view};
our %headers;
our $validUser     = 0;
our $validUserInfo = {};
our $input_data    = {};    # cgi params get put in here for controller implementors
our $output_data   = {};    # controllers can put template data in here
our $output_content;        # setting this skips the template step and just sends this content to the browser

defined $view_name or $view_name = 'Main';

if ( defined $session_id and length($session_id) )
{

  # set cookie with id of refreshed session, or delete an expired session
  $headers{-cookie} = GetLoggedInUserInfo();
}

if ( defined $cgi_params->{error_string} )
{
  $output_data->{error}{string} = $cgi_params->{error_string};
}

if( defined($cgi_params->{message}) )
{
  $output_data->{message} = $cgi_params->{message};
}

# FIXME copy array in one line, one line per delete
foreach my $param_name ( keys %$cgi_params )
{
  next if $param_name eq 'webui_view' or $param_name eq 'error_string';
  $input_data->{$param_name} = $cgi_params->{$param_name};
}

#=== Call the sub for the view ==============
no strict 'refs';
my $result = eval { $view_name->() };
use strict 'refs';

#============================================

encode_hdf( undef, $output_data );

my ( $error_string, $error_dest_view, $webui_dest );
if ($@)
{
  $error_dest_view = 'Error';
  if ( $@ =~ /^undefined subroutine/i )
  {
    $error_string = "Undefined view '$view_name'";
  }
  else
  {
    $error_string = "Unhandled error: $@";
  }
}
elsif ( ref $result eq 'ARRAY' )
{
  $error_string    = $result->[0];
  $error_dest_view = $result->[1];
  if ( !defined $error_dest_view )
  {
    my ($previous_view) = $cgi->referer =~ /webui_view=(\w+)/;
    $error_dest_view = $previous_view || 'Error';    # ensure it always gets SOME value
  }

  if ( !length($error_string) )
  {
    $error_string = "Hey fuckup, return an error string.";
  }

  if ( $cgi->request_method =~ /^(GET|HEAD)/ )       # include HEAD or not?
  {
    $webui_dest = $cgi->query_string;
  }
}
elsif ( ref $result eq 'HASH' )
{
  
}


if ( length($error_string) )
{
  my $uri = URI->new;
  $uri->path('index.pl');
  $uri->query_param( webui_view   => $error_dest_view );
  $uri->query_param( error_string => $error_string );
  $uri->query_param( webui_dest   => $webui_dest ) if defined $webui_dest;
  $headers{-location} = $uri->as_string;    # FIXME: XSS exploit in error_string
  $headers{-status}   = '302 Moved';
}
elsif( $headers{-location} )
{
  my $uri = URI->new;
  $headers{-location} .= "&message=" . $output_data->{message};
}
else
{
  $cs->parseFile("templates/$view_name.cst");
}

print $cgi->header(%headers);

# just print $output_content if the controller set it, otherwise render a template
print defined $output_content ? $output_content : $cs->render;

exit;

# =============================================================================

sub AppserverCall
{
  my $method_name = shift(@_);
  my @params      = @_;

  # inject session_id into all calls except a few special cases
  if ( !grep { $method_name eq $_ } qw(DoLogin DoCreateAccount) )
  {
    unshift( @params, $session_id );
  }

  my $result = eval { $applicationClient->Request( $method_name, @params ); };
  if ($@)
  {
    handle_error($@);
  }
  return $result;
}

sub handle_error
{
  my $message = shift;

  my ( undef, undef, $line, $sub ) = caller(2);
  my $error_message = ref $message ? Dumper($message) : $message;
  $output_data->{error}{string} = "$sub, line $line\n\n$error_message";
  encode_hdf( undef, $output_data );

  $cs->parseFile("templates/Error.cst");

  print $cgi->header();
  print $cs->render();

  exit;
}

# returns a cookie that is passed back to the user's browser
sub GetLoggedInUserInfo
{
  my $userinfo = eval { $applicationClient->Request( 'GetUserInfo', $session_id ); };
  if ($@)
  {
    $view_name = 'Login';
    $cgi_params->{error_string} = "Session expired, please log in again.";

    # FIXME: set webui_dest appropriately so when user logs back in, they go to where they left off.
    #   this will also require some way to include the params from their last request.  do these things
    #   for GET only! (and HEAD?)
    return $cgi->cookie(
                         -name    => 'webajob_session',
                         -value   => '',
                         -expires => '-1y',
                       );
  }

  $validUserInfo = $userinfo;
  $output_data->{validuser} = $validUserInfo;

  my $managedCompanyIds = AppserverCall('GetManagedCompanyIds');
  foreach my $managedCompanyId (@$managedCompanyIds)
  {
    my $companyInfo = AppserverCall( 'GetCompanyInfo', $managedCompanyId );
    $companyInfo->{credits} = AppserverCall( 'GetAccountBalance', $managedCompanyId );
    print STDERR Dumper($companyInfo);
    push @{ $output_data->{managedcompanies} }, $companyInfo;
  }

  $validUser = 1;

  # FIXME -secure when SSL is rolling.  -domain?
  return $cgi->cookie(
                       -name    => 'webajob_session',
                       -value   => $session_id,
                       -expires => '+30m'
                     );
}

sub GetRelationshipTypeDisplayString
{
  my $type = shift;

  # FIXME hash lookup / translation system
  $type =~ s/.*\.//;

  return $type;
}

# recursively encode a perl data structure into $hdf (global)
sub encode_hdf
{
  my ( $node_label, $data ) = @_;

  my $child_prefix = $node_label;
  $child_prefix .= '.' if defined $node_label;    # don't prefix root (undefined node_label) with a .

  if ( ref $data eq 'HASH' )
  {
    while ( my ( $key, $value ) = each %$data )
    {
      encode_hdf( $child_prefix . $key, $value );
    }
  }
  elsif ( ref $data eq 'ARRAY' )
  {
    my $index = 0;
    foreach my $value (@$data)
    {
      encode_hdf( $child_prefix . $index, $value );
      $index++;
    }
  }
  else
  {
    $hdf->setValue( $node_label, $data );
  }
}

sub complain
{
  my $text = shift;

  print "Content-type: text/plain\n\n";
  print $text;
  exit;
}
