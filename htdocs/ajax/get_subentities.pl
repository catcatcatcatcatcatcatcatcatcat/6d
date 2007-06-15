#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use rusty;

rusty::init();

my $DBH = rusty::db_connect();

my $params = rusty::get_utf8_params();



my $query = <<ENDSQL
SELECT subentity_id, subentity_name
FROM `lookup~country~subentity`
WHERE country_id = ?
ORDER BY subentity_name
ENDSQL
;
my $sth = $DBH->prepare_cached($query);
$sth->execute($params->{country_id});
my $output_text = "";
while (my ($subentity_id, $subentity_name) = $sth->fetchrow_array) {
  $output_text .= $subentity_id.'|'.$subentity_name.'||';
}
$sth->finish;

chop($output_text);
chop($output_text);
print "Content-type: text/plain\n\n";
print $output_text;

