#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Admin;

use vars qw($rusty $query $sth);

$rusty = rusty::Admin->new;

$_ = ($rusty->{data}->{mode} = $rusty->{params}->{mode});
SWITCH:
{
  &processphotos($_), last SWITCH if /^(?:approve|reject|mark_as_adult|undo_checking)$/;
  &list, last SWITCH if /^(?:list|recently_checked)$/;
  
  # Default behaviour: list
  $rusty->{data}->{errors}->{mode} = "mode $_ is not defined" if $_;
  &list
}



sub list {
  
  $rusty->{ttml} = "admin/photo-approvals.ttml";
  
  if ($rusty->{params}->{mode} eq 'recently_checked') {
    $rusty->{data}->{photos} = $rusty->getRecentlyCheckedPhotos();
  } else {
    $rusty->{data}->{photos} = $rusty->getAllPhotosPendingApproval();
  }
  
  # Catch processing errors that redirect back to list..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  
  $rusty->process_template;
  $rusty->exit;
}


sub processphotos {

  my $action = shift;
  
  unless ($rusty->{params}->{photo_id} > 0) {
    
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=$action"
                                     . "&success=0&reason=nophotoid" );
    $rusty->exit;
    
  }
  
  my $photo_info = $rusty->getPhotoInfo($rusty->{params}->{photo_id});
  
  # Check that this photo exists!
  if (!$photo_info) {
    
    warn "admin user trying to process photo id $rusty->{params}->{photo_id} that does not exist";
    
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=$action"
                                       . "&success=0&reason=badphotoid" );
    $rusty->exit;
    
  # To make it harder for naughty administrators deleting random photos
  # or doing things in bulk, check profile id of photo owner too
  } elsif ($rusty->{params}->{'profile_id'} == $photo_info->{'profile_id'}) {
    
    warn "admin user trying to process a photo that does not belong to them: "
       . "admin user id $rusty->{core}->{user_id} processing "
       . "photo id $rusty->{params}->{photo_id} from profile id $rusty->{params}->{profile_id} "
       . "but this photo actually belongs to $photo_info->{profile_id}";
    
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=$action"
                                       . "&success=0&reason=mismatch" );
    $rusty->exit;
    
  }
  
  # If approving photo, update the admin user id, set adult to 0 and checked_date to NOW
  # If marking photo as adult, update the admin user id, set adult to 1 and checked_date to NOW
  # If rejecting photo, update the admin user id, set rejected to 1 and checked_date to NOW
  if ($action =~ /^(?:approve|reject|mark_as_adult)$/) {
    
    # Then check photo isn't already checked - don't allow if already checked!
    if ($photo_info->{checked_date}) {
      
      warn "admin user trying to process photo id $rusty->params}->{photo_id} "
         . "that was already checked on $photo_info->{checked_date}";
      
      print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=$action"
                                       . "&success=0&reason=alreadychecked" );
      $rusty->exit;
      
    }
    
    $query = <<ENDSQL
UPDATE `user~profile~photo`
SET checked_date = NOW(),
    checked_by_user_id = ?,
    adult = ?,
    rejected = ?
WHERE photo_id = ?
  AND profile_id = ?
  AND checked_date IS NULL
LIMIT 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    my $rows = $sth->execute($rusty->{core}->{user_id}, ($action eq 'mark_as_adult' ? 1 : 0), ($action eq 'reject' ? 1 : 0), $rusty->{params}->{photo_id}, $rusty->{params}->{profile_id});
    $sth->finish;
    
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=$action"
                                       . "&success="
                                       . ($rows eq '0E0' ? "0&reason=unknown" : "1") );
    $rusty->exit;
    
  } elsif ($action eq 'undo_checking') {

    $query = <<ENDSQL
UPDATE `user~profile~photo`
SET checked_date = NULL,
    checked_by_user_id = ?,
    adult = NULL,
    rejected = NULL
WHERE photo_id = ?
  AND profile_id = ?
  AND checked_date IS NOT NULL
LIMIT 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    my $rows = $sth->execute($rusty->{core}->{user_id}, $rusty->{params}->{photo_id}, $rusty->{params}->{profile_id});
    $sth->finish;
    
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=recently_checked&prev_action=$action"
                                       . "&success="
                                       . ($rows eq '0E0' ? "0&reason=unknown" : "1") );
    $rusty->exit;
    
  }
      
  print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=$action"
                                     . "&success=1" );
  $rusty->exit;
  
}

