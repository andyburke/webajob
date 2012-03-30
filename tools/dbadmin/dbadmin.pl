#!/usr/bin/perl


use strict;

use Getopt::Long;
use Config::IniFiles;
use Carp;
use File::Spec;

use DBI;

my $getHelp = 1;
my $configFilename;
my @serverNames;

if(!GetOptions(
               'config=s'  => \$configFilename,
               'server=s@' => \@serverNames,
               'create'    => \&Create,
               'drop'      => \&Drop,
               'help'      => \$getHelp,
               'h'         => \$getHelp,
              )
   or $getHelp)
{

  print qq{
Usage:
  dbadmin [--config <config filename>] --server=<servername|all> --create|--drop [--help|--h]
    --config  specify a config other than config/default.ini to use
    --server  specify the server to operate on, 'all' will cause all servers to be affected
    --create  create databases
    --drop    drop databases
    --help|h  get this message

};
  exit;
}

sub ParseConfig
{
  $getHelp = 0;

  defined $configFilename or $configFilename = File::Spec->rel2abs('../config/default.ini');
  -f $configFilename or croak("Config file $configFilename doesn't exist");

  my $config = Config::IniFiles->new( -file => $configFilename );
  $config or croak("Some serious problem creating a Config::IniFiles object");
  return $config;
}

sub Create
{
  my $config = ParseConfig();

  if($serverNames[0] eq 'all')
  {
    @serverNames = $config->Sections();
  }

  foreach my $serverName (@serverNames)
  {
    next if($serverName eq 'global');

    print "Creating database for server: $serverName\n";
    
    my $dbSchema = $config->val($serverName, 'dbSchema');
    if(!$dbSchema)
    {
      print "  WARNING: dbSchema not set!\n\n";
      next;
    }
    my $schemaFile = File::Spec->rel2abs($dbSchema);
    if(!-e $schemaFile)
    {
      print "  WARNING: Could not locate schema file: $schemaFile\n\n";
      next;
    }
    print "  schema file: $schemaFile\n";
    
    my $dbDsn = $config->val($serverName, 'dbDsn');
    if(!$dbDsn)
    {
      print "  WARNING: dbDsn not set!\n\n";
      next;
    }
    print "  dsn: $dbDsn\n";
    
    my $dbUsername = $config->val($serverName, 'dbUsername');
    my $dbPassword = $config->val($serverName, 'dbPassword');
    print "  username: $dbUsername\n";
    print "  password: $dbPassword\n";
    
    my $dbh = DBI->connect($dbDsn, $dbUsername, $dbPassword);
    if(!$dbh)
    {
      print "  WARNING: Could not connect to database: $dbDsn\n\n";
      next;
    }

    if(!open(SCHEMA, $schemaFile))
    {
      print "  WARNING: Could not open schema file: $schemaFile\n\n";
      next;
    }
    my $fileContent = join('', <SCHEMA>);
    close(SCHEMA);
    
    # FIXME not real SQL parsing, but whatever...
    my @statements = split(';', $fileContent);
    foreach my $statement (@statements)
    {
      # skip statements that are pure whitespace
      next if $statement !~ /\S/;
      
      #    print "  executing: $statement\n";
      $dbh->do($statement);
    }

    print "Done.\n\n";
  }
}

sub Drop
{
  my $config = ParseConfig();

  if($serverNames[0] eq 'all')
  {
    @serverNames = $config->Sections();
  }

  foreach my $serverName (@serverNames)
  {
    next if($serverName eq 'global');
    
    print "Dropping database for server: $serverName\n";

    my $dbDsn = $config->val($serverName, 'dbDsn');
    if(my ($filename) = ($dbDsn =~ /dbi:SQLite2:.*?dbname=([^;]+)/))
    {
      if(!unlink($filename))
      {
        print "  WARNING: Couldn't delete db file: $filename\n\n";
        next;
      }
    }
    else
    {
      print "  WARNING: Don't understand this type of database!\n";
      next;
    }

    print "Done.\n\n";
  }
}
