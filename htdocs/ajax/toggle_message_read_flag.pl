#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use rusty;
#
#my $rusty = rusty->new;
#
#use rusty::Profile::Message;
#
#my $message_id = $rusty->{params}->{message_id};
#my $profile_id = $rusty->{core}->{profile_id};

rusty::init();

my $DBH = rusty::db_connect();

my $params = rusty::get_utf8_params();

my $session_cookie = rusty::CGI->cookie( -name => "session" );

my $query = <<ENDSQL
SELECT us.user_id, u.profile_id
FROM `user_session` us
INNER JOIN `user` u ON u.user_id = us.user_id
WHERE us.session_id = ?
  AND us.updated > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
  AND us.created IS NOT NULL
LIMIT 1
ENDSQL
;
my $sth = $DBH->prepare_cached($query);
$sth->execute($session_cookie);
my ($user_id, $profile_id) = $sth->fetchrow_array();
$sth->finish;

die "no session exists for this user (session: $session_cookie)" unless $user_id;
die "user $user_id does not have a profile id" unless $profile_id;

my $message_id = $params->{message_id};
die "no message id specified by user $user_id" unless $message_id;

my $read = $params->{read};
die "no read status specified by user $user_id" unless defined $read;

my $read_flag = $read > 0 ? 1 : 0;

$query = <<ENDSQL
UPDATE `user_profile_message`
SET recipient_read_flag = ?
WHERE message_id = ?
  AND recipient_profile_id = ?
  AND recipient_read_flag != ?
  AND read_date IS NOT NULL
  AND flag != 'LINKEDFRIEND'
LIMIT 1
ENDSQL
;
$sth = $DBH->prepare_cached($query);
my $rows = $sth->execute($read_flag, $message_id, $profile_id, $read_flag);
$sth->finish;
if ($rows eq '0E0') {
  
  # If things failed, try to work out why and send back a success
  # in the case of them trying to set something that was already set
  # (as the outcome they wanted has been (was already) achieved! =)
  $query = <<ENDSQL
SELECT message_id, recipient_profile_id, recipient_read_flag, read_date, flag
FROM `user_profile_message`
WHERE message_id = ?
LIMIT 1
ENDSQL
;
  $sth = $DBH->prepare_cached($query);
  $sth->execute($message_id);
  $sth->finish;
  my ($real_message_id,
      $recipient_profile_id,
      $recipient_read_flag,
      $read_date,
      $flag) = $sth->fetchrow_array();
  if ($recipient_profile_id != $profile_id) {
    warn "profile $profile_id tried to mark message $message_id "
       . "read flag to $read_flag when message belongs to $recipient_profile_id";
    print "Status: 404\n\n";
  } elsif ($recipient_read_flag == $read_flag) {
    warn "profile $profile_id tried to mark message $message_id "
       . "read flag to $read_flag when flag was already set to $recipient_read_flag";
    print "Status: 200\n\n"; # Say it worked because the desired outcome is true!
  } elsif (!$real_message_id) {
    warn "profile $profile_id tried to mark message $message_id "
       . "read flag to $read_flag but this message id does not exist!";
    print "Status: 404\n\n";
  } elsif (!$read_date) {
    warn "profile $profile_id tried to mark message $message_id "
       . "read flag to $read_flag but message had not yet been read!";
    print "Status: 404\n\n";
  } elsif ($flag eq 'LINKEDFRIEND') {
    warn "profile $profile_id tried to mark message $message_id "
       . "read flag to $read_flag when messae was a LINKEDFRIEND alert";
    print "Status: 404\n\n";
  } else {
    warn "profile $profile_id tried to mark message $message_id "
       . "read flag to $read_flag but nothing was updated (unkown reason!)";
    print "Status: 404\n\n";
  }
  
} else {
  
  print "Status: 200\n\n";
  
}
