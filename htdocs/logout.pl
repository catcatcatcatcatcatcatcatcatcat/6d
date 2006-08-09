#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

#
# logoout.pl - Logs out the currently logged in user.
#
# This could just remove the cookie and the user would be
# logged out but it seems best to remove the session from
# the server so the user can log in again from another machine
# within 30 mins and it won't complain that they're logged in
# somewhere else (which it did during testing) and it seemed a
# little unprofessional since they had clicked log out and it
# had logged them out but it still thought they were logged in!
# So yes, this is overkill but it won't be called that often so
# i don't expect anyone will be wounded by the inefficency.




use rusty;

our $rusty = rusty->new;

my $dbh = $rusty->DBH;




# Grab session id that wants to be logged out or whinge if no cookie!

#my $session_id = $rusty->CGI->cookie( -name => "session" )
#  || print $rusty->CGI->redirect( -url => "/" )
#    && warn "You weren't even logged in! How do you expect to log out? FOOL!"
#      && $rusty->exit;
if (!$rusty->session_cookie) {
  warn "user has no session cookie";
  print $rusty->CGI->redirect( -url => "/" );
  $rusty->exit;
} elsif (!$rusty->{core}->{'user_id'}) {
  warn "user is not logged in";
  print $rusty->CGI->redirect( -url => "/" );
  $rusty->exit;
}


# Grab all session info up to now for this user's session(s)

my $query = <<ENDSQL
SELECT user_id, clicks,
FLOOR((UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(created)) / 60)
AS mins_online
FROM `user~session`
WHERE session_id = ?
AND updated > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
AND created IS NOT NULL
LIMIT 1
ENDSQL
;
my $sth = $dbh->prepare_cached($query);
$sth->execute($rusty->session_cookie);
my ($user_id, $num_clicks, $mins_online) = $sth->fetchrow_array;
$sth->finish;

if ($user_id) {

  # Update stats for this user with session about to be logged out
  
  my $update_query = <<ENDSQL
UPDATE `user~stats`
SET last_session_end = NOW(),
mins_online = mins_online + ?, 
num_clicks = num_clicks + ?
WHERE user_id = ?
LIMIT 1
ENDSQL
;
  $sth = $dbh->prepare_cached($update_query);
  $sth->execute($mins_online, $num_clicks, $user_id);
  $sth->finish;

  # Delete the session from the database

  my $delete_query = <<ENDSQL
DELETE FROM `user~session`
WHERE session_id = ?
LIMIT 1
ENDSQL
;
  $sth = $dbh->prepare_cached($delete_query);
  $sth->execute($rusty->session_cookie);
  $sth->finish;
  
  # Clean up any other old sessions if they exist..
  $rusty->cleanUpOldUserSession($user_id);
  
} else {

  warn "Session id '".$rusty->session_cookie."' has already been removed (or will be soon!).";

}


# Send back to main page with cookie set to a value
# that should make the index page destroy it and leave
# a nice message (as well as closing the assistant if
# neccessary)..
my $delete_cookie;
if ($rusty->{params}->{'comingfrommyass'}) {
  
  $delete_cookie = $rusty->CGI->cookie( -name    => "session",
                                        -value   => 'loggedout',
                                        -expires => '+1h' );

} else {
  
  $delete_cookie = $rusty->CGI->cookie( -name    => "session",
                                        -value   => 'killmyass',
                                        -expires => '+1h' );
  
}

print $rusty->CGI->redirect( -url => "/",
                             -cookie => $delete_cookie );

$rusty->exit;

