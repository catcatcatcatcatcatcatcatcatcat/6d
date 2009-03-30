package rusty::Profiles::Photo;

use Image::Magick;

use strict;

use warnings qw( all );

no warnings qw( uninitialized );

use CarpeDiem;




sub getProfileIdFromPhotoId($) {
  
  my $self = shift;
  
  my $photo_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT profile_id
FROM `user~profile~photo` upp
WHERE upp.photo_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($photo_id);
  my ($profile_id) = $sth->fetchrow_array;
  $sth->finish;
  
  return $profile_id;
  
}


sub getPhotoCount($) {
  
  my $self = shift;

  my $profile_id = shift;

  my $dbh = $self->DBH;

  my $query = <<ENDSQL
SELECT COUNT(*)
FROM `user~profile~photo` photo
WHERE photo.profile_id = ?
  AND deleted_date IS NULL
GROUP BY profile_id
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my ($total) = $sth->fetchrow_array;
  $sth->finish;
  
  return int($total);

}


sub getCheckedPhotoCount($) {
  
  my $self = shift;

  my $profile_id = shift;

  my $dbh = $self->DBH;

  my $query = <<ENDSQL
SELECT COUNT(*)
FROM `user~profile~photo` photo
WHERE photo.profile_id = ?
  AND checked_date IS NOT NULL
  AND deleted_date IS NULL
GROUP BY profile_id
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my ($total) = $sth->fetchrow_array;
  $sth->finish;
  
  return int($total);

}


# checks if this profile has adult photos in it
sub hasAdultPics($) {

  my $self = shift;

  my $profile_id = shift;

  my $dbh = $self->DBH;

  my $query = <<ENDSQL
SELECT COUNT(*)
FROM `user~profile~photo`
WHERE profile_id = ?
  AND adult = 1
  AND deleted_date IS NULL
GROUP BY profile_id
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my ($total) = $sth->fetchrow_array;
  $sth->finish;
  
  return $total;
}


sub hasAdultPass() {
  
  # Takes user_id as argument:
  # If valid, returns the number of mins left on someone's adult pass,
  # If expired, returns -1,
  # If never purchased, returns 0.
  
  my $self = shift;
  
  my $user_id = shift;
  
  my $dbh = $self->DBH;
  
  return 0;
  
  my $query = <<ENDSQL
SELECT IF(adultpass_expiry > NOW(),
          (UNIX_TIMESTAMP(adultpass_expiry) - UNIX_TIMESTAMP()) / 60,
          -1)
FROM `user~info`
WHERE user_id = ?
AND adultpass_expiry IS NOT NULL
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($user_id);
  my ($mins_left) = $sth->fetchrow_array;
  $sth->finish;
  
  $mins_left ||= 0;
  return $mins_left;
}


sub getMainPhoto($) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $dbh = $self->DBH;
  
  # Get the "official" main photo if possible,
  # otherwise get earliest uploaded photo.
  
  my $query = <<ENDSQL
SELECT SQL_CACHE up.profile_name,
       upp.photo_id, up.main_photo_id,
       upp.filename, upp.resized_filename, upp.thumbnail_filename, upp.original_filename,
       upp.kilobytes, upp.width, upp.height,
       upp.thumbnail_nocrop_filename, upp.tnnc_width, upp.tnnc_height,
       upp.caption,
       DATE_FORMAT(upp.uploaded_date, '%d/%m/%y %H:%i') AS uploaded_date,
       DATE_FORMAT(upp.checked_date, '%d/%m/%y %H:%i') AS checked_date,
       upp.adult, upp.total_visit_count
FROM `user~profile~photo` upp
LEFT JOIN `user~profile` up ON up.main_photo_id = upp.photo_id
WHERE upp.profile_id = ?
  AND upp.deleted_date IS NULL
ORDER BY up.main_photo_id DESC, upp.uploaded_date ASC
LIMIT 1
ENDSQL
;
  # Only use the sql result cache if we're logged in and
  # requesting our own photo (on every request for a logged-in user)
  # Otherwise, it's a profile view or simply irrelevant.
  if (!$self->{core}->{'profile_id'} ||
      $self->{core}->{'profile_id'} != $profile_id) {
    $query =~ s/^SELECT SQL_CACHE /SELECT /o;
  }
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my $photo_info = $sth->fetchrow_hashref;
  $sth->finish;
  
  if (!$photo_info->{photo_id}) {
    
    # No photos at all? then give them mr-question-mark-face
    #$photo_info->{filename} = "";
    #$photo_info->{thumbnail} = "/profile/photo.pl";
    #$photo_info->{thumbnail} = "/photos/default.png";
    #$photo_info->{adult} = 0;
    # There is no filename so checked_date will not be
    # checked anymore (logic changed)..
    #$photo_info->{checked_date} = 1;
            
    # This should be done via the photo admin but we'll do it
    # here just to be safe! - Set main_photo_id to NOTHING :)
    $query = <<ENDSQL
UPDATE `user~profile` SET main_photo_id = NULL
WHERE profile_id = ?
LIMIT 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($profile_id);
    $sth->finish;
    
    return $photo_info;
    
  } elsif (!$photo_info->{main_photo_id}) {
    
    # If no main photo found,
    # set this earliest pic to be the main photo.
    $query = <<ENDSQL
UPDATE `user~profile` SET main_photo_id = ?
WHERE profile_id = ?
LIMIT 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($photo_info->{photo_id}, $profile_id);
    $sth->finish;
  }
  
  #$photo_info->{thumbnail} = "/profile/photo.pl?id=$photo_info->{photo_id}";
  #$photo_info->{filename} = "/profile/photo.pl?id=$photo_info->{photo_id}&f=1";
  #$photo_info->{thumbnail} = "/photos/$photo_info->{profile_name}/$photo_info->{thumbnail_filename}";
  #$photo_info->{thumbnail_nocrop} = "/photos/$photo_info->{profile_name}/$photo_info->{thumbnail_nocrop_filename}";
  #$photo_info->{filename} = "/photos/$photo_info->{profile_name}/$photo_info->{resized_filename}";
  
  return $photo_info;
}


sub getAllPhotos($) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT photo_id,
       filename, resized_filename, thumbnail_filename, original_filename,
       kilobytes, width, height,
       thumbnail_nocrop_filename, tnnc_width, tnnc_height,
       caption,
       DATE_FORMAT(uploaded_date, '%d/%m/%y %H:%i') AS uploaded_date,
       DATE_FORMAT(checked_date, '%d/%m/%y %H:%i') AS checked_date,
       adult, total_visit_count
FROM `user~profile~photo`
WHERE profile_id = ?
  AND deleted_date IS NULL
ORDER BY uploaded_date ASC
ENDSQL
;
#SELECT up.profile_name,
#       upp.photo_id,
#       upp.filename, upp.resized_filename, upp.thumbnail_filename, upp.original_filename,
#       upp.kilobytes, upp.width, upp.height,
#       upp.thumbnail_nocrop_filename, upp.tnnc_width, upp.tnnc_height,
#       upp.caption,
#       DATE_FORMAT(upp.uploaded_date, '%d/%m/%y %H:%i') AS uploaded_date,
#       DATE_FORMAT(upp.checked_date, '%d/%m/%y %H:%i') AS checked_date,
#       upp.adult, upp.total_visit_count
#FROM `user~profile~photo` upp
#LEFT JOIN `user~profile` up ON up.main_photo_id = upp.photo_id
#WHERE upp.profile_id = ?
#  AND upp.deleted_date IS NULL
#ORDER BY upp.uploaded_date ASC

  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id);
  my @photos = ();
  while (my $photo_info = $sth->fetchrow_hashref) {
    
    #$photo_info->{thumbnail} = "/photos/$photo_info->{profile_name}/$photo_info->{thumbnail_filename}";
    #$photo_info->{thumbnail_nocrop} = "/photos/$photo_info->{profile_name}/$photo_info->{thumbnail_nocrop_filename}";
    #$photo_info->{filename} = "/photos/$photo_info->{profile_name}/$photo_info->{resized_filename}";
    push @photos, $photo_info;
  }
  $sth->finish;
  
  return @photos ? \@photos : undef;
}


sub getPhotoInfo($) {
  
  my $self = shift;
  
  my $photo_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT photo_id,
       filename, resized_filename, thumbnail_filename, original_filename,
       kilobytes, width, height,
       thumbnail_nocrop_filename, tnnc_width, tnnc_height,
       caption,
       DATE_FORMAT(uploaded_date, '%d/%m/%y %H:%i') AS uploaded_date,
       DATE_FORMAT(checked_date, '%d/%m/%y %H:%i') AS checked_date,
       adult, deleted_date, total_visit_count
FROM `user~profile~photo`
WHERE photo_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($photo_id);
  my $photo_info = $sth->fetchrow_hashref;
  $sth->finish;
  
  return $photo_info;
}


sub profile_resize($) {
  
  my $self = shift;
  
  my $filename = shift;
  
  my $image = Image::Magick->new;
  
  $image->Read($filename);
  
  my $maxwidth = 800;
  my $maxheight = 600;
  
  $image = Image::Magick->new(magick=>'JPEG');
  
  my $width = $image->Get('columns');
  my $height = $image->Get('rows');
  
  if (($width > $maxwidth) || ($height > $maxheight)) {
  
  my $xratio = $maxheight / $height;
  my $yratio = $maxwidth / $width;
  
  my $ratio = ($xratio < $yratio) ? $xratio : $yratio;
  
  my $newwidth = int($width * $ratio);
  my $newheight = int($height * $ratio);
  
  $image->Scale( height => $newheight, width => $newwidth );
  
  }

  $image->Write($filename);
  
}


sub profile_thumbnail($) {

  my $self = shift;

  my $filename = shift;

  my $image = Image::Magick->new;

  $image->Read($filename);

  $image = Image::Magick->new(magick=>'JPEG');

  $image->Scale( height => '140', width => '140' );

  $image->Write($filename);

}




# The following function is mainly used for administrative purposes..
# so use with caution! :P
sub getAllPhotosPendingApproval($) {
  
  my $self = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT upp.photo_id, upp.profile_id, up.profile_name,
       upp.filename, upp.resized_filename, upp.thumbnail_filename, upp.original_filename,
       upp.kilobytes, upp.width, upp.height,
       upp.thumbnail_nocrop_filename, upp.tnnc_width, upp.tnnc_height,
       upp.caption,
  	   SEC_TO_TIME(UNIX_TIMESTAMP() - UNIX_TIMESTAMP(upp.uploaded_date)) AS elapsed_time_since_upload
FROM `user~profile~photo` upp
INNER JOIN `user~profile` up ON up.profile_id = upp.profile_id
WHERE upp.checked_date IS NULL
  AND upp.deleted_date IS NULL
ORDER BY upp.uploaded_date ASC
LIMIT 100
ENDSQL
;

  my $sth = $dbh->prepare_cached($query);
  $sth->execute();
  my @photos = ();
  while (my $photo_info = $sth->fetchrow_hashref) {
    push @photos, $photo_info;
  }
  $sth->finish;
  
  return @photos ? \@photos : undef;
}




sub getRecentlyApprovedPhotos($) {
  
  my $self = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT upp.photo_id, upp.profile_id, up.profile_name,
       upp.filename, upp.resized_filename, upp.thumbnail_filename, upp.original_filename,
       upp.kilobytes, upp.width, upp.height,
       upp.thumbnail_nocrop_filename, upp.tnnc_width, upp.tnnc_height,
       upp.caption,
  	   SEC_TO_TIME(UNIX_TIMESTAMP() - UNIX_TIMESTAMP(upp.checked_date)) AS elapsed_time_since_check
FROM `user~profile~photo` upp
INNER JOIN `user~profile` up ON up.profile_id = upp.profile_id
WHERE upp.checked_date IS NOT NULL
  AND upp.deleted_date IS NULL
ORDER BY upp.checked_date DESC
LIMIT 100
ENDSQL
;

  my $sth = $dbh->prepare_cached($query);
  $sth->execute();
  my @photos = ();
  while (my $photo_info = $sth->fetchrow_hashref) {
    push @photos, $photo_info;
  }
  $sth->finish;
  
  return @photos ? \@photos : undef;
}




1;
