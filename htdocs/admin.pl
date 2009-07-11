#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Admin;

use vars qw($rusty $query $sth);

$rusty = rusty::Admin->new;

$rusty->{ttml} = "admin.ttml";

$rusty->{core}->{'ref'} = $rusty->{params}->{'ref'};

$rusty->populate_site_stats();

# mean benchmark times per day for last week
$query = <<ENDSQL
SELECT date,
       SUM(num_benchmarks) AS hits,
       ROUND(SUM(total_time) / SUM(num_benchmarks)) AS mean
FROM `site~stats~benchmarks`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 WEEK)
GROUP BY date
ORDER BY date DESC
ENDSQL
;

$sth = $rusty->DBH->prepare_cached($query);
$sth->execute();
while (my $figures = $sth->fetchrow_hashref) {
  push @{$rusty->{data}->{bydate}->{day}}, $figures;
}
$sth->finish;

# all request times - slowest first
$query = <<ENDSQL
SELECT IF(mode='',script,CONCAT_WS('?mode=', script, mode)) AS request,
       SUM(num_benchmarks) AS hits,
       ROUND(SUM(total_time) / SUM(num_benchmarks)) AS mean
FROM `site~stats~benchmarks`
GROUP BY request
ORDER BY mean DESC
ENDSQL
;

$sth = $rusty->DBH->prepare_cached($query);
$sth->execute();
while (my $figures = $sth->fetchrow_hashref) {
  push @{$rusty->{data}->{benchmarks}->{byrequest}->{speed}}, $figures;
}
$sth->finish;

# all request times - most popular first
$query = <<ENDSQL
SELECT IF(mode='',script,CONCAT_WS('?mode=', script, mode)) AS request,
       SUM(num_benchmarks) AS hits,
       ROUND(SUM(total_time) / SUM(num_benchmarks)) AS mean
FROM `site~stats~benchmarks`
GROUP BY request
ORDER BY hits DESC
ENDSQL
;

$sth = $rusty->DBH->prepare_cached($query);
$sth->execute();
while (my $figures = $sth->fetchrow_hashref) {
  push @{$rusty->{data}->{benchmarks}->{byrequest}->{popularity}}, $figures;
}
$sth->finish;

# site stats - (make graph out of this)
$query = <<ENDSQL
SELECT IF(date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 WEEK),
          DATE_FORMAT(date, "%Y-%m-%d"),
          IF(YEAR(date) = YEAR(CURRENT_DATE()),
             DATE_FORMAT(date, "%X wk %v"),
             DATE_FORMAT(date, "%Y")
          )
       ) AS period,
       SUM(signups) AS signups,
       SUM(logins) AS logins,
       SUM(nocookies) AS nocookies,
       SUM(warnings) AS warnings,
       SUM(deaths) AS deaths,
       SUM(passphrase_hit) AS passphrase_hit,
       SUM(passphrase_near_miss) AS passphrase_near_miss,
       SUM(passphrase_miss) AS passphrase_miss
FROM `site~stats`
GROUP BY period
ORDER BY period DESC
ENDSQL
;

$sth = $rusty->DBH->prepare_cached($query);
$sth->execute();
while (my $figures = $sth->fetchrow_hashref) {
  push @{$rusty->{data}->{stats}}, $figures;
}
$sth->finish;

$rusty->process_template;
$rusty->exit;
