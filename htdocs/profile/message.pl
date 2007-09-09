#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

use vars qw($rusty $query $sth);

$rusty = rusty::Profiles->new;


if (!$rusty->{core}->{'user_id'}) {
  require URI::Escape;
  print $rusty->CGI->redirect( -url => "/login.pl?ref="
                                     . URI::Escape::uri_escape($rusty->{core}->{'self_url'}) );
  $rusty->exit;
} elsif ($rusty->{core}->{profile_info}->{'deleted_date'}) {
  print $rusty->CGI->redirect( -url => "/profile/account.pl?deleted=1" );
  $rusty->exit;
}

if (!$rusty->{core}->{'profile_id'} && !$rusty->{params}->{prev_action}) {
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=summary&prev_action="
                                     . $rusty->{params}->{mode}
                                     . "&success=0&reason=noprofile" );
  $rusty->exit;
}

$rusty->{data}->{search_id} = $rusty->{params}->{search_id};

$_ = $rusty->{params}->{mode};
SWITCH:
{
  &summary, last SWITCH if /^summary$/o;
  &list, last SWITCH if /^list$/o;
  &list('inbox'), last SWITCH if /^inbox$/o;
  &list('sent'), last SWITCH if /^sent$/o;
  &list('drafts'), last SWITCH if /^drafts$/o;
  &read, last SWITCH if /^read$/o;
  &compose, last SWITCH if /^(?:compose|
                                reply|
                                forward|
                                editdraft)$/ox;
  &send, last SWITCH if /^send$/o;
  &processselected($_), last SWITCH if /^(?:delete|
                                            deleteselected|
                                            markasread|
                                            markselectedasread|
                                            markasunread|
                                            markselectedasunread)$/ox;
  &viewconvhist, last SWITCH if /^viewconvhist$/o;
  &respond, last SWITCH if /^respond$/o;
  &submitasspam, last SWITCH if /^submitasspam$/o;
  
  # Default behaviour: summary
  $rusty->{data}->{errors}->{mode} = "mode $_ is not defined" if $_;
  &summary;
}

$rusty->exit;




sub summary {
  
  $rusty->{ttml} = "profile/message/summary.ttml";
  
  #$rusty->{data}->{inbox_count} = $rusty->getMessagesSummary($rusty->{core}->{'profile_id'},'inbox');
  #$rusty->{data}->{sent_count} = $rusty->getMessagesSummary($rusty->{core}->{'profile_id'},'sent');
  #$rusty->{data}->{drafts_count} = $rusty->getMessagesSummary($rusty->{core}->{'profile_id'},'drafts');
  $rusty->{data}->{tray_count} = $rusty->getAllMessagesSummary($rusty->{core}->{'profile_id'});
  
  # Catch processing errors that redirect back to list..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  
  $rusty->process_template;
}




sub list($) {
  
  $rusty->{data}->{'tray'} = $rusty->{params}->{tray};
  $rusty->{data}->{'tray'} ||= $rusty->{params}->{mode} if $rusty->{params}->{mode} ne 'list';
  $rusty->{data}->{'tray'} ||= 'inbox';
  $rusty->{data}->{'mode'} = "list";
  
  $rusty->{ttml} = "profile/message/list.ttml";
  
  $rusty->{data}->{tray_count} = $rusty->getAllMessagesSummary($rusty->{core}->{'profile_id'});
  
  # Catch processing errors that redirect back to list..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  
  # Allow non-js users to select all using link rather than js..
  $rusty->{data}->{selectall} = $rusty->{params}->{selectall};
  
  if ($rusty->{params}->{'limit'} =~ /^\d+$/ &&
      $rusty->{params}->{'limit'} > 0 &&
      $rusty->{params}->{'limit'} <= 100) {
    
    $rusty->{data}->{'limit'} = $rusty->{params}->{'limit'};
  }
  
  if ($rusty->{params}->{'offset'} =~ /^\d+$/ &&
      $rusty->{params}->{'offset'} < $rusty->{data}->{tray_count}->{$rusty->{data}->{'tray'}}->{total}) {
    
    $rusty->{data}->{'offset'} = $rusty->{params}->{'offset'};
  }
  
  $rusty->{data}->{'order'} = $rusty->{params}->{'order'};
  $rusty->{data}->{'order2'} = $rusty->{params}->{'order2'};
  
  # If any viewing prefs are being updated, update the db!
  if (defined($rusty->{data}->{'offset'}) ||
      $rusty->{data}->{'limit'} ||
      $rusty->{data}->{'order'} ||
      $rusty->{data}->{'order2'}) {
    
    $rusty->setMessageViewPrefs( profile_id => $rusty->{core}->{'profile_id'},
                                 tray       => $rusty->{data}->{'tray'},
                                 offset     => $rusty->{data}->{'offset'},
                                 limit      => $rusty->{data}->{'limit'},
                                 order      => $rusty->{data}->{'order'},
                                 suborder   => $rusty->{data}->{'order2'} );
  }
  
  # Get all viewing prefs for this folder
  my $msgviewprefs = $rusty->getMessageViewPrefs( $rusty->{core}->{'profile_id'},
                                                  $rusty->{data}->{'tray'} );
  $rusty->{data}->{'offset'} = $msgviewprefs->{'offset'};
  $rusty->{data}->{'limit'} = $msgviewprefs->{'limit'};
  $rusty->{data}->{'order'} = $msgviewprefs->{'order'};
  $rusty->{data}->{'order2'} = $msgviewprefs->{'suborder'};
  
  
  # If we're only requesting a new limit or offset,
  # don't re-search, just get new section from the cache..
  # But if we're changing the listing order, create a new cache.
  # Also if no cache exists at all, make sure we create one!!
  if ( (!defined($rusty->{params}->{'offset'}) &&
        !$rusty->{params}->{'limit'})
      || !defined($msgviewprefs->{'result_cache'}) ) {
    
    # Create cache of messages given the viewing prefs (ordering)
    $rusty->createMessageListCache( $rusty->{core}->{'profile_id'},
                                    $rusty->{data}->{'tray'},
                                    $rusty->{data}->{'order'},
                                    $rusty->{data}->{'order2'} );
  }
  
  # Get all messages for this folder given the viewing prefs & offset/limit
  my $message_cache =
    $rusty->getMessagesFromCache( $rusty->{core}->{'profile_id'},
                                  $rusty->{data}->{'tray'},
                                  $rusty->{data}->{'offset'},
                                  $rusty->{data}->{'limit'} );
  
  $rusty->{data}->{messages} = $message_cache->{messages};
  $rusty->{data}->{message_cache_count} = $message_cache->{count};
  $rusty->{data}->{message_cache_date} = $message_cache->{cache_date};
  
  # The method below is deprecated in favour of above two!
  ## Get all messages for this folder given the viewing prefs
  #$rusty->{data}->{messages} =
  #  $rusty->getMessages( $rusty->{core}->{'profile_id'},
  #                       $rusty->{data}->{'tray'},
  #                       $rusty->{data}->{'offset'},
  #                       $rusty->{data}->{'limit'},
  #                       $rusty->{data}->{'order'},
  #                       $rusty->{data}->{'order2'} );
  
  $rusty->process_template;
}




sub read {
  
  $rusty->{ttml} = "profile/message/read.ttml";
  
  $rusty->{data}->{tray_count} = $rusty->getAllMessagesSummary($rusty->{core}->{'profile_id'});
  
  # Catch processing errors that redirect back to read..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  
  $rusty->{data}->{mode} = $rusty->{params}->{mode};
  $rusty->{data}->{tray} = $rusty->{params}->{tray};
  
  my $message = $rusty->getMessageDetail($rusty->{params}->{message_id});
  
  # Unless the message we are reading is owned by us *OR* has already been sent to us..
  unless ( ($message->{sender_profile_id} == $rusty->{core}->{profile_id} ||
            $message->{recipient_profile_id} == $rusty->{core}->{profile_id}) &&
          !$message->{is_draft} ) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&tray=".$rusty->{data}->{tray}
                                     . "&prev_action=read"
                                     . "&success=0&reason=badmessageid" );
    $rusty->exit;
    
  }
  
  # Mark message as read unless it has already been read
  # (and don't flag as read until responded if friend request)..
  if (!$message->{read_date}) {
    if ($message->{flag} eq "LINKEDFRIEND") {
      $rusty->markMessageRead($rusty->{params}->{message_id});
      
      my $existing_friend_link = $rusty->findFriendLink($message->{sender_profile_id},
                                                        $rusty->{core}->{'profile_id'});
      # If we haven't found a link here we really should scream but hey ho. Haw haw!
      if ($existing_friend_link->{friend_link_id}) {
        # Mark the friend link request read here too! Why am I doing this twice?? :(
        $rusty->readFriendLink($existing_friend_link->{friend_link_id})
      }
    } else {
      $rusty->markMessageReadAndFlag($rusty->{params}->{message_id});
    }
  } elsif (!$message->{recipient_read_flag} && $message->{flag} ne "LINKEDFRIEND") {
    $rusty->markMessageReadFlags( recipient_profile_id => $rusty->{core}->{'profile_id'},
                                  message_ids => [ $rusty->{params}->{message_id} ] );
  }
  
  sub recurse_inner_message($$;$) { # Level is an optional arg. (3 on inner recursive call, 2 for public)
    my ($this_msg, $recurse_max, $recurse_level_count) = @_;
    if ($this_msg->{reply_id} || $this_msg->{forward_id}) {
      $this_msg->{original_message} = $rusty->getMessageDetail($this_msg->{reply_id} || $this_msg->{forward_id});
      if (++$recurse_level_count < $recurse_max) {
        &recurse_inner_message($this_msg->{original_message}, $recurse_max, $recurse_level_count);
      }
    }
  }
  # This should (hopefully) find the next 9 messages in this thread and
  # create a nice tree of messages to recurse over in the template!
  &recurse_inner_message($message, 9);
  
  $rusty->{data}->{message} = $message;
  
  # Give them a nice picture of the receipient or sender! :)
  $rusty->{data}->{message_main_photo} =
    $message->{sender_profile_id} == $rusty->{core}->{profile_id} ?
      $rusty->getPhotoInfo($message->{recipient_main_photo_id}) :
      $rusty->getPhotoInfo($message->{sender_main_photo_id});
    
  # Get the previous/next messages so we have links for them both..
  if ($rusty->{params}->{tray}) {
    if (my $message_cache = $rusty->getPrevAndNextMessages($rusty->{core}->{profile_id},
                                                           $rusty->{params}->{tray},
                                                           $rusty->{params}->{message_id})) {
      $rusty->{data}->{previous_message_id} = $message_cache->{prev};
      $rusty->{data}->{next_message_id} = $message_cache->{next};
      $rusty->{data}->{message_cache_count} = $message_cache->{count};
      $rusty->{data}->{message_cache_date} = $message_cache->{cache_date};
    }
  }
  
  $rusty->process_template;
  
}




sub compose {
  
  $rusty->{ttml} = "profile/message/compose.ttml";
  
  $rusty->{data}->{tray_count} = $rusty->getAllMessagesSummary($rusty->{core}->{'profile_id'});
  
  # Catch processing errors that redirect back to compose..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  
  # Make sure we know if people have come from a profile (and search)
  # or been sent back here from sending a message that was from there..
  $rusty->{data}->{from_profile} = $rusty->{params}->{from_profile};
  $rusty->{data}->{search_id} = $rusty->{params}->{search_id};
  
  # Pick out if original mode is reply, forward, editdraft or compose..
  $rusty->{data}->{mode} = $rusty->{params}->{mode};
  # and which tray we came from..
  $rusty->{data}->{tray} = $rusty->{params}->{tray};
  
  $rusty->{data}->{profile_name} = $rusty->{params}->{to};
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{profile_name}) > 0) {
    
    $rusty->{data}->{profile_name} = $rusty->{params}->{profile_name};
    
    if (!($rusty->{data}->{profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{profile_name}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=".$rusty->{data}->{mode}
                                         . "&tray=".$rusty->{data}->{tray}
                                         . "&success=0&reason=badprofilename"
                                         . "&profile_name="
                                         . $rusty->{data}->{profile_name} );
      $rusty->exit;
    }
    
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{profile_id} > 0) {
    
    $rusty->{data}->{friend_profile_id} = $rusty->{params}->{profile_id};
    
    if (!($rusty->{data}->{profile_name} =
            $rusty->getProfileNameFromProfileId($rusty->{data}->{profile_id}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=".$rusty->{data}->{mode}
                                         . "&tray=".$rusty->{data}->{tray}
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
    }
    
  }
  
  # If they are trying to send a message to themselves..
  if ($rusty->{core}->{profile_id} == $rusty->{data}->{profile_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=".$rusty->{data}->{mode}
                                       . "&tray=".$rusty->{data}->{tray}
                                       . "&success=0&reason=itisyou" );
    $rusty->exit;
  }
  
  
  if ($rusty->{data}->{mode} eq 'reply') {
    
    my $original_message = $rusty->getMessageDetail($rusty->{params}->{message_id});
    
    # If message we are replying to was not sent to us or has not been sent yet..
    # Or is a special automated message type (friend link request), disallow!
    if ($original_message->{recipient_profile_id} != $rusty->{core}->{profile_id} ||
        !$original_message->{sent_date} ||
        $original_message->{flag} eq 'LINKEDFRIEND') {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=reply"
                                       . "&tray=".$rusty->{data}->{tray}
                                       . "&success=0&reason=badmessageidlinked" );
      $rusty->exit;
      
    }
    
    $rusty->{data}->{subject} = "Re: " . $original_message->{subject};
    $rusty->{data}->{reply_id} = $original_message->{message_id};
    $rusty->{data}->{profile_name} = $original_message->{sender_profile_name};
    $rusty->{data}->{profile_id} = $original_message->{sender_profile_id};
    $rusty->{data}->{original_message} = $original_message;
    
  } elsif ($rusty->{data}->{mode} eq 'forward') {
    
    my $original_message = $rusty->getMessageDetail($rusty->{params}->{message_id});
    
    # If message we are forwarding was not sent to us or has not been sent yet..
    # Or is a special automated message type (friend link request), disallow!
    if ($original_message->{recipient_profile_id} != $rusty->{core}->{profile_id} ||
        !$original_message->{sent_date} ||
        $original_message->{flag} eq 'LINKEDFRIEND') {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=forward"
                                       . "&tray=".$rusty->{data}->{tray}
                                       . "&success=0&reason=badmessageidlinked" );
      $rusty->exit;
      
    }
    
    $rusty->{data}->{subject} = "[Fwd: " . $original_message->{subject} . "]";
    $rusty->{data}->{forward_id} = $original_message->{message_id};
    $rusty->{data}->{original_message} = $original_message;
    
  } elsif ($rusty->{data}->{mode} eq 'editdraft') {
    
    my $draft_message = $rusty->getMessageDetail($rusty->{params}->{message_id});
    $rusty->{data}->{subject} = $draft_message->{subject};
    $rusty->{data}->{body} = $draft_message->{body};
    $rusty->{data}->{message_id} = $draft_message->{message_id};
    $rusty->{data}->{profile_name} = $draft_message->{draft_recipient_profile_name};
    
    # If the draft was a reply/forward, get the original message!
    if ($rusty->{data}->{reply_id} = $draft_message->{reply_id}) {
      $rusty->{data}->{original_message} = $rusty->getMessageDetail($rusty->{data}->{reply_id});
    } elsif ($rusty->{data}->{forward_id} = $draft_message->{forward_id}) {
      $rusty->{data}->{original_message} = $rusty->getMessageDetail($rusty->{data}->{forward_id});
    }
    
  }
  
  sub recurse_inner_message($$;$) { # Level is an optional arg. (3 on inner recursive call, 2 for public)
    my ($this_msg, $recurse_max, $recurse_level_count) = @_;
    if ($this_msg->{reply_id} || $this_msg->{forward_id}) {
      $this_msg->{original_message} = $rusty->getMessageDetail($this_msg->{reply_id} || $this_msg->{forward_id});
      if (++$recurse_level_count < $recurse_max) {
        &recurse_inner_message($this_msg->{original_message}, $recurse_max, $recurse_level_count);
      }
    }
  }
  # This should (hopefully) find the next 9 messages in this thread and
  # create a nice tree of messages to recurse over in the template!
  &recurse_inner_message($rusty->{data}->{original_message}, 9)
    if exists($rusty->{data}->{original_message}) &&
       $rusty->{data}->{original_message}->{message_id};
  
  ##################################
  
  if ($rusty->{data}->{profile_id}) {
    # Give them a nice picture of their recipient (if specified)! :)
    $rusty->{data}->{recipient_main_photo} =
      $rusty->getMainPhoto($rusty->{data}->{profile_id});
  }
  
  $rusty->process_template;
  
}



# This sub will show the full conversation thread history for a
# replied to or forwarded message.  But maybe 10 deep
# is more than enough; 1 - 1 conversations will both have the history in
# their inbox and any other big forwarded messages can copy/paste the
# important info from the original email!  No more chain messages! =)
sub viewconvhist {
  
  $rusty->{ttml} = "profile/message/viewconvhist.ttml";
  
  $rusty->{data}->{mode} = $rusty->{params}->{mode};
  $rusty->{data}->{tray} = $rusty->{params}->{tray};
  
  my $message = $rusty->getMessageDetail($rusty->{params}->{message_id});
  
  # Unless the message we are reading is owned by us *OR* has already been sent to us..
  unless ( ($message->{sender_profile_id} == $rusty->{core}->{profile_id} ||
            $message->{recipient_profile_id} == $rusty->{core}->{profile_id}) &&
          !$message->{is_draft} ) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&tray=".$rusty->{data}->{tray}
                                     . "&prev_action=read"
                                     . "&success=0&reason=badmessageid" );
    $rusty->exit;
    
  }
  
  sub recurse_inner_message($$;$) { # Level is an optional arg. (3 on inner recursive call, 2 for public)
    my ($this_msg, $recurse_max, $recurse_level_count) = @_;
    if ($this_msg->{reply_id} || $this_msg->{forward_id}) {
      $this_msg->{original_message} = $rusty->getMessageDetail($this_msg->{reply_id} || $this_msg->{forward_id});
      if (++$recurse_level_count < $recurse_max) {
        &recurse_inner_message($this_msg->{original_message}, $recurse_max, $recurse_level_count);
      }
    }
  }
  # This should (hopefully) find the next 49 messages in this thread and
  # create a nice tree of messages to recurse over in the template!
  # For performance reasons, we won't allow messages to have over 49 messages
  # tied to it - maybe we should just stop at 10 and not even allow > 10! :)
  &recurse_inner_message($message, 49);
  
  $rusty->{data}->{message} = $message;
  
  $rusty->process_template;
  
}





sub send {
  
  # If we are sending a message from a profile (and search) compose, then pass info on!
  my $extra_query_string_params = ( $rusty->{params}->{from_profile} ?
                                    "&from_profile="
                                  . $rusty->{params}->{from_profile} : "" )
                                . ( $rusty->{params}->{search_id} ?
                                    "&search_id="
                                  . $rusty->{params}->{search_id} : "" );
  
  # Now, let's catch out the smart-ass monster-truckers..
  # Posting only allowed to stop amateur spammers trying to
  # reconstruct the send POST URI as a GET.. Fools..
  unless ($rusty->ensure_post()) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                       . "?mode=inbox&prev_action=send"
                       . "&success=0&reason=notposted"
                       . $extra_query_string_params );
    $rusty->exit;
  }
  
  # Save the message to drafts so if we are saving, it's done, and if
  # we're sending, it will be saved in case of a problem in sending..
  my %msg_params = ( from_id => $rusty->{core}->{'profile_id'},
                     to_name => $rusty->{params}->{profile_name},
                     subject => $rusty->{params}->{subject},
                     body    => $rusty->{params}->{body} );
  
  $msg_params{reply_id} = $rusty->{params}->{reply_id} if $rusty->{params}->{reply_id};
  $msg_params{forward_id} = $rusty->{params}->{forward_id} if $rusty->{params}->{forward_id};
  $msg_params{message_id} = $rusty->{params}->{message_id} if $rusty->{params}->{message_id};
  
  my $saved_message_id = $rusty->saveDraftMessage(%msg_params);
  
  # If we are just saving this message to drafts, then return with success!
  if ($rusty->{params}->{save}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                       . "?mode=list&tray=drafts"
                       . "&prev_action=save"
                       . "&success=" . ($saved_message_id > 0 ? 1 : 0)
                       . $extra_query_string_params );
    $rusty->exit;
  }
  
  # Now do the checks for sending..
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{profile_name}) > 0) {
    
    $rusty->{data}->{profile_name} = $rusty->{params}->{profile_name};
    
    if (!($rusty->{data}->{profile_id} =
            $rusty->getProfileIdFromProfileName($rusty->{data}->{profile_name}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=compose&prev_action=send"
                                         . "&message_id=".$saved_message_id
                                         . "&tray=".$rusty->{params}->{tray}
                                         . "&success=0&reason=badprofilename"
                                         . "&profile_name="
                                         . $rusty->{data}->{profile_name}
                                         . $extra_query_string_params );
      $rusty->exit;
    }
    
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{profile_id} > 0) {
    
    $rusty->{data}->{friend_profile_id} = $rusty->{params}->{profile_id};
    
    if (!($rusty->{data}->{profile_name} =
            $rusty->getProfileNameFromProfileId($rusty->{data}->{profile_id}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=compose&prev_action=send"
                                         . "&message_id=".$saved_message_id
                                         . "&tray=".$rusty->{params}->{tray}
                                         . "&success=0&reason=badprofileid"
                                         . $extra_query_string_params);
      $rusty->exit;
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=compose&prev_action=send"
                                       . "&message_id=".$saved_message_id
                                       . "&tray=".$rusty->{params}->{tray}
                                       . "&success=0&reason=noprofileidorname"
                                       . $extra_query_string_params);
    $rusty->exit;
  }
  
  # If they are trying to send a message to themselves..
  if ($rusty->{core}->{profile_id} == $rusty->{data}->{profile_id}) {
    
    # I sometimes allow this (comment out below) for testing porpoises :)
    # But don't do it in production as messages to oneself messes up the
    # numbers when working out how many messages in inbox/sent items. :(
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=compose&prev_action=send"
                                       . "&message_id=".$saved_message_id
                                       . "&tray=".$rusty->{params}->{tray}
                                       . "&success=0&reason=itisyou"
                                       . $extra_query_string_params );
    $rusty->exit;
  }
  
  # If replying to or forwarding a message, make sure the 
  # original message was sent to us and has already been sent.
  if ($rusty->{params}->{reply_id} || $rusty->{params}->{forward_id}) {
    
    my $original_message = $rusty->getMessageDetail($rusty->{params}->{reply_id} || 
                                                    $rusty->{params}->{forward_id});
    
    # If message we are replying to was not sent to us or has not been sent yet..
    if ($original_message->{recipient_profile_id} != $rusty->{core}->{profile_id} ||
        !$original_message->{sent_date} ||
        $original_message->{flag} eq 'LINKEDFRIEND') {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=editdraft&prev_action=send"
                                       . "&message_id=".$saved_message_id
                                       . "&tray=".$rusty->{params}->{tray}
                                       . "&success=0&reason=badmessageidlinked"
                                       . $extra_query_string_params);
      $rusty->exit;
      
    }
    
  }
  
  my $success = $rusty->sendSavedMessage( saved_message_id => $saved_message_id,
                                          profile_id       => $rusty->{data}->{profile_id} );
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                   . "?mode=inbox&prev_action=send"
                   . "&success=$success&offset=0"
                   . $extra_query_string_params );
  $rusty->exit;
  
}




sub processselected {
  
  my $mode = shift;
  $rusty->{params}->{'tray'} ||= "inbox";
  
  # If the fool has not specified any message ids, send them back!
  if (!$rusty->{params}->{message_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&tray=".$rusty->{params}->{'tray'}
                                       . "&prev_action=$mode"
                                       . "&success=0&reason=nomessageid" );
    $rusty->exit;
    
  }
  
  my @message_ids = $rusty->CGI->param('message_id');
  
  my $success;
  my %params = ( user_action => 1 );
  if ($rusty->{params}->{'tray'} =~ /^(?:sent|drafts)$/o) {
    $params{sender_profile_id} = $rusty->{core}->{'profile_id'};
  } else {
    $params{recipient_profile_id} = $rusty->{core}->{'profile_id'};
  }
  if ($mode eq 'delete') {
    $success = $rusty->deleteMessages( %params,
                                       message_ids => [ $rusty->{params}->{message_id} ] );
  } elsif ($mode eq 'deleteselected') {
    $success = $rusty->deleteMessages( %params,
                                       message_ids => \@message_ids );
  } elsif ($mode eq 'markasread') {
    $success = $rusty->markMessageReadFlags( recipient_profile_id => $rusty->{core}->{'profile_id'},
                                             message_ids => [ $rusty->{params}->{message_id} ]);
  } elsif ($mode eq 'markselectedasread') {
    $success = $rusty->markMessageReadFlags( recipient_profile_id => $rusty->{core}->{'profile_id'},
                                             message_ids => \@message_ids);
  } elsif ($mode eq 'markasunread') {
    $success = $rusty->markMessageUnreadFlags( recipient_profile_id => $rusty->{core}->{'profile_id'},
                                               message_ids => [ $rusty->{params}->{message_id} ]);
  } elsif ($mode eq 'markselectedasunread') {
    $success = $rusty->markMessageUnreadFlags( recipient_profile_id => $rusty->{core}->{'profile_id'},
                                               message_ids => \@message_ids);
  } else {
    warn "unknown mode: $mode";
    $success = 0;
  }
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&tray=".$rusty->{params}->{'tray'}
                                     . "&prev_action=$mode"
                                     . "&success=".($success>0?1:0) );
}




sub submitasspam {
  
  $rusty->{params}->{'tray'} ||= "inbox";
  
  # If the fool has not specified any message ids, send them back!
  if (!$rusty->{params}->{message_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&tray=".$rusty->{params}->{'tray'}
                                       . "&prev_action=submitasspam"
                                       . "&success=0&reason=nomessageid" );
    $rusty->exit;
    
  }
  
  my $message = $rusty->getMessageDetail($rusty->{params}->{message_id});
  
  # Unless the message we are reading is owned by us *OR* has already been sent to us..
  unless ( ($message->{sender_profile_id} == $rusty->{core}->{profile_id} ||
            $message->{recipient_profile_id} == $rusty->{core}->{profile_id}) &&
          !$message->{is_draft} ) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&tray=".$rusty->{data}->{tray}
                                     . "&prev_action=submitasspam"
                                     . "&success=0&reason=badmessageid" );
    $rusty->exit;
    
  }
  
  if ($rusty->submitMessageAsSpam($rusty->{params}->{message_id})) {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&tray=".$rusty->{params}->{'tray'}
                                       . "&prev_action=submitasspam"
                                       . "&success=1" );
    
    require Email; #qw( send_email create_html_from_text );
    
    # Send out email to a support dept.
    
    my $current_time = localtime();
    
    my $textmessage = <<ENDMSG
  =============
  Date: $current_time
  User ID: $rusty->{core}->{user_id}
  Email: $rusty->{core}->{email}
  Profile Name: $rusty->{core}->{profile_name}
  Message ID: $rusty->{params}->{message_id}
  =============
  
  Subject: $message->{subject}
  
  Message:
  
$message->{body}
  
ENDMSG
;
    
    my $htmlmessage = Email::create_html_from_text($textmessage);
    
    Email::send_email( 'To'          => [ "spam\@rustypea.com", ],
                       'Reply-To'    => [ "$rusty->{core}->{profile_name} <$rusty->{core}->{email}>", ],
                       'Subject'     => "Spam message submitted",
                       'TextMessage' => $textmessage,
                       'HtmlMessage' => $htmlmessage );
    
  } else {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&tray=".$rusty->{params}->{'tray'}
                                       . "&prev_action=submitasspam"
                                       . "&success=0&reason=alreadysubmittedasspam" );
  }
}

  




