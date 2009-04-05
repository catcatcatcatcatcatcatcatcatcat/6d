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
SELECT SQL_CACHE subentity_code, name
FROM `lookup~continent~country~city1000`
WHERE country_code = ?
ORDER BY name
ENDSQL
;


my $sth = $DBH->prepare_cached($query);
$sth->execute($params->{country_code});
my $output_text = "";
use HTML::Entities 'encode_entities';
while (my ($subentity_code, $subentity_name) = $sth->fetchrow_array) {
  utf8::decode($subentity_name);
  $output_text .= $subentity_code.'|'.HTML::Entities::encode_entities($subentity_name).'||';
}

$sth->finish;

chop($output_text);
chop($output_text);
print "Content-type: text/plain; charset=UTF-8\n\n";
print $output_text;

