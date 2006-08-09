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
  print $rusty->CGI->redirect( -url => "/login.pl?ref=/profile/photo-admin.pl" );
  $rusty->exit;
} elsif ($rusty->{core}->{profile_info}->{'deleted_date'}) {
  print $rusty->CGI->redirect( -url => "/profile/account.pl?deleted=1" );
  $rusty->exit;
}


if (!$rusty->{core}->{'profile_id'} && !$rusty->{params}->{prev_action}) {
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action="
                                     . $rusty->{params}->{mode}
                                     . "&success=0&reason=noprofile" );
  $rusty->exit;
}
my $profile = $rusty->getProfileInfo($rusty->{core}->{'profile_id'});
$rusty->{data}->{updated} = $profile->{updated};
$rusty->{data}->{main_photo_id} = $profile->{main_photo_id};

$_ = $rusty->{params}->{mode};
SWITCH:
{
  &setmainphoto, last SWITCH if /^setmainphoto$/;
  &delete, last SWITCH if /^delete$/;
  &editcaption, last SWITCH if /^editcaption$/;
  &list, last SWITCH if /^list$/;
  
  # Default behaviour: list
  $rusty->{data}->{errors}->{mode} = "mode $_ is not defined" if $_;
  &list
}



sub list {
  
  $rusty->{ttml} = "profile/photo-admin.ttml";
  
  $rusty->{data}->{photos} = $rusty->getAllPhotos($rusty->{core}->{'profile_id'})
    if $rusty->{core}->{'profile_id'};
  
  # Catch processing errors that redirect back to list..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  
  $rusty->process_template;
  $rusty->exit;
}


sub setmainphoto {
  
  unless ($rusty->{params}->{photo_id} > 0) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=setmainphoto"
                                     . "&success=0&reason=nophotoid" );
    $rusty->exit;
    
  }
  
  my $photo_profile_id = $rusty->getProfileIdFromPhotoId($rusty->{params}->{photo_id});
  
  if ($photo_profile_id && ($rusty->{core}->{'profile_id'} != $photo_profile_id)) {
    
    warn "user trying to set main photo on photo that does not belong to them: "
       . "user_id $rusty->{core}->{'user_id'} setting "
       . "photo_id $rusty->{params}->{photo_id} "
       . "which belongs to user_id $photo_profile_id";
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=setmainphoto"
                                       . "&success=0&reason=mismatch" );
    $rusty->exit;
    
  }
  
  $query = <<ENDSQL
UPDATE `user~profile` up
INNER JOIN `user~profile~photo` upp ON upp.profile_id = up.profile_id
SET up.main_photo_id = upp.photo_id
WHERE up.profile_id = ?
  AND upp.photo_id = ?
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  my $rows = $sth->execute($rusty->{core}->{'profile_id'}, $rusty->{params}->{photo_id});
  $sth->finish;
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=setmainphoto"
                                     . "&success="
                                     . ($rows eq '0E0' ? "0&reason=badphotoid" : "1") );
  $rusty->exit;
  
}


sub delete {
  
  unless ($rusty->{params}->{photo_id} > 0) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=delete"
                                     . "&success=0&reason=nophotoid" );
    $rusty->exit;
    
  }
  
  my $photo_profile_id = $rusty->getProfileIdFromPhotoId($rusty->{params}->{photo_id});
  
  if ($photo_profile_id && ($rusty->{core}->{'profile_id'} != $photo_profile_id)) {
    
    warn "user trying to delete a photo that does not belong to them: "
       . "user_id $rusty->{core}->{'user_id'} deleting "
       . "photo_id $rusty->{params}->{photo_id} "
       . "which belongs to user_id $photo_profile_id";
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=delete"
                                       . "&success=0&reason=mismatch" );
    $rusty->exit;
    
  }
  
  # Create a deleted photo directory for this user.
  my $photo_profile_name = $rusty->getProfileNameFromProfileId($photo_profile_id);
  my $photo_profile_directory = $rusty->photo_upload_directory . "/$photo_profile_name";
  mkdir($photo_profile_directory . "/del", 0777)
    unless -d ("$photo_profile_directory/del");
  die "cannot create profile deleted photo directory: $photo_profile_directory/del"
    unless -d ("$photo_profile_directory/del");
  
  # Delete the resized and both thumbnailed versions of the image.
  my $photo_info = $rusty->getPhotoInfo($rusty->{params}->{photo_id});
  unlink "$photo_profile_directory/$photo_info->{resized_filename}"
    or warn "could not delete profile resized photo: $photo_info->{resized_filename}";
  unlink "$photo_profile_directory/$photo_info->{thumbnail_filename}"
    or warn "could not delete profile thumbnailed photo: $photo_info->{thumbnail_filename}";
  unlink "$photo_profile_directory/$photo_info->{thumbnail_nocrop_filename}"
    or warn "could not delete profile thumbnail (no crop) photo: $photo_info->{thumbnail_nocrop_filename}";
  rename "$photo_profile_directory/$photo_info->{filename}",
         "$photo_profile_directory/del/$photo_info->{filename}"
    or warn "could not move profile original photo to deleted folder: $photo_info->{thumbnail_filename}";
  
  $query = <<ENDSQL
UPDATE `user~profile~photo`
SET deleted_date = NOW(),
    resized_filename = NULL,
    thumbnail_filename = NULL,
    thumbnail_nocrop_filename = NULL,
    tnnc_width = NULL, tnnc_height = NULL,
    filename = CONCAT("del/",filename)
WHERE photo_id = ?
LIMIT 1
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  my $rows = $sth->execute($rusty->{params}->{photo_id});
  $sth->finish;
  
  if (!$rows || $rows eq '0E0') {
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=delete"
                                       . "&success=0&reason=badphotoid" );
    $rusty->exit;
    
  }
  
  # Call to get main photo will sort out which is
  # the default photo now, even if there are no photos (will set it to NULL)
  $rusty->getMainPhoto($rusty->{core}->{'profile_id'}); 
  
  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=delete"
                                     . "&success=1" );
  $rusty->exit;
  
}


sub editcaption {
  
  $rusty->{ttml} = "profile/photo-admin-caption.ttml";
  
  unless ($rusty->{params}->{photo_id} > 0) {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=editcaption"
                                     . "&success=0&reason=nophotoid" );
    $rusty->exit;
    
  }
  
  my $photo_info = $rusty->getPhotoInfo($rusty->{params}->{photo_id});
  
  if ($photo_info->{'profile_id'} &&
      ($photo_info->{'profile_id'} != $rusty->{core}->{'profile_id'})) {
    
    warn "user trying to edit a photo caption that does not belong to them: "
       . "user_id $rusty->{core}->{'user_id'} editing "
       . "photo_id $rusty->{params}->{photo_id} "
       . "which belongs to user_id $photo_info->{'profile_id'}";
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=editcaption"
                                       . "&success=0&reason=mismatch" );
    $rusty->exit;
    
  }
  
  if ($rusty->{params}->{submitting}) {
    
    $query = <<ENDSQL
UPDATE `user~profile~photo`
SET caption = ?
WHERE photo_id = ?
LIMIT 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    my $rows = $sth->execute($rusty->{params}->{caption}, $rusty->{params}->{photo_id});
    $sth->finish;
    
    if (!$rows || $rows eq '0E0') {
      print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                         . "?mode=list&prev_action=editcaption"
                                         . "&success=0&reason=badphotoid" );
      $rusty->exit;
    }
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=editcaption"
                                       . "&success=1" );
    $rusty->exit;
    
  }
  
  $rusty->{data}->{photo_info} = $photo_info;
  
  $rusty->process_template;
  $rusty->exit;
  
}

