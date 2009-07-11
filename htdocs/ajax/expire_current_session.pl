#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use rusty;

rusty::init();

my $DBH = rusty::db_connect();

my $session_cookie = rusty::CGI->cookie( -name => "session" );

my $query = <<ENDSQL
UPDATE `user~session` SET
created = DATE_SUB(created, INTERVAL 1 HOUR),
updated = DATE_SUB(updated, INTERVAL 1 HOUR)
WHERE session_id = ?
  AND updated > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
  AND created IS NOT NULL
LIMIT 1
ENDSQL
;
my $sth = $DBH->prepare_cached($query);
my $rows = $sth->execute($session_cookie);
$sth->finish;

if ($rows eq '0E0') {
  die "No session to expire for session id: $session_cookie";
} else {
  print "Status: 200\n\n";
}
