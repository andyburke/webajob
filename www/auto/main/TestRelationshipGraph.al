package main;

sub TestRelationshipGraph
{
  my $sourceId = $cgi_params->{source_id};
  
  print "Content-type: text/plain\n\n";
  use Data::Dumper;
  
  print Dumper AppserverCall('GetRelatedEntities', $sourceId, 2, 'company');
  exit;

}

1;