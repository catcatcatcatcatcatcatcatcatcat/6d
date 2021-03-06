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
SELECT SQL_CACHE c.subentity_code, c.name AS subentity_name,
       c.latitude, c.longitude,
       c.population, c.elevation,
       c.TimeZoneId AS timezone,
       t.GMT_offset_2007_01_01 AS gmt_offset,
       IF(c.latitude>=0,
          CONCAT(FORMAT(c.latitude,3),'&deg;N'),
          CONCAT(FORMAT(c.latitude*-1,3),'&deg;S')) AS latitude_formatted,
       IF(c.longitude>=0,
          CONCAT(FORMAT(c.longitude,3),'&deg;E'),
          CONCAT(FORMAT(c.longitude*-1,3),'&deg;W')) AS longitude_formatted
FROM `lookup_continent_country_city1000` c
LEFT JOIN `lookup_continent_country_city1000_timezones` t
       ON t.TimeZoneId = c.TimeZoneId
WHERE c.country_code = ?
ORDER BY c.name
ENDSQL
;

my $sth = $DBH->prepare_cached($query);
$sth->execute($params->{country_code});
my $output_text = "";
use HTML::Entities 'encode_entities';
while (my ($subentity_code, $subentity_name, $latitude, $longitude,
           $population, $elevation, $timezone, $gmt_offset,
           $latitude_formatted, $longitude_formatted) = $sth->fetchrow_array) {
  $gmt_offset =~ s/\.0$//o; $gmt_offset =~ s/^(?!-)/\+/; $gmt_offset = 'GMT' . $gmt_offset;
  $elevation ||= 'unknown';
  utf8::decode($subentity_name);
  $output_text .= $subentity_code.'|'.HTML::Entities::encode_entities($subentity_name).'|'.$latitude.'|'.$longitude.'|'
                 .$population.'|'.$elevation.'|'.$timezone.'|'.$gmt_offset.'|'
                 .$latitude_formatted.'|'.$longitude_formatted.'||';
}

$sth->finish;

chop($output_text);
chop($output_text);
print "Content-type: text/plain; charset=UTF-8\n\n";
print $output_text;

