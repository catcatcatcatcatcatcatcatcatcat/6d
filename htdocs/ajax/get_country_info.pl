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
SELECT SQL_CACHE name, capital, population,
                 areaInSqKm, currency, languages,
                 CONCAT(IF(bounding_box_north>=0,
                           CONCAT(FORMAT(bounding_box_north,3),'&deg;N'),
                           CONCAT(FORMAT(bounding_box_north*-1,3),'&deg;S')), ' - ',
                        IF(bounding_box_south>=0,
                           CONCAT(FORMAT(bounding_box_south,3),'&deg;N'),
                           CONCAT(FORMAT(bounding_box_south*-1,3),'&deg;S'))) AS latitude,
                 CONCAT(IF(bounding_box_east>=0,
                           CONCAT(FORMAT(bounding_box_east,3),'&deg;E'),
                           CONCAT(FORMAT(bounding_box_east*-1,3),'&deg;W')), ' - ',
                        IF(bounding_box_west>=0,
                           CONCAT(FORMAT(bounding_box_west,3),'&deg;E'),
                           CONCAT(FORMAT(bounding_box_west*-1,3),'&deg;W'))) AS longitude
FROM `lookup~continent~country`
WHERE country_id = ?
LIMIT 1
ENDSQL
;

my $sth = $DBH->prepare_cached($query);
$sth->execute($params->{country_id});
my $output_text = "";
my ($name, $capital, $population, $areaInSqKm, $currency, $languages,
    $latitude, $longitude) = $sth->fetchrow_array;
use HTML::Entities 'encode_entities';

# Hack to remove trailing .0 for most places that
# don't use this precision.
$areaInSqKm =~ s/\.0$//;
$output_text .= HTML::Entities::encode_entities($name).'|'
               .HTML::Entities::encode_entities($capital||'N/A').'|'.$population.'|'
               .$areaInSqKm.'|'.($currency||'N/A').'|'.($languages||'N/A').'|'
               .$latitude.'|'.$longitude;
$sth->finish;


print "Content-type: text/plain\n\n";
print $output_text;

