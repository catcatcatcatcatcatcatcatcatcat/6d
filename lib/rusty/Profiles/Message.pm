package rusty::Profiles::Message;

use strict;

#use lib "../..";

use warnings qw( all );

no warnings qw( uninitialized );

#use CarpeDiem;

#use rusty;

#our @ISA = qw( rusty::Profiles );

sub sendMessage(@) {
  
  my $self = shift;
  
  my (%params) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
INSERT INTO `user~profile~message`
       (sent_date, sender_profile_id, recipient_profile_id,
       subject, body)
VALUES (NOW(), ?, ?, ?, ?)
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute( $params{from},
                 $params{to},
                 $params{subject},
                 $params{body} );
  $sth->finish;
  
  my $message_id = $dbh->{mysql_insertid};
  return 0 unless $message_id;
  
  # Now add the extra info if any was given..
  
  $query = "UPDATE `user~profile~message` SET\n"
         . (defined($params{recipient_deleted}) ? "recipient_deleted = ?,\n" : "")
         . (defined($params{sender_deleted}) ? "sender_deleted = ?,\n" : "")
         . (defined($params{reply_id}) ? "reply_id = ?,\n" : "")
         . (defined($params{special}) ? "special = ?,\n" : "")
         . "WHERE message_id = ?\n"
         . "LIMIT 1\n";
  my @params;
  push @params, $params{recipient_deleted} if defined($params{recipient_deleted});
  push @params, $params{sender_deleted} if defined($params{sender_deleted});
  push @params, $params{reply_id} if defined($params{reply_id});
  push @params, $params{special} if defined($params{special});
  push @params, $message_id;
  
  # Fix the last '?,' - if no '?,' was found then don't try to execute!
  if ($query =~ s/(.+)\?\,/$1?/) {
    
    $sth = $dbh->prepare_cached($query);
    $sth->execute( @params );
    $sth->finish;
  }
  
  return $message_id;
  
}


sub deleteMessage(@) {
  
  my $self = shift;
  
  my (%params) = @_;
  
  my $dbh = $self->DBH;
  
  # Just mark the message as deleted!
  
  my $query = <<ENDSQL
UPDATE `user~profile~message` SET
deleted_date = NOW()
message_id = ?,
sender_profile_id = ?,
recipient_profile_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute( $params{message_id},
                            $params{sender_profile_id},
                            $params{recipient_profile_id} );
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
  
}


sub getMessagesSummary($$) {
  
  my $self = shift;
  
  my ($profile_id, $tray) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT COUNT(read_date) AS read, COUNT(*) AS total
FROM `user~profile~message`
ENDSQL
;
  if ($tray eq 'inbox') {
    $query .= <<ENDSQL
WHERE recipient_profile_id = ?
  AND recipient_deleted_date IS NULL
  AND sent_date IS NOT NULL
ENDSQL
;
  } elsif ($tray eq 'sent') {
    $query .= <<ENDSQL
WHERE sender_profile_id = ?
  AND sender_deleted_date IS NULL
  AND sent_date IS NOT NULL
ENDSQL
;
  } elsif ($tray eq 'drafts') {
    $query .= <<ENDSQL
WHERE sender_profile_id = ?
  AND sender_deleted_date IS NULL
  AND sent_date IS NULL
ENDSQL
;
  }
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my $messages = $sth->fetchrow_hashref;
  $sth->finish;
  
  $messages->{unread} = $messages->{total} - $messages->{read};
  
  return $messages;
}




sub getMessages($$$) {
  
  my $self = shift;
  
  my ($profile_id, $tray, $offset, $limit) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT message_id,
       DATE_FORMAT(sent_date, '%a %d/%m/%y %H:%i') AS sent_date,
       DATE_FORMAT(read_date, '%a %d/%m/%y %H:%i') AS read_date,
       sender_profile_id, recipient_profile_id, subject, body
FROM `user~profile~message`
ENDSQL
;
  if ($tray eq 'inbox') {
    $query .= <<ENDSQL
WHERE recipient_profile_id = ?
  AND recipient_deleted_date IS NULL
  AND sent_date IS NOT NULL
ENDSQL
;
  } elsif ($tray eq 'sent') {
    $query .= <<ENDSQL
WHERE sender_profile_id = ?
  AND sender_deleted_date IS NULL
  AND sent_date IS NOT NULL
ENDSQL
;
  } elsif ($tray eq 'drafts') {
    $query .= <<ENDSQL
WHERE sender_profile_id = ?
  AND sender_deleted_date IS NULL
  AND sent_date IS NULL
ENDSQL
;
  }
  
  $query .= <<ENDSQL
ORDER BY sent_date
LIMIT ?, ?
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $offset, $limit);
  my @msgs;
  while (my $msg = $sth->fetchrow_hashref) {
    push @msgs, $msg;
  }
  $sth->finish;
  
  return @msgs ? \@msgs : undef;
}




sub quoteMessage($) {
  
  my $self = shift;
  
  my $msg = shift;
  
  # Strip off trailing whitespace
  $msg =~ s/\s+$//o;
  
  # Same as PHP's wordwrap function
  # (wraps text to a set width on words -
  # here we break on hyphens or whitespace).
  $msg =~ s/(.{0,75})[\-\s+]/$1\n/og;
  
  $msg =~ s/\n/\n-- /og;
  
  $msg = "-- " . $msg;
  
  if (substr($msg, -3) == "-- ") {
    $msg = substr($msg, 0, -3);
  }
  
  return $msg;
  
}




sub markMessageRead($) {

  my $self = shift;

  my $message_id = shift;

  my $dbh = $self->DBH;

  my $query = <<ENDSQL
UPDATE `user~profile~message`
SET read_date = NOW()
WHERE message_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($message_id);
  $sth->finish;
  
}




1;
