#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Admin;

$rusty = rusty::Admin->new;

$_ = $rusty->{params}->{mode};
SWITCH:
{
  &processphotos, last SWITCH if /^processphotos$/;
  &list, last SWITCH if /^list$/;
  
  # Default behaviour: list
  $rusty->{data}->{errors}->{mode} = "mode $_ is not defined" if $_;
  &list
}



sub list {
  
  $rusty->{ttml} = "profile/photo-admin.ttml";
  
  $rusty->{data}->{photos} = $rusty->getAllPhotosPendingApproval()
  
  # Catch processing errors that redirect back to list..
  $rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
  $rusty->{data}->{success} = $rusty->{params}->{success};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  
  $rusty->process_template;
  $rusty->exit;
}


sub processphotos {
  
  unless ($rusty->{params}->{photo_id} > 0) {
    
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
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
    
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
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
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?mode=list&prev_action=delete"
                                       . "&success=0&reason=badphotoid" );
    $rusty->exit;
    
  }
  
  # Call to get main photo will sort out which is
  # the default photo now, even if there are no photos (will set it to NULL)
  $rusty->getMainPhoto($rusty->{core}->{'profile_id'}); 
  
  print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                     . "?mode=list&prev_action=delete"
                                     . "&success=1" );
  $rusty->exit;
  
}

