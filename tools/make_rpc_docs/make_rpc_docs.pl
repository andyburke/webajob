#!/usr/bin/perl

use strict;
use RPC::XML;
use RPC::XML::Client;
use IO::Dir;
use IO::File;
use ClearSilver;
use Data::Dumper;


my $hdf;
my $template_filename = "make_rpc_docs.cst";
my $template_index_filename = "make_rpc_docs_index.cst";
my $doc_path = '../docs/servers/auto-generated';
my @server_names;


dump_output_template();
dump_output_index_template();


my $dir = IO::Dir->new('.');
while (defined (my $filename = $dir->read))
{
  next unless $filename =~ /^(.*?)\.port$/;
  my $server_name = $1;
  push @server_names, $server_name;

  my $port_file = IO::File->new($filename);
  my ($port) = $port_file->getline =~ /(\d+)/;
  my $url = "http://localhost:$port/RPCSERV";
  print "probing server: $server_name @ $url\n";

  my $client = RPC::XML::Client->new($url);
  my $result = $client->send_request('system.introspection');
  my @methods = sort { $a->{name} cmp $b->{name} } @{$result->value};

  $hdf = ClearSilver::HDF->new();
  $hdf->setValue("server.name", $server_name);
  encode_hdf("server.name", $server_name);

  my $i = 0;
  foreach my $method_data (@methods) {
    next if $method_data->{name} =~ /^system\./;
    print "  method: $method_data->{name}\n";
    encode_hdf("methods.$i", $method_data);
    $i++;
  }

  my $cs = ClearSilver::CS->new($hdf);
  $cs->parseFile($template_filename);
  my $doc_file = IO::File->new(">$doc_path/$server_name.html");
  $doc_file->print($cs->render);

  print "\n";
}


print "\nwriting index\n";

$hdf = ClearSilver::HDF->new();
@server_names = sort @server_names;
encode_hdf("server_names", \@server_names);
my $cs = ClearSilver::CS->new($hdf);
$cs->parseFile($template_index_filename);
my $doc_file = IO::File->new(">$doc_path/index.html");
$doc_file->print($cs->render);


unlink($template_filename);
unlink($template_index_filename);


# ===========================


# recursively encode a perl data structure into $hdf (global)
sub encode_hdf
{
  my ($node_label, $data) = @_;

  my $child_prefix = $node_label;
  $child_prefix .= '.' if defined $node_label; # don't prefix root (undefined node_label) with a .

  if (ref $data eq 'HASH')
  {
    while (my ($key, $value) = each %$data)
    {
      encode_hdf($child_prefix . $key, $value);
    }
  }
  elsif (ref $data eq 'ARRAY')
  {
    my $index = 0;
    foreach my $value (@$data)
    {
      encode_hdf($child_prefix . $index, $value);
      $index++;
    }
  }
  else
  {
    $hdf->setValue($node_label, $data);
  }
}


sub dump_output_template {
  my $template_file = IO::File->new(">$template_filename");

  $template_file->print(<<__TEMPLATE__);
<html>
<head>
</head>
<body>

<h1>Server: <?cs var:server.name ?></h1>

<?cs each:method = methods ?>

<h2><?cs var:method.name ?></h2>
<table border="1" cellpadding="5">
  <tr>
    <td>version</td>
    <td><?cs var:method.version ?></td>
  </tr>
  <tr>
    <td>signatures</td>
    <td>
      <?cs each:signature = method.signature ?>
        <?cs var:signature ?>;
      <?cs /each ?>
    </td>
  </tr>
  <tr>
    <td>help</td>
    <td>
      <?cs var:method.help ?>
    </td>
  </tr>
</table>

<?cs /each ?>

</body>
</html>
__TEMPLATE__
}

sub dump_output_index_template {
  my $template_file = IO::File->new(">$template_index_filename");

  $template_file->print(<<__TEMPLATE__);
<html>
<head>
</head>
<body>

<h1>Backend Servers</h1>

<?cs each:server_name = server_names ?>

<a href="<?cs var:server_name ?>.html"><?cs var:server_name ?></a><br />

<?cs /each ?>

</body>
</html>
__TEMPLATE__
}
