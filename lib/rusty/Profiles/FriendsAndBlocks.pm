package rusty::Profiles::FriendsAndBlocks;

use strict;

#use lib "../..";

use warnings qw( all );

no warnings qw( uninitialized );

#use CarpeDiem;

#use rusty;

#our @ISA = qw( rusty::Profiles );

sub getAllFriends($) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT upf.friend_link_id,
       upf.requestee_profile_id AS profile_id,
       u.profile_name,
       up.main_photo_id,
       upf.status,
       DATE_FORMAT(upf.requested_date, '%d/%m/%y %H:%i') AS requested_date,
       DATE_FORMAT(upf.read_date, '%d/%m/%y %H:%i') AS read_date,
       DATE_FORMAT(upf.decided_date, '%d/%m/%y %H:%i') AS decided_date
FROM `user~profile~friend_link` upf
INNER JOIN `user~profile` up ON upf.requestee_profile_id = up.profile_id
INNER JOIN `user` u ON u.user_id = up.user_id
WHERE upf.requester_profile_id = ?
  AND upf.deleted_date IS NULL
  AND upf.status != 'rejected'
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my @friends = ();
  while (my $friend_info = $sth->fetchrow_hashref) {
    push @friends, $friend_info;
  }
  $sth->finish;
  
  return @friends ? \@friends : undef;
}


sub getFriendLink($$) {
  
  my $self = shift;
  
  my ($friend_link_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT friend_link_id, requester_profile_id, requestee_profile_id, status,
       DATE_FORMAT(requested_date, '%d/%m/%y %H:%i') AS requested_date,
       DATE_FORMAT(read_date, '%d/%m/%y %H:%i') AS read_date,
       DATE_FORMAT(decided_date, '%d/%m/%y %H:%i') AS decided_date,
       DATE_FORMAT(deleted_date, '%d/%m/%y %H:%i') AS deleted_date
FROM `user~profile~friend_link`
WHERE friend_link_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($friend_link_id);
  my $friend_link = $sth->fetchrow_hashref;
  $sth->finish;
  
  return $friend_link;
}


sub findFriendLink($$) {
  
  my $self = shift;
  
  my ($requester_profile_id, $requestee_profile_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT friend_link_id, requester_profile_id, requestee_profile_id, status,
       DATE_FORMAT(requested_date, '%d/%m/%y %H:%i') AS requested_date,
       DATE_FORMAT(read_date, '%d/%m/%y %H:%i') AS read_date,
       DATE_FORMAT(decided_date, '%d/%m/%y %H:%i') AS decided_date,
       DATE_FORMAT(deleted_date, '%d/%m/%y %H:%i') AS deleted_date
FROM `user~profile~friend_link`
WHERE requester_profile_id = ?
  AND requestee_profile_id = ?
  AND deleted_date IS NULL
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($requester_profile_id, $requestee_profile_id);
  my $friend_link = $sth->fetchrow_hashref;
  $sth->finish;
  
  return $friend_link;
}


sub findPendingOrExistingFriendLink($$) {
  
  my $self = shift;
  
  my ($profile_id, $friend_profile_id) = @_;
  
  my $dbh = $self->DBH;
  
  # Look for any current link from us to them OR any link in to us
  # from them that is unanswered (read or unread, but not decided)
  my $query = <<ENDSQL
SELECT friend_link_id, requester_profile_id, requestee_profile_id, status,
       DATE_FORMAT(requested_date, '%d/%m/%y %H:%i') AS requested_date,
       DATE_FORMAT(read_date, '%d/%m/%y %H:%i') AS read_date,
       DATE_FORMAT(decided_date, '%d/%m/%y %H:%i') AS decided_date
FROM `user~profile~friend_link`
WHERE deleted_date IS NULL
  AND (
    (    requester_profile_id = ?
     AND requestee_profile_id = ?
     AND status != 'rejected' )
    OR (
         requester_profile_id = ?
     AND requestee_profile_id = ?
     AND status IN ('unread','read')
    )
  )
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $friend_profile_id,
                $friend_profile_id, $profile_id);
  my $friend_link = $sth->fetchrow_hashref;
  $sth->finish;
  
  return $friend_link;
}


sub requestFriendLink($$) {
  
  my $self = shift;
  
  my ($profile_id, $friend_profile_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
INSERT INTO `user~profile~friend_link`
       (requester_profile_id, requestee_profile_id, requested_date, status)
VALUES (?, ?, NOW(), 'unread')
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $friend_profile_id);
  $sth->finish;
  
  return $dbh->{mysql_insertid};
}


sub readFriendLink($) {
  
  my $self = shift;
  
  my $friend_link_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
UPDATE `user~profile~friend_link`
SET read_date = NOW()
WHERE friend_link_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute($friend_link_id);
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
}


sub acceptFriendLink($) {
  
  my $self = shift;
  
  my $friend_link_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
UPDATE `user~profile~friend_link`
SET status = 'accepted',
    decided_date = NOW()
WHERE friend_link_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute($friend_link_id);
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
}


sub addReciprocalFriendLink($$) {
  
  my $self = shift;
  
  my ($profile_id, $friend_profile_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
INSERT INTO `user~profile~friend_link`
       (requester_profile_id, requestee_profile_id, decided_date, status)
VALUES (?, ?, NOW(), 'reciprocal')
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $friend_profile_id);
  $sth->finish;
  
  return $dbh->{mysql_insertid};
}


sub rejectFriendLink($) {
  
  my $self = shift;
  
  my $friend_link_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
UPDATE `user~profile~friend_link`
SET status = 'rejected',
    decided_date = NOW()
WHERE friend_link_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute($friend_link_id);
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
}


sub deleteFriendLink($) {
  
  my $self = shift;
  
  my $friend_link_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
UPDATE `user~profile~friend_link`
SET deleted_date = NOW()
WHERE friend_link_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute($friend_link_id);
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
}


sub getAllFaves($) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT upf.fave_link_id, upf.fave_profile_id AS profile_id,
       u.profile_name, up.main_photo_id,
       DATE_FORMAT(upf.added_date, '%d/%m/%y %H:%i') AS added_date
FROM `user~profile~fave_link` upf
INNER JOIN `user~profile` up ON upf.fave_profile_id = up.profile_id
INNER JOIN `user` u ON u.user_id = up.user_id
WHERE upf.profile_id = ?
  AND upf.removed_date IS NULL
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my @faves = ();
  while (my $fave_info = $sth->fetchrow_hashref) {
    push @faves, $fave_info;
  }
  $sth->finish;
  
  return @faves ? \@faves : undef;
}


sub findExistingFaveLink($$) {
  
  my $self = shift;
  
  my ($profile_id, $fave_profile_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT fave_link_id, profile_id, fave_profile_id,
       DATE_FORMAT(added_date, '%d/%m/%y %H:%i') AS blocked_date
FROM `user~profile~fave_link`
WHERE (profile_id = ? AND fave_profile_id = ?)
  AND removed_date IS NULL
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $fave_profile_id);
  my $fave_link = $sth->fetchrow_hashref;
  $sth->finish;
  
  return $fave_link;
}


sub createFaveLink($$) {
  
  my $self = shift;
  
  my ($profile_id, $fave_profile_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
INSERT INTO `user~profile~fave_link`
       (profile_id, fave_profile_id, added_date)
VALUES (?, ?, NOW())
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $fave_profile_id);
  $sth->finish;
  
  return $dbh->{mysql_insertid};
}


sub deleteFaveLink($) {
  
  my $self = shift;
  
  my $fave_link_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
UPDATE `user~profile~fave_link`
SET removed_date = NOW()
WHERE fave_link_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute($fave_link_id);
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
}














sub getAllBlocks($) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT upb.block_link_id, upb.blockee_profile_id AS profile_id,
       u.profile_name, up.main_photo_id,
       DATE_FORMAT(upb.blocked_date, '%d/%m/%y %H:%i') AS blocked_date
FROM `user~profile~block_link` upb
INNER JOIN `user~profile` up ON upb.blockee_profile_id = up.profile_id
INNER JOIN `user` u ON u.user_id = up.user_id
WHERE upb.blocker_profile_id = ?
  AND upb.unblocked_date IS NULL
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my @blocks = ();
  while (my $block_info = $sth->fetchrow_hashref) {
    push @blocks, $block_info;
  }
  $sth->finish;
  
  return @blocks ? \@blocks : undef;
}


sub findBlockLink($$) {
  
  my $self = shift;
  
  my ($profile_id, $block_profile_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT block_link_id, blocker_profile_id, blockee_profile_id,
       DATE_FORMAT(blocked_date, '%d/%m/%y %H:%i') AS blocked_date
FROM `user~profile~block_link`
WHERE (blocker_profile_id = ? AND blockee_profile_id = ?)
  AND unblocked_date IS NULL
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $block_profile_id);
  my $block_link = $sth->fetchrow_hashref;
  $sth->finish;
  
  return $block_link;
}


sub addBlockLink($$) {
  
  my $self = shift;
  
  my ($profile_id, $block_profile_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
INSERT INTO `user~profile~block_link`
       (blocker_profile_id, blockee_profile_id, blocked_date)
VALUES (?, ?, NOW())
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $block_profile_id);
  $sth->finish;
  
  return $dbh->{mysql_insertid};
}


sub unblockBlockLink($) {
  
  my $self = shift;
  
  my $block_link_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
UPDATE `user~profile~block_link`
SET unblocked_date = NOW()
WHERE block_link_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute($block_link_id);
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
}


sub getProfileDisplayPrefs($) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT showfaves, showfriends
FROM `user~profile`
WHERE profile_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my $display_prefs = $sth->fetchrow_hashref;
  $sth->finish;
  
  return $display_prefs;
}


sub updateProfileDisplayPrefs($) {
  
  my $self = shift;
  
  my %updateparams = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
UPDATE `user~profile` SET
ENDSQL
;
  my @params = ();
  if (exists $updateparams{showfaves}) {
    $query .= " showfaves = ? ";
    push @params, $updateparams{showfaves};
  } elsif (exists $updateparams{showfriends}) {
    $query .= " showfriends = ? ";
    push @params, $updateparams{showfriends};
  }
  $query .= <<ENDSQL
WHERE profile_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute(@params, $updateparams{profile_id});
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
}



1;
