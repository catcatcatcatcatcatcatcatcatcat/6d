#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use rusty;

rusty::init();

my $DBH = rusty::db_connect();

my $params = rusty::get_utf8_params();

my $session_cookie = rusty::CGI->cookie( -name => "session" );

my $query = <<ENDSQL
SELECT us.user_id, u.profile_id
FROM `user~session` us
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

my $flagged = $params->{flagged};
die "no flagged status specified by user $user_id" unless defined $flagged;

my $flagged_flag = $flagged > 0 ? 1 : 0;

$query = <<ENDSQL
UPDATE `user~profile~message` SET
  recipient_flagged_flag = IF(recipient_profile_id = ?, ?, recipient_flagged_flag),
  sender_flagged_flag = IF(sender_profile_id = ?, ?, sender_flagged_flag)
WHERE message_id = ?
  AND ( ( recipient_profile_id = ?
          AND recipient_flagged_flag != ? )
     OR ( sender_profile_id = ?
          AND sender_flagged_flag != ? ) )
LIMIT 1
ENDSQL
;

$sth = $DBH->prepare_cached($query);
my $rows = $sth->execute( $profile_id, $flagged_flag, $profile_id, $flagged_flag,
                          $message_id,
                          $profile_id, $flagged_flag, $profile_id, $flagged_flag );
if ($rows eq '0E0') {
  
  # If things failed, try to work out why and send back a success
  # in the case of them trying to set something that was already set
  # (as the outcome they wanted has been (was already) achieved! =)
  $query = <<ENDSQL
SELECT message_id, recipient_profile_id, recipient_flagged_flag
                   sender_profile_id, sender_flagged_flag
FROM `user~profile~message`
WHERE message_id = ?
LIMIT 1
ENDSQL
;
  $sth = $DBH->prepare_cached($query);
  $sth->execute($message_id);
  my ($real_message_id,
      $recipient_profile_id,
      $recipient_flagged_flag,
      $sender_profile_id,
      $sender_flagged_flag) = $sth->fetchrow_array();
  if ($recipient_profile_id != $profile_id &&
      $sender_profile_id != $profile_id) {
    warn "profile $profile_id tried to mark message $message_id "
       . "flagged flag to $flagged_flag when message belongs to "
       . "recipient $recipient_profile_id and sender $sender_profile_id";
    print "Status: 404\n\n";
  } elsif ($recipient_profile_id == $profile_id && $recipient_flagged_flag == $flagged_flag) {
    warn "profile $profile_id tried to mark message $message_id "
       . "flagged flag to $flagged_flag when flag was already set to $recipient_flagged_flag";
    print "Status: 200\n\n"; # Say it worked because the desired outcome is true!
  } elsif ($sender_profile_id == $profile_id && $sender_flagged_flag == $flagged_flag) {
    warn "profile $profile_id tried to mark message $message_id "
       . "flagged flag to $flagged_flag when flag was already set to $sender_flagged_flag";
    print "Status: 200\n\n"; # Say it worked because the desired outcome is true!
  } elsif (!$real_message_id) {
    warn "profile $profile_id tried to mark message $message_id "
       . "flagged flag to $flagged_flag but this message id does not exist!";
    print "Status: 404\n\n";
  } else {
    warn "profile $profile_id tried to mark message $message_id "
       . "flagged flag to $flagged_flag but nothing was updated (unkown reason!)";
    print "Status: 404\n\n";
  }
  
} else {
  
  print "Status: 200\n\n";
  
}
$sth->finish;
