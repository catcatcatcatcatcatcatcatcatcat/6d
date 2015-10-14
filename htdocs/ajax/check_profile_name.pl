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
SELECT profile_name
FROM `user_profile`
WHERE profile_name = ?
LIMIT 1
ENDSQL
;
my $sth = $DBH->prepare_cached($query);
$sth->execute($params->{profile_name});
if ($sth->fetchrow_array) {
  print "Status: 200\n\n";
} else {
  print "Status: 404\n\n";
}
$sth->finish;
