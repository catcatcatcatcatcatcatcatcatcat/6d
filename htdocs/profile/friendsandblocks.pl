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
  
  # If we have no profile & we're not redirected from this (prev_action set)
  require URI::Escape;
  print $rusty->CGI->redirect( -url => "/profile/account.pl?ref="
                                     . URI::Escape::uri_escape($rusty->{core}->{'self_url'}) );
  #print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
  #                                   . "?mode=list&prev_action="
  #                                   . $rusty->{params}->{mode}
  #                                   . "&success=0&reason=noprofile" );
  $rusty->exit;
}

# Make sure that if we have come here from a profile page (which may
# have also been from a search) that we always allow the user to get
# back to their profile view page, and from there back to their search.
$rusty->{data}->{search_id} = $rusty->{params}->{search_id};
$rusty->{data}->{from_profile} = $rusty->{params}->{from_profile};
if ($rusty->{data}->{from_profile}) {
  $rusty->{data}->{query_string_params} = "&from_profile="
                                        . $rusty->{params}->{from_profile}
                                        . "&search_id="
                                        . $rusty->{data}->{search_id};
}


$_ = $rusty->{params}->{mode};
SWITCH:
{
  &addfriend, last SWITCH if /^addfriend$/;
  &respond, last SWITCH if /^respond$/;
  &delfriend, last SWITCH if /^delfriend$/;
  &addfave, last SWITCH if /^addfave$/;
  &delfave, last SWITCH if /^delfave$/;
  &block, last SWITCH if /^block$/;
  &unblock, last SWITCH if /^unblock$/;
  &addeditnote($_), last SWITCH if /^(?:add|edit)note$/;
  &delnote, last SWITCH if /^delnote$/;
  &updateprefs, last SWITCH if /^updateprefs$/;
  &list, last SWITCH if /^list$/;
  
  # Default behaviour: list
  $rusty->{data}->{errors}->{mode} = "mode $_ is not defined" if $_;
  &list;
}

$rusty->exit;




sub list {
  
  $rusty->{ttml} = "profile/friendsandblocks-admin.ttml";
  
  if ($rusty->{core}->{'profile_id'}) {
    $rusty->{data}->{friend_links} = $rusty->getAllFriends($rusty->{core}->{'profile_id'});
    $rusty->{data}->{fave_links} = $rusty->getAllFaves($rusty->{core}->{'profile_id'});
    $rusty->{data}->{block_links} = $rusty->getAllBlocks($rusty->{core}->{'profile_id'});
    $rusty->{data}->{notes} = $rusty->getAllProfileNotes($rusty->{core}->{'profile_id'});
    $rusty->{data}->{display_prefs} = $rusty->getProfileDisplayPrefs($rusty->{core}->{'profile_id'});
  }
  
  # Catch processing errors that redirect back to list..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  $rusty->{data}->{friend_profile_name} = $rusty->{params}->{friend_profile_name};
  $rusty->{data}->{block_profile_name} = $rusty->{params}->{block_profile_name};
  
  $rusty->process_template;
}


sub addfriend {
  
  $rusty->{ttml} = "profile/friends-add.ttml";
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{friend_profile_name}) > 0) {
    
    $rusty->{data}->{friend_profile_name} = $rusty->{params}->{friend_profile_name};
    
    if (!($rusty->{data}->{friend_profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{friend_profile_name}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=addfriend"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofilename"
                                         . "&friend_profile_name="
                                         . $rusty->{data}->{friend_profile_name} );
      $rusty->exit;
      
    }
    
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{friend_profile_id} > 0) {
    
    $rusty->{data}->{friend_profile_id} = $rusty->{params}->{friend_profile_id};
    
    if (!($rusty->{data}->{friend_profile_name} =
         $rusty->getProfileNameFromProfileId($rusty->{data}->{friend_profile_id}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=addfriend"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
      
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfriend"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  # If they are trying to create a link to themselves..
  if ($rusty->{core}->{profile_id} == $rusty->{data}->{friend_profile_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfriend"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=itisyou" );
    $rusty->exit;
  }
  
  # Look for any current link from us to them OR any link in to us
  # from them that is unanswered (read or unread, but not decided)
  $rusty->{data}->{existing_friend_link} = $rusty->findPendingOrExistingFriendLink($rusty->{core}->{'profile_id'},
                                                                         $rusty->{data}->{friend_profile_id});
  
  # If there is already a pending or existing link between them,
  # throw the error (the ttml will handle the different messages).
  if ($rusty->{data}->{existing_friend_link}->{friend_link_id}) {
    $rusty->{data}->{friend_main_photo} =
      $rusty->getMainPhoto($rusty->{data}->{friend_profile_id});
    $rusty->process_template;
    $rusty->exit;
  }
  
  my $existing_block_link = $rusty->findBlockLink($rusty->{core}->{'profile_id'},
                                                  $rusty->{data}->{friend_profile_id});
  
  # If there is a blsock link on this profile, we can't add them as a friend!
  if ($existing_block_link->{block_link_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfriend"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=friendblocked" );
    $rusty->exit;
  }
  # If the request was made to actually create the friend link, then do it!
  if ($rusty->{params}->{send} == 1) {
    
    $rusty->{data}->{friend_link_id} = $rusty->requestFriendLink($rusty->{core}->{'profile_id'},
                                                                 $rusty->{data}->{friend_profile_id});
    
    unless ($rusty->{data}->{friend_link_id}) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=addfriend"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0" );
      $rusty->exit;
      
    }
    
    my $subject = "friend link request from $rusty->{core}->{profile_name}";
    
    my $message = <<ENDMSG
$rusty->{core}->{profile_name} has requested that your profiles be linked because you are friends.
If you agree, a link to $rusty->{core}->{profile_name}'s profile will appear on your profile, and vice versa.

Of course, its quite possible that $rusty->{data}->{profile_name} is some kind of scary-ass stalker who,
as we speak, is outside your house in the dark of night waiting for a moment to sneak in
and go through your knicker drawer. Kinky!

ENDMSG
;
    if ($rusty->{params}->{message} =~ /\w/o) {
      $message .= <<ENDMSG
To help you make your decision, $rusty->{core}->{profile_name} added the following message:

--

$rusty->{params}->{message}

--

ENDMSG
;
    }
    
    $message .= <<ENDMSG
So, if you have heard of $rusty->{core}->{profile_name}, click on "Accept".
If you suspect they're the aforementioned stalker, click on "Reject".

This message will remain "Unread" until you respond using the buttons below.

ENDMSG
;
    
    my $msg_id = $rusty->sendMessage( from    => $rusty->{core}->{'profile_id'},
                                      to      => $rusty->{data}->{friend_profile_id},
                                      subject => $subject,
                                      body    => $message,
                                      flag    => "LINKEDFRIEND" );
    
    unless ($msg_id) {
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfriend"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0" );
      $rusty->exit;
    }
    
    # Add this message id to the friend link record!
    $rusty->addMsgIdToFriendLink($rusty->{data}->{friend_link_id}, $msg_id);
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfriend"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=1" );
    $rusty->exit;
    
  } else {
    
    # This is the first page of adding a friend, so
    # give them a nice picture of their friend! :)
    $rusty->{data}->{friend_main_photo} =
      $rusty->getMainPhoto($rusty->{data}->{friend_profile_id});
  }
  
  $rusty->process_template;
}


sub delfriend {
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{friend_profile_name}) > 0) {
    
    $rusty->{data}->{friend_profile_name} = $rusty->{params}->{friend_profile_name};
    
    if (!($rusty->{data}->{friend_profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{friend_profile_name}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=delfriend"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofilename"
                                         . "&friend_profile_name="
                                         . $rusty->{data}->{friend_profile_name} );
      $rusty->exit;
      
    }
    
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{friend_profile_id} > 0) {
    
    $rusty->{data}->{friend_profile_id} = $rusty->{params}->{friend_profile_id};
    
    if (!($rusty->{data}->{friend_profile_name} =
         $rusty->getProfileNameFromProfileId($rusty->{data}->{friend_profile_id}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=delfriend"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
      
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=delfriend"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  my $existing_friend_link = $rusty->findFriendLink($rusty->{core}->{'profile_id'},
                                                    $rusty->{data}->{friend_profile_id});
  
  # If there is not already a pending or existing link between them, throw the error.
  unless ($existing_friend_link->{friend_link_id}) {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=delfriend"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=nofriendlinkfound" );
    $rusty->exit;
  }
  
  my $success = $rusty->deleteFriendLink($existing_friend_link->{friend_link_id});
  
  # Now delete the invitation message if it is still undecided
  if ($existing_friend_link->{status} =~ /^(?:un)?read$/o) {
    $rusty->deleteMessages( recipient_profile_id => $rusty->{core}->{'profile_id'},
                            message_ids => [ $existing_friend_link->{message_id} ] );
  }
    
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=delfriend"
                                     . $rusty->{data}->{query_string_params}
                                     . "&success=".($success>0?1:0) );
}


sub respond {
  
  my $existing_friend_link;
  if ($rusty->{params}->{friend_link_id}) {
    
    $existing_friend_link = $rusty->getFriendLink($rusty->{params}->{friend_link_id});
    
  } elsif ($rusty->{params}->{friend_profile_name}) {
    
    # If we weren't furnished with a friend_link_id, find it out from the requester's
    # profile name (we get this from the message requests)
    $rusty->{data}->{requester_profile_name} = $rusty->{params}->{friend_profile_name};
    $rusty->{data}->{requester_profile_id} =
      $rusty->getProfileIdFromProfileName($rusty->{params}->{friend_profile_name});
    
    $existing_friend_link = $rusty->findFriendLink($rusty->{data}->{requester_profile_id},
                                                   $rusty->{core}->{'profile_id'});
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=respond"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=notenoughinfo" );
    $rusty->exit;
  }
  
  # If we couldn't find a link with that id or it's not one meant for us, go oops now.
  # Also if it's not respondable to-able (this should never happen) - (not read status)
  if (!$existing_friend_link->{friend_link_id} ||
      ($existing_friend_link->{requestee_profile_id} != $rusty->{core}->{'profile_id'}) ||
      $existing_friend_link->{status} ne "read") {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=respond"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=nopendingfriendlinkfound" );
    $rusty->exit;
    
  # Say oops politely if the invite has been deleted while
  # they were reading the message (shouldn't happen that much!)
  } elsif ($existing_friend_link->{deleted_date}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=respond"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=linkrequestdeleted" );
    $rusty->exit;
    
  }
  
  if (!$rusty->{data}->{requester_profile_name}) {
    
    $rusty->{data}->{requester_profile_name} =
      $rusty->getProfileNameFromProfileId($existing_friend_link->{requester_profile_id});
  }
  
  if (($rusty->{params}->{response} eq 'accept') ||
      ($rusty->{params}->{response} eq 'acceptandreciprocate')) {
    
    $rusty->acceptFriendLink($existing_friend_link->{friend_link_id});
    
    my $subject = "friend link request response";
    
    my $message = "$rusty->{core}->{profile_name} has accepted your request to link your profiles as friends.\n";
    
    $rusty->sendMessage( from               => $rusty->{core}->{'profile_id'},
                         to                 => $existing_friend_link->{requester_profile_id},
                         subject            => $subject,
                         body               => $message,
                         sender_hidden_from => 1,
                         flag               => 'LINKEDFRIENDRESPONSE' );
    
    if ($rusty->{params}->{response} eq 'acceptandreciprocate') {
      
      # Add new reciprocal link unless a valid or pending friend link already exists.
      $rusty->addReciprocalFriendLink($rusty->{core}->{'profile_id'},
                                      $existing_friend_link->{requester_profile_id})
        unless $rusty->findPendingOrExistingFriendLink($rusty->{core}->{'profile_id'},
                                             $existing_friend_link->{requester_profile_id});
      
    }
    
  } elsif (($rusty->{params}->{response} eq 'reject') ||
           ($rusty->{params}->{response} eq 'rejectandblock')) {
    
    $rusty->rejectFriendLink($existing_friend_link->{friend_link_id});
    
    my $subject = "friend link request response";
    
    my $message = "$rusty->{core}->{profile_name} has rejected your request to link your profiles as friends.\n";
    
    $rusty->sendMessage( from               => $rusty->{core}->{'profile_id'},
                         to                 => $existing_friend_link->{requester_profile_id},
                         subject            => $subject,
                         body               => $message,
                         sender_hidden_from => 1,
                         flag               => 'LINKEDFRIENDRESPONSE' );
    
    if ($rusty->{params}->{response} eq 'rejectandblock') {
      
      # Add a block on this person unless a valid block already exists.
      $rusty->addBlockLink($rusty->{core}->{'profile_id'},
                           $existing_friend_link->{requester_profile_id})
        unless ($rusty->findBlockLink($rusty->{core}->{'profile_id'},
                                      $existing_friend_link->{requester_profile_id}));
      
    }
    
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=respond"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=invalidresponse" );
    $rusty->exit;
  }
  
  # Take message that was this request and mark it as read if we were given it..
  $rusty->markMessageReadFlags( recipient_profile_id => $rusty->{core}->{'profile_id'},
                                message_ids => [ $existing_friend_link->{message_id} ]);

  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=respond"
                                     . $rusty->{data}->{query_string_params}
                                     . "&success=1&response="
                                     . $rusty->{params}->{response} );
}


sub addfave {
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{fave_profile_name}) > 0) {
    
    $rusty->{data}->{fave_profile_name} = $rusty->{params}->{fave_profile_name};
    
    if (!($rusty->{data}->{fave_profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{fave_profile_name}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=addfave"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofilename"
                                         . "&fave_profile_name="
                                         . $rusty->{data}->{fave_profile_name} );
      $rusty->exit;
      
    }
    
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{fave_profile_id} > 0) {
    
    $rusty->{data}->{fave_profile_id} = $rusty->{params}->{fave_profile_id};
    
    if (!($rusty->{data}->{fave_profile_name} =
         $rusty->getProfileNameFromProfileId($rusty->{data}->{fave_profile_id}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=addfave"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
      
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfave"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  # If they are trying to create a link to themselves..
  if ($rusty->{core}->{profile_id} == $rusty->{data}->{fave_profile_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfave"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=itisyou" );
    $rusty->exit;
  }
  
  # Look for any current link from us to them..
  my $existing_fave_link = $rusty->findExistingFaveLink($rusty->{core}->{'profile_id'},
                                                        $rusty->{data}->{fave_profile_id});
  
  # If there is already a fave link on this profile, throw the error.
  if ($existing_fave_link->{fave_link_id}) {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfave"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=favelinkalreadyexists" );
    $rusty->exit;
  }
  
  my $existing_block_link = $rusty->findBlockLink($rusty->{core}->{'profile_id'},
                                                  $rusty->{data}->{fave_profile_id});
  
  # If there is a block link on this profile, we can't add them as a fave!
  if ($existing_block_link->{block_link_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfave"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=faveblocked" );
    $rusty->exit;
  }
  
  unless ($rusty->createFaveLink($rusty->{core}->{'profile_id'},
                                 $rusty->{data}->{fave_profile_id})) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfave"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0" );
    $rusty->exit;
    
  }
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=addfave"
                                     . $rusty->{data}->{query_string_params}
                                     . "&success=1" );
  $rusty->exit;
}


sub delfave {
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{fave_profile_name}) > 0) {
    
    $rusty->{data}->{fave_profile_name} = $rusty->{params}->{fave_profile_name};
    
    if (!($rusty->{data}->{fave_profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{fave_profile_name}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=delfave"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofilename"
                                         . "&fave_profile_name="
                                         . $rusty->{data}->{fave_profile_name} );
      $rusty->exit;
      
    }
    
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{fave_profile_id} > 0) {
    
    $rusty->{data}->{fave_profile_id} = $rusty->{params}->{fave_profile_id};
    
    if (!($rusty->{data}->{fave_profile_name} =
         $rusty->getProfileNameFromProfileId($rusty->{data}->{fave_profile_id}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=delfave"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
      
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=delfave"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  my $existing_fave_link = $rusty->findExistingFaveLink($rusty->{core}->{'profile_id'},
                                                        $rusty->{data}->{fave_profile_id});
  
  # If there is not already a pending or existing link between them, throw the error.
  unless ($existing_fave_link->{fave_link_id}) {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=delfave"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=nofavelinkfound" );
    $rusty->exit;
  }
  
  my $success = $rusty->deleteFaveLink($existing_fave_link->{fave_link_id});
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=delfave"
                                     . $rusty->{data}->{query_string_params}
                                     . "&success=".($success>0?1:0) );
}


sub block {
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{block_profile_name}) > 0) {
    
    $rusty->{data}->{block_profile_name} = $rusty->{params}->{block_profile_name};
    
    if (!($rusty->{data}->{block_profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{block_profile_name}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=block"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofilename"
                                         . "&block_profile_name="
                                         . $rusty->{data}->{block_profile_name});
      $rusty->exit;
      
    }
    
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{block_profile_id} > 0) {
    
    $rusty->{data}->{block_profile_id} = $rusty->{params}->{block_profile_id};
    
    if (!($rusty->{data}->{block_profile_name} =
         $rusty->getProfileNameFromProfileId($rusty->{data}->{block_profile_id}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=block"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
      
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=block"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  # If they are trying to create a link to themselves..
  if ($rusty->{core}->{profile_id} == $rusty->{data}->{block_profile_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=block"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=itisyou" );
    $rusty->exit;
  }
  
  my $existing_block_link = $rusty->findBlockLink($rusty->{core}->{'profile_id'},
                                                  $rusty->{data}->{block_profile_id});
  
  
  # If there is already a block link on this profile, throw the error.
  if ($existing_block_link->{block_link_id}) {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=block"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=blocklinkalreadyexists" );
    $rusty->exit;
  }
  
  my $existing_friend_link = $rusty->findFriendLink($rusty->{core}->{'profile_id'},
                                                    $rusty->{data}->{block_profile_id});
  
  # If there is a friend link on this profile, we can't add them as a block!
  if ($existing_friend_link->{friend_link_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=block"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=blockisfriend" );
    $rusty->exit;
  }
  
  my $existing_fave_link = $rusty->findExistingFaveLink($rusty->{core}->{'profile_id'},
                                                        $rusty->{data}->{block_profile_id});
  
  # If there is a fave link on this profile, we can't add them as a block!
  if ($existing_fave_link->{fave_link_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=block"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=blockisfave" );
    $rusty->exit;
  }
  
  my $success = $rusty->addBlockLink($rusty->{core}->{'profile_id'},
                                     $rusty->{data}->{block_profile_id});
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=block"
                                     . $rusty->{data}->{query_string_params}
                                     . "&success=".($success>0?1:0) );
}


sub unblock {
  
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{block_profile_name}) > 0) {
    
    $rusty->{data}->{block_profile_name} = $rusty->{params}->{block_profile_name};
    
    if (!($rusty->{data}->{block_profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{block_profile_name}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=unblock"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofilename"
                                         . "&block_profile_name="
                                         . $rusty->{data}->{block_profile_name});
      $rusty->exit;
      
    }
    
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{block_profile_id} > 0) {
    
    $rusty->{data}->{block_profile_id} = $rusty->{params}->{block_profile_id};
    
    if (!($rusty->{data}->{block_profile_name} =
         $rusty->getProfileNameFromProfileId($rusty->{data}->{block_profile_id}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=unblock"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
      
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=unblock"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  my $existing_block_link = $rusty->findBlockLink($rusty->{core}->{'profile_id'},
                                                  $rusty->{data}->{block_profile_id});
  
  # If there is not already a block link on this profile, throw the error.
  unless ($existing_block_link->{block_link_id}) {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=unblock"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=noblocklinkfound" );
    $rusty->exit;
  }
  
  my $success = $rusty->unblockBlockLink($existing_block_link->{block_link_id});
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=unblock"
                                     . $rusty->{data}->{query_string_params}
                                     . "&success=".($success>0?1:0) );
}


sub addeditnote {
  
  my $action = shift;
    
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{noted_profile_name}) > 0) {
    
    $rusty->{data}->{noted_profile_name} = $rusty->{params}->{noted_profile_name};
    
    if (!($rusty->{data}->{noted_profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{noted_profile_name}))) {
      
      print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                         . $rusty->{data}->{noted_profile_name}
                                         . "&prev_action=$action"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofilename"
                                         . "&noted_profile_name="
                                         . $rusty->{data}->{noted_profile_name} );
      $rusty->exit;
      
    }
  
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{noted_profile_id} > 0) {
    
    $rusty->{data}->{noted_profile_id} = $rusty->{params}->{noted_profile_id};
    
    if (!($rusty->{data}->{noted_profile_name} =
         $rusty->getProfileNameFromProfileId($rusty->{data}->{noted_profile_id}))) {
      
      print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                         . $rusty->{data}->{noted_profile_name}
                                         . "&prev_action=$action"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
      
    }
  
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                       . $rusty->{data}->{noted_profile_name}
                                       . "&prev_action=$action"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  # If they are trying to create a note about themselves..
  if ($rusty->{core}->{profile_id} == $rusty->{data}->{noted_profile_id}) {
    
    print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                       . $rusty->{data}->{noted_profile_name}
                                       . "&prev_action=$action"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=itisyou" );
    $rusty->exit;
  }
  
  if (length($rusty->{params}->{note}) == 0) {
    
    if ($action eq 'addnote') {
      print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                         . $rusty->{data}->{noted_profile_name}
                                         . "&prev_action=$action"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=nonote"
                                         . "&mode=addnote" );
      $rusty->exit;
    } else {
      
      my $success = $rusty->deleteProfileNote($rusty->{core}->{'profile_id'},
                                              $rusty->{data}->{noted_profile_id});
      
      print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                         . $rusty->{data}->{noted_profile_name}
                                         . "&prev_action=delnote"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=$success" );
      $rusty->exit;
    }
  }
  
  my $success = $rusty->createProfileNote($rusty->{core}->{'profile_id'},
                                          $rusty->{data}->{noted_profile_id},
                                          $rusty->{params}->{note});
  
  print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                     . $rusty->{data}->{noted_profile_name}
                                     . "&prev_action=$action"
                                     . $rusty->{data}->{query_string_params}
                                     . "&success=$success" );
  $rusty->exit;
}


sub delnote {
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{noted_profile_name}) > 0) {
    
    $rusty->{data}->{noted_profile_name} = $rusty->{params}->{noted_profile_name};
    
    if (!($rusty->{data}->{noted_profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{noted_profile_name}))) {
      
      print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                         . $rusty->{params}->{noted_profile_name}
                                         . "&prev_action=delnote"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofilename"
                                         . "&noted_profile_name="
                                         . $rusty->{data}->{noted_profile_name} );
      $rusty->exit;
      
    }
    
  # If a profile id has been specified, check it exists
  # and get the associated profile name.  If not, send back with error.
  } elsif ($rusty->{params}->{noted_profile_id} > 0) {
    
    $rusty->{data}->{noted_profile_id} = $rusty->{params}->{noted_profile_id};
    
    if (!($rusty->{data}->{noted_profile_name} =
         $rusty->getProfileNameFromProfileId($rusty->{data}->{noted_profile_id}))) {
      
      print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                         . $rusty->{params}->{noted_profile_name}
                                         . "&prev_action=delnote"
                                         . $rusty->{data}->{query_string_params}
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
      
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                       . $rusty->{params}->{noted_profile_name}
                                       . "&prev_action=delnote"
                                       . $rusty->{data}->{query_string_params}
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  my $success = $rusty->deleteProfileNote($rusty->{core}->{'profile_id'},
                                          $rusty->{data}->{noted_profile_id});
  
  print $rusty->CGI->redirect( -url => "/profile/view.pl?profile_name="
                                     . $rusty->{params}->{noted_profile_name}
                                     . "&prev_action=delnote"
                                     . $rusty->{data}->{query_string_params}
                                     . "&success=$success" );
}




sub updateprefs {
  
  if ($rusty->{params}->{updateparam} eq 'showfaves') {
    $rusty->updateProfileDisplayPrefs( profile_id => $rusty->{core}->{'profile_id'},
                                       showfaves =>
                                       $rusty->{params}->{showfaves} ? 1 : 0 );
  } elsif ($rusty->{params}->{updateparam} eq 'showfriends') {
    $rusty->updateProfileDisplayPrefs( profile_id => $rusty->{core}->{'profile_id'},
                                       showfriends =>
                                       $rusty->{params}->{showfriends} ? 1 : 0 );
  }
  
  
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=updateprefs"
                                     . $rusty->{data}->{query_string_params}
                                     . "&success=1" );
}

