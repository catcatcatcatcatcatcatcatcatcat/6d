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
  print $rusty->CGI->redirect( -url => "/signup.pl" );
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
  &list('inbox'), last SWITCH if /^inbox$/;
  &list('sent'), last SWITCH if /^sent$/;
  &list('drafts'), last SWITCH if /^drafts$/;
  &compose, last SWITCH if /^compose$/;
  &send, last SWITCH if /^send$/;
  &delete, last SWITCH if /^delete$/;
  &summary, last SWITCH if /^summary$/;
  
  # Default behaviour: summary
  $rusty->{data}->{errors}->{mode} = "mode $_ is not defined" if $_;
  &summary;
}

$rusty->exit;




sub summary {
  
  $rusty->{ttml} = "profile/message/summary.ttml";
  
  $rusty->{data}->{inbox_count} = $rusty->getMessagesSummary($rusty->{core}->{'profile_id'},'inbox');
  $rusty->{data}->{sent_count} = $rusty->getMessagesSummary($rusty->{core}->{'profile_id'},'sent');
  $rusty->{data}->{drafts_count} = $rusty->getMessagesSummary($rusty->{core}->{'profile_id'},'drafts');
  
  # Catch processing errors that redirect back to list..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  
  $rusty->process_template;
}


sub list {
  
  my $tray = shift;
  
  $rusty->{ttml} = "profile/message/list.ttml";
  
  # Catch processing errors that redirect back to list..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  
  $rusty->{data}->{inbox_count} = $rusty->getMessagesSummary($rusty->{core}->{'profile_id'},'inbox');
  $rusty->{data}->{sent_count} = $rusty->getMessagesSummary($rusty->{core}->{'profile_id'},'sent');
  $rusty->{data}->{drafts_count} = $rusty->getMessagesSummary($rusty->{core}->{'profile_id'},'drafts');
  
  if ($rusty->{params}->{'limit'} =~ /^\d+$/ &&
      $rusty->{params}->{'limit'} > 0 &&
      $rusty->{params}->{'limit'} < 100) {
    
    $rusty->{data}->{'limit'} = $rusty->{params}->{'limit'};
    
  } else {
    
    $rusty->{data}->{'limit'} = 10;
  }
  
  if ($rusty->{params}->{'offset'} =~ /^\d+$/ &&
      $rusty->{params}->{'offset'} < $rusty->{data}->{inbox_count}->{total}) {
    
    $rusty->{data}->{'offset'} = $rusty->{params}->{'offset'};
    
  } else {
    
    $rusty->{data}->{'offset'} = 0;
  }
  
  $rusty->{data}->{messages} =
    $rusty->getMessages($rusty->{core}->{'profile_id'},
                        $tray,
                        $rusty->{data}->{'offset'},
                        $rusty->{data}->{'limit'});
}


sub compose {
  
  # If a profile name has been specified, check it exists
  # and get the associated profile id.  If not, send back with error.
  if (length($rusty->{params}->{profile_name}) > 0) {
    
    $rusty->{data}->{profile_name} = $rusty->{params}->{profile_name};
    
    if (!($rusty->{data}->{profile_id} =
         $rusty->getProfileIdFromProfileName($rusty->{data}->{profile_name}))) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=summary&prev_action=inbox"
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
                                         . "?mode=list&prev_action=inbox"
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=inbox"
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
  }
  
  # If they are trying to send a message to themselves..
  if ($rusty->{core}->{profile_id} == $rusty->{data}->{profile_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=inbox"
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
  
  
  # If the request was made to actually create the friend link, then do it!
  if ($rusty->{params}->{send} == 1) {
    
    unless ($rusty->requestFriendLink($rusty->{core}->{'profile_id'},
                                      $rusty->{data}->{friend_profile_id})) {
      
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=addfriend"
                                         . "&success=0" );
      $rusty->exit;
      
    }
    
    my $subject = "friend link request from $rusty->{core}->{profile_name}";
    
    my $success = $rusty->sendMessage( from    => $rusty->{core}->{'profile_id'},
                                       to      => $rusty->{data}->{friend_profile_id},
                                       subject => $subject,
                                       body    => $message,
                                       special => "LINKEDFRIEND" );
    
    unless ($success) {
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfriend"
                                       . "&success=0" );
      $rusty->exit;
    }
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=addfriend"
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
  
  # If the fool has not specified a profile id, send them back!
  if (!$rusty->{params}->{friend_profile_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=delfriend"
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  my $existing_friend_link = $rusty->findFriendLink($rusty->{core}->{'profile_id'},
                                                    $rusty->{params}->{friend_profile_id});
  
  # If there is not already a pending or existing link between them, throw the error.
  unless ($existing_friend_link->{friend_link_id}) {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=delfriend"
                                       . "&success=0&reason=nofriendlinkfound" );
    $rusty->exit;
  }
  
  my $success = $rusty->deleteFriendLink($existing_friend_link->{friend_link_id});
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=delfriend"
                                     . "&success=".($success>0?1:0) );
  
}


sub respond {
  
  my $existing_friend_link = $rusty->getFriendLink($rusty->{params}->{friend_link_id});
  
  # If we couldn't find a link with that id or it's not one meant for us, go oops now.
  if (!$existing_friend_link->{friend_link_id} ||
      ($existing_friend_link->{requestee_profile_id} != $rusty->{core}->{'profile_id'})) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=respond"
                                       . "&success=0&reason=nopendingfriendlinkfound" );
    $rusty->exit;
    
  # Go oops now if it's not respondable to-able (this should never happen)
  } elsif ($existing_friend_link->{status} ne "read") {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=respond"
                                       . "&success=0&reason=nopendingfriendlinkfound" );
    $rusty->exit;
  
  # Say oops politely if the invite has been deleted while
  # they were reading the message (shouldn't happen that much!)
  } elsif ($existing_friend_link->{deleted_date}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=respond"
                                       . "&success=0&reason=linkrequestdeleted" );
    $rusty->exit;
    
  }
  
  $rusty->{data}->{requester_profile_name} =
    $rusty->getProfileNameFromProfileId($existing_friend_link->{requester_profile_id});
  
  if (($rusty->{params}->{reponse} eq 'accept') ||
      ($rusty->{params}->{reponse} eq 'acceptandreciprocate')) {
    
    $rusty->acceptFriendLink($existing_friend_link->{friend_link_id});
    
    $rusty->deleteMessage( from    => $rusty->{data}->{friend_profile_id},
                           to      => $rusty->{core}->{'profile_id'},
                           special => "LINKEDFRIEND" );
    
    my $subject = "friend link request response";
    
    my $message = "$rusty->{data}->{profile_name} has accepted your request to link your profiles as friends.\n";
    
    $rusty->sendMessage( from           => $rusty->{core}->{'profile_id'},
                         to             => $rusty->{data}->{friend_profile_id},
                         subject        => $subject,
                         body           => $message,
                         sender_deleted => 1 );
    
    if ($rusty->{params}->{reponse} eq 'acceptandreciprocate') {
      
      # Add new reciprocal link unless a valid or pending friend link already exists.
      $rusty->addReciprocalFriendLink($rusty->{core}->{'profile_id'},
                                      $existing_friend_link->{requester_profile_id})
        unless $rusty->findPendingOrExistingFriendLink($rusty->{core}->{'profile_id'},
                                             $existing_friend_link->{requester_profile_id});
        
    }
    
  } elsif (($rusty->{params}->{reponse} eq 'reject') ||
           ($rusty->{params}->{reponse} eq 'rejectandblock')) {
    
    $rusty->rejectFriendLink($existing_friend_link->{friend_link_id});
    
    $rusty->deleteMessage( from    => $rusty->{data}->{friend_profile_id},
                           to      => $rusty->{core}->{'profile_id'},
                           special => "LINKEDFRIEND" );
    
    my $subject = "friend link request response";
    
    my $message = "$rusty->{data}->{profile_name} has rejected your request to link your profiles as friends.\n";
    
    $rusty->sendMessage( from           => $rusty->{core}->{'profile_id'},
                         to             => $rusty->{data}->{friend_profile_id},
                         subject        => $subject,
                         body           => $message,
                         sender_deleted => 1 );
    
    if ($rusty->{params}->{reponse} eq 'rejectandblock') {
      
      # Add a block on this person unless a valid block already exists.
      $rusty->addBlockLink($rusty->{core}->{'profile_id'},
                           $existing_friend_link->{requester_profile_id})
        unless ($rusty->findBlockLink($rusty->{core}->{'profile_id'},
                                      $existing_friend_link->{requester_profile_id}));
        
    }
    
  }
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=respond"
                                     . "&success=1&response="
                                     . $rusty->{params}->{reponse} );
  
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
                                         . "&success=0&reason=badprofilename" );
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
                                         . "&success=0&reason=badprofileid" );
      $rusty->exit;
      
    }
    
  # If the fool has not specified any profile name or id, send them back!
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=block"
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  # If they are trying to create a link to themselves..
  if ($rusty->{core}->{profile_id} == $rusty->{data}->{block_profile_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=block"
                                       . "&success=0&reason=itisyou" );
    $rusty->exit;
  }
  
  my $existing_block_link = $rusty->findBlockLink($rusty->{core}->{'profile_id'},
                                                  $rusty->{data}->{block_profile_id});
  
  
  # If there is already a block link on this profile, throw the error.
  if ($existing_block_link->{block_link_id}) {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=block"
                                       . "&success=0&reason=blocklinkalreadyexists" );
    $rusty->exit;
  }
  
  my $success = $rusty->addBlockLink($rusty->{core}->{'profile_id'},
                                     $rusty->{data}->{block_profile_id});
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=block"
                                     . "&success=".($success>0?1:0) );
}


sub unblock {
  
  # If the fool has not specified a profile id, send them back!
  if (!$rusty->{params}->{block_profile_id}) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=unblock"
                                       . "&success=0&reason=noprofileidorname" );
    $rusty->exit;
    
  }
  
  my $existing_block_link = $rusty->findBlockLink($rusty->{core}->{'profile_id'},
                                                  $rusty->{params}->{block_profile_id});
  
  # If there is not already a block link on this profile, throw the error.
  unless ($existing_block_link->{block_link_id}) {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=unblock"
                                       . "&success=0&reason=noblocklinkfound" );
    $rusty->exit;
  }
  
  my $success = $rusty->unblockBlockLink($existing_block_link->{block_link_id});
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=unblock"
                                     . "&success=".($success>0?1:0) );
}

