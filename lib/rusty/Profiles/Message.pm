package rusty::Profiles::Message;

use strict;

use lib "../..";

use warnings qw( all );

no warnings qw( uninitialized );




# Used for users manually sending messages - saves massage as draft
# before doing all checks.  If checks fail for any reason, the message
# will remain as draft and the final send stage would not fire, instead
# the user would be sent back to the draft to correct their changes.
sub saveDraftMessage(@) {
  
  my $self = shift;
  
  my (%params) = @_;
  
  my $dbh = $self->DBH;
  
  my ($query, $sth);
  
  # If we are re-saving a draft, update the existing message.
  # I know it's not being sent, but this 'sent_date' field
  # doubles up as 'saved time' if the 'is_draft' field is set
  if ($params{message_id}) {
    
    $query = <<ENDSQL
UPDATE `user~profile~message`
SET subject = ?,
    body = ?,
    sent_date = NOW()
WHERE message_id = ?
LIMIT 1
ENDSQL
  ;
    $sth = $dbh->prepare_cached($query);
    my $rows = $sth->execute( $params{subject},
                              $params{body},
                              $params{message_id} );
    $sth->finish;
    
    return $params{message_id} unless $rows eq '0E0';
    
  }
  
  # If this is a new save to drafts, save our new message..
  # And if the re-save failed above (almost certainly because
  # the message_id of the so-called 'existing' draft was
  # invalid, then save a new copy.
  $query = <<ENDSQL
INSERT DELAYED INTO `user~profile~message`
       (sender_profile_id, draft_recipient_profile_name,
        is_draft, subject, body, reply_id, forward_id,
        sender_read_flag, sent_date)
  VALUES (?, ?, 1, ?, ?, ?, ?, 0, NOW())
ENDSQL
  ;
  $sth = $dbh->prepare_cached($query);
  $sth->execute( $params{from_id},
                 $params{to_name},
                 $params{subject},
                 $params{body},
                 $params{reply_id},
                 $params{forward_id} );
  $sth->finish;
  
  my $message_id = $dbh->{mysql_insertid};
  
  return $message_id ? $message_id : 0;
}




# Used for users manually sending messages - does the final send once
# message has been saved as draft and all checks done.  If checks had
# failed for any reason, the message would remain as draft and this
# send stage would not fire until all checks were passed.
sub sendSavedMessage(@) {
  
  my $self = shift;
  
  my %msg_info = @_;
  
  my $dbh = $self->DBH;
  
  # Set statuses to sent and grab sender's current main photo id
  # so historical message archives will show user's main photo at
  # the time of sending, rather than just showing the current photo..
  my $query = <<ENDSQL
UPDATE `user~profile~message` upm
LEFT JOIN `user~profile` up_sender ON up_sender.profile_id = upm.sender_profile_id
LEFT JOIN `user~profile` up_recipient ON up_recipient.profile_id = upm.recipient_profile_id
LEFT JOIN `user~profile~message` upm_reply ON upm_reply.message_id = upm.reply_id
LEFT JOIN `user~profile~message` upm_forward ON upm_forward.message_id = upm.forward_id
SET upm.is_draft = 0,
    upm.sent_date = NOW(),
    upm.draft_recipient_profile_name = NULL,
    upm.recipient_profile_id = ?,
    upm.sender_main_photo_id = up_sender.main_photo_id,
    upm.recipient_main_photo_id = up_recipient.main_photo_id
WHERE upm.message_id = ?
AND upm.is_draft = 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute( $msg_info{profile_id},
                            $msg_info{saved_message_id} );
  $sth->finish;
  
  # If this didn't work, return with error status
  return 0 if $rows eq '0E0';
  
  # Set reply/forward flag on whatever we might have been forwarding/replying to.
  $query = <<ENDSQL
UPDATE `user~profile~message` upm_to_update
LEFT JOIN `user~profile~message` upm_reply
       ON upm_reply.reply_id = upm_to_update.message_id
LEFT JOIN `user~profile~message` upm_recipient_forward
       ON upm_recipient_forward.forward_id = upm_to_update.message_id
      AND upm_recipient_forward.sender_profile_id = upm_to_update.recipient_profile_id
LEFT JOIN `user~profile~message` upm_sender_forward
       ON upm_sender_forward.forward_id = upm_to_update.message_id
      AND upm_sender_forward.sender_profile_id = upm_to_update.sender_profile_id
SET upm_to_update.recipient_replied_flag = IF(ISNULL(upm_reply.message_id),
                                                     upm_to_update.recipient_replied_flag, 1),
    upm_to_update.recipient_forwarded_flag = IF(ISNULL(upm_recipient_forward.message_id),
                                                       upm_to_update.recipient_forwarded_flag, 1),
    upm_to_update.sender_forwarded_flag = IF(ISNULL(upm_sender_forward.message_id),
                                                    upm_to_update.sender_forwarded_flag, 1)
WHERE upm_reply.message_id = ?
   OR upm_recipient_forward.message_id = ?
   OR upm_sender_forward.message_id = ?
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute( $msg_info{saved_message_id},
                 $msg_info{saved_message_id},
                 $msg_info{saved_message_id} );
  $sth->finish;
  
  # Update unread message count for recipient
  $query = <<ENDSQL
UPDATE `user~profile` SET
unread_message_count = unread_message_count + 1
WHERE profile_id = ?
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute( $msg_info{profile_id} );
  $sth->finish;
  
  return 1;
}



# Used internally to send messages.  No intermediary stage so
# params will have to be correct or funny things will happen! :)
# There is no such thing as draft here so if it dies, the message
# will not be stored anywhere in the db and may be lost forever!
sub sendMessage(@) {
  
  my $self = shift;
  
  my (%params) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
INSERT DELAYED INTO `user~profile~message`
       (is_draft, sent_date, sender_profile_id, recipient_profile_id,
       subject, body)
VALUES (0, NOW(), ?, ?, ?, ?)
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
  
  $query = <<ENDSQL
UPDATE `user~profile~message` upm
LEFT JOIN `user~profile` up_sender ON up_sender.profile_id = upm.sender_profile_id
LEFT JOIN `user~profile` up_recipient ON up_recipient.profile_id = upm.recipient_profile_id
SET
upm.sender_main_photo_id = up_sender.main_photo_id,
upm.recipient_main_photo_id = up_recipient.main_photo_id,
ENDSQL
;
  $query .=  (defined($params{recipient_hidden_from}) ? "upm.recipient_hidden_from = ?,\n" : "")
           . (defined($params{sender_hidden_from}) ? "upm.sender_hidden_from = ?,\n" : "")
           . (defined($params{reply_id}) ? "upm.reply_id = ?,\n" : "")
           . (defined($params{flag}) ? "upm.flag = ?,\n" : "")
           . "WHERE upm.message_id = ?\n";
  my @params;
  push @params, $params{recipient_hidden_from} if defined($params{recipient_hidden_from});
  push @params, $params{sender_hidden_from} if defined($params{sender_hidden_from});
  push @params, $params{reply_id} if defined($params{reply_id});
  push @params, $params{flag} if defined($params{flag});
  push @params, $message_id;
  
  # Fix the last '?,' - if no '?,' was found then don't try to execute!
  # But now we are doing the main photo setting anyway, execute whatever.
  #if ($query =~ s/(.+)\?\,/$1?/s) {
  $query =~ s/(.+)\?\,/$1?/s; 
  
  $sth = $dbh->prepare_cached($query);
  $sth->execute( @params );
  $sth->finish;
  
  # Set reply/forward flag on whatever we might have been forwarding/replying to.
  $query = <<ENDSQL
UPDATE `user~profile~message` upm_to_update
LEFT JOIN `user~profile~message` upm_reply
       ON upm_reply.reply_id = upm_to_update.message_id
LEFT JOIN `user~profile~message` upm_recipient_forward
       ON upm_recipient_forward.forward_id = upm_to_update.message_id
      AND upm_recipient_forward.sender_profile_id = upm_to_update.recipient_profile_id
LEFT JOIN `user~profile~message` upm_sender_forward
       ON upm_sender_forward.forward_id = upm_to_update.message_id
      AND upm_sender_forward.sender_profile_id = upm_to_update.sender_profile_id
SET upm_to_update.recipient_replied_flag = IF(ISNULL(upm_reply.message_id),
                                                     upm_to_update.recipient_replied_flag, 1),
    upm_to_update.recipient_forwarded_flag = IF(ISNULL(upm_recipient_forward.message_id),
                                                       upm_to_update.recipient_forwarded_flag, 1),
    upm_to_update.sender_forwarded_flag = IF(ISNULL(upm_sender_forward.message_id),
                                                    upm_to_update.sender_forwarded_flag, 1)
WHERE upm_reply.message_id = ?
   OR upm_recipient_forward.message_id = ?
   OR upm_sender_forward.message_id = ?
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute( $message_id, $message_id, $message_id );
  $sth->finish;
  
  # Update unread message count for recipient
  $query = <<ENDSQL
UPDATE `user~profile` SET
unread_message_count = unread_message_count + 1
WHERE profile_id = ?
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute( $params{to} );
  $sth->finish;
  
  return $message_id;
}




# Simply gets new messages from the inbox of a given profile_id
# (invented to work with assistant and do things quickly!)
sub getNewMessagesCount($$) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $dbh = $self->DBH;
  
  # Would be lovely to use SQL_CACHE here but we
  # update this table whenever any message is sent
  # (and that msg could be to us) so can't cache. :(
#  my $query = <<ENDSQL
#SELECT COUNT(*)
#FROM `user~profile~message`
#WHERE recipient_profile_id = ?
#  AND recipient_deleted_date IS NULL
#  AND recipient_hidden_from = 0
#  AND is_draft = 0
#  AND read_date IS NULL
#GROUP BY recipient_profile_id
#ENDSQL
#;
  # Now we can cache! :)
  my $query = <<ENDSQL
SELECT SQL_CACHE unread_message_count
FROM `user~profile`
WHERE profile_id = ?
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my ($num_new_messages) = $sth->fetchrow_array;
  $sth->finish;
  
  return int($num_new_messages);
}




sub getMessagesSummary($$$) {
  
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
  AND recipient_hidden_from = 0
  AND is_draft = 0
GROUP BY recipient_profile_id
ENDSQL
;
  } elsif ($tray eq 'sent') {
    $query .= <<ENDSQL
WHERE sender_profile_id = ?
  AND sender_deleted_date IS NULL
  AND sender_hidden_from = 0
  AND is_draft = 0
GROUP BY sender_profile_id
ENDSQL
;
  } elsif ($tray eq 'drafts') {
    $query .= <<ENDSQL
WHERE sender_profile_id = ?
  AND sender_deleted_date IS NULL
  AND sender_hidden_from = 0
  AND is_draft = 1
GROUP BY sender_profile_id
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




sub getAllMessagesSummary($$) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $dbh = $self->DBH;
  
  # Let's try to get all folders at once (In every case so far, we've wanted to get
  # all info and in this case it's almost certainly faster to do it in one fell
  # swoop than 3 queries (untested theory).
  my $query = <<ENDSQL
SELECT IF(recipient_profile_id = ?, 'inbox',
          IF(sender_profile_id = ?
             AND is_draft = 0, 'sent',
             IF(sender_profile_id = ?
                AND is_draft = 1, 'drafts',
                NULL
             )
          )
       ) AS tray,
       COUNT(read_date) AS read_count,
       SUM(recipient_read_flag) AS read_flag_count,
       COUNT(*) AS total_count
FROM `user~profile~message`
WHERE (recipient_profile_id = ?
       AND recipient_deleted_date IS NULL
       AND recipient_hidden_from = 0
       AND is_draft = 0)
   OR (sender_profile_id = ?
       AND sender_deleted_date IS NULL
       AND sender_hidden_from = 0)
GROUP BY tray
HAVING tray IS NOT NULL
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $profile_id, $profile_id, $profile_id, $profile_id);
  
  my $traycount = { 'inbox'  => { 'read' => 0, 'total' => 0, 'unread' => 0, 'flagged_as_unread' => 0 },
                    'sent'   => { 'read' => 0, 'total' => 0, 'unread' => 0, 'flagged_as_unread' => 0 },
                    'drafts' => { 'read' => 0, 'total' => 0, 'unread' => 0, 'flagged_as_unread' => 0 }
                  };
  while (my $messages = $sth->fetchrow_hashref) {
    $traycount->{$messages->{tray}} = { 'read' => $messages->{read_count},
                                        'total' => $messages->{total_count},
                                        'unread' => $messages->{total_count} - $messages->{read_count},
                                        'flagged_as_unread' => $messages->{total_count} - $messages->{read_flag_count},
                                      };
  }
  $sth->finish;
  
  # Update unread message count
  $query = <<ENDSQL
UPDATE `user~profile` SET
unread_message_count = ?
WHERE profile_id = ?
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute( $traycount->{'inbox'}->{unread}, $profile_id );
  $sth->finish;
  
  return $traycount;
}




sub setMessageViewPrefs(@) {
  
  my $self = shift;
  
  #my ($profile_id, $tray) = splice(0,2,@_);
  my %params = @_;
  return -1 unless $params{profile_id} && $params{tray};
  return -2 unless defined($params{offset}) || $params{limit} ||
                   $params{order} || $params{suborder};
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
INSERT INTO `user~profile~messageviewprefs`
  (profile_id, tray, offset, `limit`, `order`, suborder)
VALUES
  (?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
  offset = IF(ISNULL(?), offset, ?),
  `limit` = IF(ISNULL(?), `limit`, ?),
  `order` = IF(ISNULL(?), `order`, ?),
  suborder = IF(ISNULL(?), suborder, ?)
ENDSQL
;
  
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute( $params{profile_id}, $params{tray}, ($params{offset} || 0), 
                            ($params{limit} || 10), $params{order}, $params{suborder},
                            $params{offset}, $params{offset},
                            $params{limit}, $params{limit},
                            $params{order}, $params{order},
                            $params{order}, $params{suborder} );
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : $rows);
}




sub getMessageViewPrefs($$$) {
  
  my $self = shift;
  
  my ($profile_id, $tray) = @_;
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT offset, `limit`, `order`, suborder, result_cache
FROM `user~profile~messageviewprefs`
WHERE profile_id = ?
  AND tray = ?
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $tray);
  my $msgviewprefs = $sth->fetchrow_hashref;
  $msgviewprefs ||= { offset => 0, limit => 10 };
  $sth->finish;
  return $msgviewprefs;
}




sub createMessageListCache($$$$$$$) {
  
  my $self = shift;
  
  my ($profile_id, $tray, $order, $order2) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT upm.message_id
FROM `user~profile~message` upm
ENDSQL
;
  if ($tray eq 'inbox') {
    $query .= <<ENDSQL
LEFT JOIN `user~profile` up ON up.profile_id = upm.sender_profile_id
WHERE upm.recipient_profile_id = ?
  AND upm.recipient_deleted_date IS NULL
  AND upm.recipient_hidden_from = 0
  AND upm.is_draft = 0
ENDSQL
;
  } elsif ($tray eq 'sent') {
    $query .= <<ENDSQL
LEFT JOIN `user~profile` up ON up.profile_id = upm.recipient_profile_id
WHERE upm.sender_profile_id = ?
  AND upm.sender_deleted_date IS NULL
  AND upm.sender_hidden_from = 0
  AND upm.is_draft = 0
ENDSQL
;
  } elsif ($tray eq 'drafts') {
    $query .= <<ENDSQL
LEFT JOIN `user~profile` up ON up.profile_id = upm.recipient_profile_id
WHERE upm.sender_profile_id = ?
  AND upm.sender_deleted_date IS NULL
  AND upm.sender_hidden_from = 0
  AND upm.is_draft = 1
ENDSQL
;
  }
  
  # If ordering, make sure we have a sub-order (default or specified)..
  my $order_by_order2;
  if ($order) {
    my $reverse_order = ($order2 =~ s/^__//o ? 1 : 0);
    $order2 = 'sent_date' unless $order2 =~ /^(?:sent_date|profile_name|subject)$/o;
    $order_by_order2 = ($reverse_order ?
                         ($order2 eq 'sent_date' ? 'ASC' : 'DESC') :
                         ($order2 eq 'sent_date' ? 'DESC' : 'ASC'));
    $order2 = "upm.$order2" if $order2 =~ /^(?:sent_date|subject)$/o;
    $order2 = "up.$order2" if $order2 =~ /^profile_name$/o;
  }
  
  # Set up default ordering unless we already have ordering specified
  my $reverse_order = ($order =~ s/^__//o ? 1 : 0);
  $order = 'sent_date' unless $order =~ /^(?:sent_date|profile_name|subject)$/o;
  my $order_by_order = ($reverse_order ?
                        ($order eq 'sent_date' ? 'ASC' : 'DESC') :
                        ($order eq 'sent_date' ? 'DESC' : 'ASC'));
  $order = "upm.$order" if $order =~ /^(?:sent_date|subject)$/o;
  $order2 = "up.$order" if $order =~ /^profile_name$/o;
  
  $query .= "ORDER BY $order $order_by_order"
          . ($order2 ? ", $order2 $order_by_order2" : "");
  
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my @msg_ids;
  while (my ($msg_id) = $sth->fetchrow_array) {
    push @msg_ids, $msg_id;
  }
  $sth->finish;
  
  $query = <<ENDSQL
INSERT INTO `user~profile~messageviewprefs`
  (profile_id, tray, result_cache_date, result_cache_count, result_cache)
VALUES
  (?, ?, NOW(), ?, ?)
ON DUPLICATE KEY UPDATE
  result_cache_date = NOW(),
  result_cache_count = ?,
  result_cache = ?
ENDSQL
  ;
  $sth = $dbh->prepare_cached($query);
  my $msgstring = join(',', @msg_ids);
  $sth->execute($profile_id, $tray, scalar(@msg_ids), $msgstring, scalar(@msg_ids), $msgstring);
  $sth->finish;
}




sub getMessagesFromCache($$$$$) {
  
  my $self = shift;
  
  my ($profile_id, $tray, $offset, $limit) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT result_cache_date, result_cache_count, result_cache
FROM `user~profile~messageviewprefs`
WHERE profile_id = ?
  AND tray = ?
LIMIT 1
ENDSQL
  ;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $tray);
  my $msg_results_cache = $sth->fetchrow_hashref;
  $sth->finish;
  
  if ($msg_results_cache->{result_cache_count} == 0) {
    return { messages => undef,
             count => $msg_results_cache->{result_cache_count},
             cache_date => $msg_results_cache->{result_cache_date} };
  }
  
  my @msg_ids = split /,/, $msg_results_cache->{result_cache};  
  my @desired_msg_ids = splice(@msg_ids, $offset, $limit);
  my $desired_msg_ids_string = join ',', @desired_msg_ids;
  
  $query = <<ENDSQL
SELECT upm.message_id,
       DATE_FORMAT(upm.sent_date, '%a %d/%m/%y %H:%i') AS sent_date,
       DATE_FORMAT(upm.read_date, '%a %d/%m/%y %H:%i') AS read_date,
       upm.sender_profile_id, upm.sender_main_photo_id,
       upm.recipient_profile_id, upm.recipient_main_photo_id,
       upm.draft_recipient_profile_name,
       upm.recipient_read_flag, upm.sender_read_flag,
       upm.recipient_flagged_flag, upm.sender_flagged_flag,
       upm.recipient_replied_flag, upm.flag, upm.suspected_spam_date,
       upm.recipient_forwarded_flag, upm.sender_forwarded_flag,
       up.profile_name,
       upm.subject, upm.body
FROM `user~profile~message` upm
ENDSQL
;

  if ($tray eq 'inbox') {
    $query .= <<ENDSQL
LEFT JOIN `user~profile` up ON up.profile_id = upm.sender_profile_id
ENDSQL
  ;
  } elsif ($tray eq 'sent' ||
           $tray eq 'drafts') {
    $query .= <<ENDSQL
LEFT JOIN `user~profile` up ON up.profile_id = upm.recipient_profile_id
ENDSQL
  ;
  }
  
  # If only one ID, no need to do an 'IN' and can cache query..
  if (@desired_msg_ids == 1) {
    $query .= "WHERE upm.message_id = ?\n";
    $sth = $dbh->prepare_cached($query);
    $sth->execute($desired_msg_ids[0]);
  } else {
    $query .= "WHERE upm.message_id IN ( $desired_msg_ids_string )\n";
     # Not prepare_cached as query is always changing!
    $sth = $dbh->prepare($query);
    $sth->execute();
  }
  my %msg_details;
  while (my $msg_detail = $sth->fetchrow_hashref) {
    $msg_details{$msg_detail->{message_id}} = $msg_detail;
  }
  $sth->finish;
  
  # Get them back in desired order with detail added!
  my @msgs = ();
  foreach my $desired_msg_id (@desired_msg_ids) {
    push @msgs, $msg_details{$desired_msg_id};
  }
  return { messages => (@msgs ? \@msgs : undef),
           count => $msg_results_cache->{result_cache_count},
           cache_date => $msg_results_cache->{result_cache_date} };
}




sub getPrevAndNextMessages($$$$) {

  my $self = shift;
  
  my ($profile_id, $tray, $message_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT result_cache, result_cache_count, result_cache_date
FROM `user~profile~messageviewprefs`
WHERE profile_id = ?
  AND tray = ?
LIMIT 1
ENDSQL
  ;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $tray);
  my $msg_results_cache = $sth->fetchrow_hashref;
  $sth->finish;
  if (my $msg_ids_string = $msg_results_cache->{result_cache}) {
    
    my ($prev, $next) = (undef, undef);
    
    # This regex will try to find our message id and capture the
    # previous and/or next message ids in the message list cached.
    if ($msg_ids_string =~ /(?:^|(\d+),)$message_id(?:$|,(\d+))/) {
      $prev = $1; $next = $2;
    }
    
    return { prev => $prev,
             next => $next,
             count => $msg_results_cache->{result_cache_count},
             cache_date => $msg_results_cache->{result_cache_date} };
  } else {
    
    return undef;
  }
}




sub getMessageDetail($) {
  
  my $self = shift;
  
  my ($message_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT upm.message_id, is_draft,
       DATE_FORMAT(upm.sent_date, '%a %d/%m/%y %H:%i') AS sent_date,
       DATE_FORMAT(upm.read_date, '%a %d/%m/%y %H:%i') AS read_date,
       upm.sender_profile_id, upm.sender_main_photo_id,
       upm.recipient_profile_id, upm.recipient_main_photo_id,
       upm.draft_recipient_profile_name,
       up_sender.profile_name AS sender_profile_name,
       up_recipient.profile_name AS recipient_profile_name,
       upm.subject, upm.body,
       upm.recipient_deleted_date, upm.sender_deleted_date,
       upm.sent_date, upm.read_date,
       upm.recipient_read_flag, upm.sender_read_flag,
       upm.recipient_flagged_flag, upm.sender_flagged_flag,
       upm.recipient_replied_flag, upm.flag, upm.suspected_spam_date,
       upm.reply_id, upm.forward_id
FROM `user~profile~message` upm
LEFT JOIN `user~profile` up_sender ON up_sender.profile_id = upm.sender_profile_id
LEFT JOIN `user~profile` up_recipient ON up_recipient.profile_id = upm.recipient_profile_id
WHERE upm.message_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($message_id);
  my $msg = $sth->fetchrow_hashref;
  $sth->finish;
  
  return $msg;
  
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




sub deleteMessages(@) {
  
  my $self = shift;
  
  my (%params) = @_;
  
  my $dbh = $self->DBH;
  
  return unless @{$params{message_ids}};
  
  my $message_ids_string = join ', ', @{$params{message_ids}};
  
  my $query;
  my @query_params;
  if ($params{recipient_profile_id}) {
    
    $query = <<ENDSQL
UPDATE `user~profile~message`
SET recipient_deleted_date = NOW()
WHERE message_id IN ( $message_ids_string )
  AND recipient_profile_id = ?
  AND recipient_deleted_date IS NULL
  AND recipient_hidden_from = 0
ENDSQL
;
    if ($params{user_action}) {
      $query .= "  AND !(flag = 'LINKEDFRIEND' && recipient_read_flag != 1)\n";
    }
    push @query_params, $params{recipient_profile_id};
    
  } elsif ($params{sender_profile_id}) {
    
    $query = <<ENDSQL
UPDATE `user~profile~message`
SET sender_deleted_date = NOW()
WHERE message_id IN ( $message_ids_string )
  AND sender_profile_id = ?
  AND sender_deleted_date IS NULL
  AND sender_hidden_from = 0
ENDSQL
;
    push @query_params, $params{sender_profile_id};
    
  }
  
  my $sth;
  # If query has only one id in the 'IN', change the query and add param
  if ($query =~ s/message_id IN \( \d+ \)/message_id = \?/o) {
    unshift @query_params, ${$params{message_ids}}[0];
    $sth = $dbh->prepare_cached($query);
  } else {
    # Not prepare_cached as query is always changing!
    $sth = $dbh->prepare($query);
  }
  
  # Now we're do an WHERE message_id IN (1, 2, 3..).
  # This syntax is faster but could go bump more easily..
  # Previously we were looping over the message_ids
  # and adding up the count of successful updates..
  #my $rows = 0;
  #foreach my $message_id (@{$params{message_ids}}) {
  #  my $these_rows = $sth->execute( $message_id, @params );
  #  $rows += $these_rows eq '0E0' ? 0 : 1;
  #}
  my $rows = $sth->execute(@query_params);
  $sth->finish;
  
  #return $rows;
  return ($rows eq '0E0' ? 0 : $rows);
}




sub markMessageRead($) {

  my $self = shift;

  my $message_id = shift;

  my $dbh = $self->DBH;

  my $query = <<ENDSQL
UPDATE `user~profile~message`
SET read_date = NOW()
WHERE message_id = ?
  AND read_date IS NULL
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute($message_id);
  $sth->finish;
  
  # If we managed to really read it,
  if ($rows ne '0E0') {
    
    # Update unread message count for recipient
    $query = <<ENDSQL
UPDATE `user~profile` up
INNER JOIN `user~profile~message` upm ON upm.recipient_profile_id = up.profile_id
SET up.unread_message_count = up.unread_message_count - 1
WHERE upm.message_id = ?
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute( $message_id );
  }
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
}




sub markMessageReadAndFlag($) {

  my $self = shift;

  my $message_id = shift;

  my $dbh = $self->DBH;

  my $query = <<ENDSQL
UPDATE `user~profile~message`
SET read_date = NOW(),
    recipient_read_flag = 1
WHERE message_id = ?
  AND read_date IS NULL
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute($message_id);
  $sth->finish;
  
  # If we managed to really read it,
  if ($rows ne '0E0') {
    
    # Update unread message count for recipient
    $query = <<ENDSQL
UPDATE `user~profile` up
INNER JOIN `user~profile~message` upm ON upm.recipient_profile_id = up.profile_id
SET up.unread_message_count = up.unread_message_count - 1
WHERE upm.message_id = ?
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute( $message_id );
    $sth->finish;
  }
  
  return ($rows eq '0E0' ? 0 : 1);
}




sub markMessageReadFlags($) {
  
  my $self = shift;
  
  my (%params) = @_;
  
  my $dbh = $self->DBH;
  
  return unless @{$params{message_ids}};
  
  my $message_ids_string = join ', ', @{$params{message_ids}};
  
  my $query = <<ENDSQL
UPDATE `user~profile~message`
SET recipient_read_flag = 1
WHERE message_id IN ( $message_ids_string )
  AND recipient_profile_id = ?
  AND recipient_read_flag != 1
  AND read_date IS NOT NULL
ENDSQL
;
  if ($params{user_action}) {
    $query .= "  AND flag != 'LINKEDFRIEND'\n";
  }
  
  my ($sth, $rows);
  # If query has only one id in the 'IN', change the query and add param
  if ($query =~ s/message_id IN \( \d+ \)/message_id = \?/o) {
    $sth = $dbh->prepare_cached($query);
    $rows = $sth->execute(${$params{message_ids}}[0], $params{recipient_profile_id});
  } else {
    # Not prepare_cached as query is always changing!
    $sth = $dbh->prepare($query);
    $rows = $sth->execute($params{recipient_profile_id});
  }
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : $rows);
}




sub markMessageUnreadFlags($) {
  
  my $self = shift;
  
  my (%params) = @_;
  
  my $dbh = $self->DBH;
  
  return unless @{$params{message_ids}};
  
  my $message_ids_string = join ', ', @{$params{message_ids}};
  
  my $query = <<ENDSQL
UPDATE `user~profile~message`
SET recipient_read_flag = 0
WHERE message_id IN ( $message_ids_string )
  AND recipient_profile_id = ?
  AND recipient_read_flag != 0
ENDSQL
;
  if ($params{user_action}) {
    $query .= "  AND flag != 'LINKEDFRIEND'\n";
  }
  
  my ($sth, $rows);
  # If query has only one id in the 'IN', change the query and add param
  if ($query =~ s/message_id IN \( \d+ \)/message_id = \?/o) {
    $sth = $dbh->prepare_cached($query);
    $rows = $sth->execute(${$params{message_ids}}[0], $params{recipient_profile_id});
  } else {
    # Not prepare_cached as query is always changing!
    $sth = $dbh->prepare($query);
    $rows = $sth->execute($params{recipient_profile_id});
  }
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : $rows);
}




sub submitMessageAsSpam($) {

  my $self = shift;

  my $message_id = shift;

  my $dbh = $self->DBH;

  my $query = <<ENDSQL
UPDATE `user~profile~message`
SET suspected_spam_date = NOW()
WHERE message_id = ?
  AND suspected_spam_date IS NULL
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  my $rows = $sth->execute($message_id);
  $sth->finish;
  
  return ($rows eq '0E0' ? 0 : 1);
}




1;
