#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

our $rusty = rusty::Profiles->new;

my ($dbh, $query, $sth, $rows);

$dbh = $rusty->DBH;



# Make the garbageman clean up every 30 mins!
# He removes old cookie test sessions,
# removes and updates user stats for expired sessions,
# and removes expired passphrase sessions.

# Delete all expired passphrase sessions (older than 30 mins)

$query = <<ENDSQL
DELETE FROM `passphrase`
WHERE created < DATE_SUB(NOW(), INTERVAL 30 MINUTE)
ENDSQL
;

if (($rows = $dbh->do($query)) ne '0E0') {
  push @{$rusty->{data}->{messages}},
    "$rows expired passphrase sessions removed.";
}

# Delete all sessions which belong to cookie tests that failed
# (leaving recent ones as they could be mid-test) - should be
# 10 seconds realistically to refresh login.pl but we'll err
# on the side of caution and leave all from the last minute.

$query = <<ENDSQL
DELETE FROM `user_session`
WHERE created IS NULL
AND updated < DATE_SUB(NOW(), INTERVAL 1 MINUTE)
ENDSQL
;

if (($rows = $dbh->do($query)) ne '0E0') {
  push @{$rusty->{data}->{messages}},
    "$rows cookie failure test sessions removed.";
}

# Grab all session information for sessions that have not been
# updated (user has not clicked on a page) for 30 mins.  These
# are the sessions that we will add to user's stats and remove.

$query = <<ENDSQL
SELECT session_id, user_id, clicks,
FLOOR((UNIX_TIMESTAMP(updated) - UNIX_TIMESTAMP(created)) / 60)
AS mins_online, updated
FROM `user_session`
WHERE updated < DATE_SUB(NOW(), INTERVAL 30 MINUTE)
ENDSQL
;
$sth = $dbh->prepare($query);
$sth->execute();

# Set up interpolated statement for use with bind values
# for the UPDATE and DELETE statements for each session id.

my $update_query = <<ENDSQL
UPDATE `user_stats`
SET last_session_end = IF(ISNULL(last_session_end), ?,
                          IF(? > last_session_end, ?, last_session_end)),
mins_online = mins_online + ?, 
num_clicks = num_clicks + ?
WHERE user_id = ?
LIMIT 1
ENDSQL
;

my $update_sth = $dbh->prepare($update_query);

my $delete_query = <<ENDSQL
DELETE FROM `user_session`
WHERE session_id = ?
LIMIT 1
ENDSQL
;

my $delete_sth = $dbh->prepare($delete_query);

my $rot_query = <<ENDSQL
UPDATE `user_session`
SET session_id = CONCAT("ERROR: ", SUBSTRING(session_id, 8)),
    user_id = NULL,
    updated = updated # Make sure it is not updated on update!
WHERE session_id = ?
LIMIT 1
ENDSQL
;
my $rot_sth = $dbh->prepare_cached($rot_query);

# Loop through each expired session found and perform
# the UPDATE and DELETE statement templates above.

while (my $expired_session = $sth->fetchrow_hashref) {

  my $mins_online = $expired_session->{'mins_online'};

  if ($mins_online < 0) {
    my $err = "We REALLY shouldn't be getting "
            . "$mins_online mins online for sessions, so "
            . "session ".$expired_session->{'session_id'}
            . " has been left to rot in it's own ridiculousness.";
    warn $err;
    $rot_sth->execute($expired_session->{'session_id'});
    push @{$rusty->{data}->{messages}}, "<b>$err</b>";
    # Leave session there to be found for debugging! =D
    next;
  }

  $rows = $update_sth->execute(
                                $expired_session->{'updated'},
                                $expired_session->{'updated'},
                                $expired_session->{'updated'},
                                $mins_online,
                                $expired_session->{'clicks'},
                                $expired_session->{'user_id'}
                              )
    || die "Unable to execute query: ".$dbh->errstr;

  if ($rows eq '0E0') {
    warn "No rows affected by update query on user id "
       . $expired_session->{'user_id'}."'s stats - "
       . "I reckon they need some stats creating..";
  }
  
  $rows = $delete_sth->execute($expired_session->{'session_id'});
  
  if ($rows eq '0E0') {
    warn "No rows affected by delete query on expired session id '"
       . $expired_session->{'session_id'}."'. This is impossible!";
  }
  
  push @{$rusty->{data}->{messages}},
    "Updated user as "
  . "last online at ".$expired_session->{'updated'}." with "
  . $expired_session->{'mins_online'}." more mins online and "
  . $expired_session->{'clicks'}." clicks, thanks to session '"
  . $expired_session->{'session_id'}."', which is now deleted.";
}
$update_sth->finish;
$delete_sth->finish;
$rot_sth->finish;
$sth->finish;

# Update site~benchmark~stats averages -
# this only needs to be run just after midnight every night.
my $site_benchmarks_query = <<ENDSQL
UPDATE `site_stats_benchmarks` SET
mean_benchmark = TRUNCATE(total_time / num_benchmarks,3)
WHERE mean_benchmark IS NULL
  AND num_benchmarks > 0
  AND date < CURRENT_DATE()
ENDSQL
;
if (($rows = $dbh->do($site_benchmarks_query)) ne '0E0') {
  push @{$rusty->{data}->{messages}},
    "$rows site benchmarks stats' averages calculated.";
}


#use GTop ( ); 
#print "Shared memory of the current process: ", 
#    GTop->new->proc_mem($$)->share, "\n"; 
#print "Total shared memory: ",
#    GTop->new->mem->share, "\n"; 


$rusty->{ttml} = "garbageman.ttml";

$rusty->process_template;
$rusty->exit;


$rusty->exit;
