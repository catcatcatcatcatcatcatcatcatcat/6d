#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw( all );

no warnings qw( uninitialized );

use CarpeDiem;

use rusty::Profiles;

use vars qw( $rusty $query $sth );

$rusty = rusty::Profiles->new;

$rusty->{data}->{search_id} = $rusty->{params}->{search_id};



$_ = $rusty->{params}->{mode};
SWITCH:
{
  &display_single_photo, last SWITCH if /^single$/;
  
  # Default behaviour: display_single_photo
  $rusty->{data}->{errors}->{mode} = "mode $_ is not defined" if $_;
  &display_single_photo
}

$rusty->exit;




sub display_single_photo {
  
  $rusty->{ttml} = "profile/photo-display.ttml";
  
  $rusty->{data}->{profile_id} = $rusty->{params}->{profile_id};
  $rusty->{data}->{photo_id} = $rusty->{params}->{photo_id};
  $rusty->{data}->{mode} = $rusty->{params}->{mode};
  
  my $query = <<ENDSQL
SELECT up.profile_name,
       upp.profile_id, upp.photo_id,
       upp.filename, upp.resized_filename, upp.thumbnail_filename, upp.original_filename,
       upp.kilobytes, upp.width, upp.height,
       upp.thumbnail_nocrop_filename, upp.tnnc_width, upp.tnnc_height,
       upp.caption,
       DATE_FORMAT(upp.uploaded_date, '%d/%m/%y %H:%i') AS uploaded_date,
       DATE_FORMAT(upp.checked_date, '%d/%m/%y %H:%i') AS checked_date,
       upp.adult, upp.total_visit_count
FROM `user_profile_photo` upp
LEFT JOIN `user_profile` up ON up.profile_id = upp.profile_id
WHERE upp.photo_id = ?
  AND upp.deleted_date IS NULL
  AND rejected != 1
LIMIT 1
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute($rusty->{data}->{photo_id});
  $rusty->{data}->{photo} = $sth->fetchrow_hashref;
  $sth->finish;
  
  # If the photo id requested does not exist, go crazy!
  if (!$rusty->{data}->{photo}->{photo_id}) {
    warn "photo id requested simply does not exist in DB (could be rejected/deleted - photo id: $rusty->{data}->{photo_id})";
    $rusty->{data}->{error} = "Photo not found";
    $rusty->process_template;
    $rusty->exit;
  }
  
  
  # Let's make sure that if owner mode was requested, we are
  # looking at one of our own photos. If so, we give access regardless.
  if ($rusty->{data}->{mode} eq 'owner') {
    if ($rusty->{core}->{'profile_id'} &&
        $rusty->{core}->{'profile_id'} != $rusty->{data}->{photo}->{'profile_id'}) {
      warn "owner mode requested for photo that isn't theirs: "
         . " profile id '$rusty->{core}->{profile_id}' and photo id "
         . "'$rusty->{data}->{photo_id}'.";
      delete $rusty->{data}->{mode};
    }
  } elsif ($rusty->{data}->{mode} eq 'admin') {
    require rusty::Admin;
    #check if user is admin user with privileges
    if ($rusty->{core}->{'user_id'}) {
      require rusty::Admin;
      $rusty->{core}->{'admin_level'} = $rusty->rusty::Admin::getAdminLevelFromUserId($rusty->{core}->{'user_id'});
      if (!$rusty->{core}->{'admin_level'}) {
        warn "UserID '$rusty->{core}->{user_id}' trying to access admin pages but has no admin privileges set";
        print $rusty->redirect( -url => "/" );
        $rusty->exit;
      }
    } else {
      $rusty->redirectToLoginPage($rusty->{core}->{'self_url'});
      $rusty->exit;
    }
  }
  
  
  if ($rusty->{data}->{profile_id} ne $rusty->{data}->{photo}->{'profile_id'}) {
    
    warn "photo id $rusty->{data}->{photo_id} requested for non-matching profile id $rusty->{data}->{profile_id}"
       . " instead of correct profile id $rusty->{data}->{photo}->{'profile_id'}";
    $rusty->{data}->{error} = "Profile id and photo id do not match";
    $rusty->process_template;
    $rusty->exit;
    
  }
  
  
  # As long as we aren't looking at our own photo, update visit count.
  if ($rusty->{core}->{'profile_id'} != $rusty->{data}->{photo}->{'profile_id'}) {
    
    $query = <<ENDSQL
UPDATE `user_profile_photo` SET
total_visit_count = total_visit_count + 1
WHERE photo_id = ?
LIMIT 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{data}->{photo_id});
    $sth->finish;
    
    $rusty->{data}->{photo}->{total_visit_count}++;
    
  }
  $rusty->{data}->{warn} = $rusty->{params}->{warn};
  $rusty->process_template;
}

