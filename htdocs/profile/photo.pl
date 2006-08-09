#!/usr/bin/perl -T
# Script to call if you want to show a photo - 
# takes photo id as a param and sends out the file info.. Lovely.
use strict;

use lib '../../lib';

use warnings qw( all );

no warnings qw( uninitialized );

use CarpeDiem;

use rusty;

my $rusty = rusty->new;

$rusty->benchmark->start('photo.pl');

# Connect to db

my ($dbh, $query, $sth);

$dbh = $rusty->DBH();

# Set autoflush and binary output for images

$| = 1;

binmode STDOUT;

our ($DEFAULT_PICTURE, $PENDING_PICTURE, $ADULT_PICTURE);

# this doesn't pretend to stop people from right-click downloading photos
# it stops the not-logged-in from guessing the filename of full size images
# given a thumbnail. it is still faaairly obvious that you just stick f=1
# on the end of the url to get a big version, but the script will ignore you
# if you do that and arent logged in (you'll get the thumbnail anyway)

# this used to return the question-mark-face-guy to anyone who linked
# directly to the image rather than linking through the website
# but then, people will probably send the direct links to each other in
# a "what do you think of him?" kind of way.

my $photo_id = $rusty->{params}->{id};

my $fullsize = $rusty->{params}->{f};
my $adminmode = $rusty->{params}->{a};
my $thumbnail_nocrop = $rusty->{params}->{nc};

my ($profile_id, $pornpass);

if ($rusty->{core}->{'user_id'}) {
  
  $query = <<ENDSQL
SELECT up.profile_id
#       ui.user_id
FROM `user~profile` up
#LEFT JOIN `user~info` ui ON ui.user_id = up.user_id
#                        AND ui.pornpass_expiry > NOW()
WHERE up.user_id = ?
LIMIT 1
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute($rusty->{core}->{'user_id'});
  ($profile_id, $pornpass) = $sth->fetchrow_array;
  $sth->finish;
}

$query = <<ENDSQL
SELECT upp.profile_id, u.profile_name,
       upp.resized_filename AS filename,
       upp.thumbnail_filename,
       upp.thumbnail_nocrop_filename,
       upp.deleted_date, upp.checked_date, upp.adult
FROM `user~profile~photo` upp
INNER JOIN `user~profile` up ON up.profile_id = upp.profile_id
INNER JOIN `user` u ON u.user_id = up.user_id
WHERE upp.photo_id = ?
LIMIT 1
ENDSQL
;

$sth = $rusty->DBH->prepare_cached($query);
$sth->execute($photo_id);
my $photo_info = $sth->fetchrow_hashref;
$sth->finish;


# This was a nice little test.. which resulted in:
# 1000 trials of photo.pl-query-joined (1.365s total), 1.365ms/trial
# 1000 trials of photo.pl-query-notjoined (2.699s total), 2.699ms/trial
#my $photo_info = $sth->fetchrow_hashref;
#
#foreach (1..1000) {
#  $rusty->benchmark->start('photo.pl-query-joined');
#  $query = <<ENDSQL
#SELECT upp.profile_id, u.profile_name,
#       upp.resized_filename AS filename,
#       upp.thumbnail_filename,
#       upp.checked_date, upp.adult
#FROM `user~profile~photo` upp
#INNER JOIN `user~profile` up ON up.profile_id = upp.profile_id
#INNER JOIN `user` u ON u.user_id = up.user_id
#WHERE upp.photo_id = ?
#LIMIT 1
#ENDSQL
#;
#  
#  $sth = $rusty->DBH->prepare_cached($query);
#  $sth->execute($photo_id);
#  $photo_info = $sth->fetchrow_hashref;
#  $sth->finish;
#  $rusty->benchmark->stop('photo.pl-query-joined');
#}
#
#foreach (1..1000) {
#  $rusty->benchmark->start('photo.pl-query-notjoined');
#  $query = <<ENDSQL
#SELECT upp.profile_id,
#       upp.resized_filename AS filename,
#       upp.thumbnail_filename,
#       upp.checked_date, upp.adult
#FROM `user~profile~photo` upp
#WHERE upp.photo_id = ?
#LIMIT 1
#ENDSQL
#;
#  $sth = $rusty->DBH->prepare_cached($query);
#  $sth->execute($photo_id);
#  $photo_info = $sth->fetchrow_hashref;
#  $sth->finish;
#  $query = <<ENDSQL
#SELECT up.user_id
#FROM `user~profile` up
#WHERE up.profile_id = ?
#LIMIT 1
#ENDSQL
#;
#  $sth = $rusty->DBH->prepare_cached($query);
#  $sth->execute($photo_info->{'profile_id'});
#  my ($rusty->{core}->{'user_id'}) = $sth->fetchrow;
#  $sth->finish;
#  $query = <<ENDSQL
#SELECT u.profile_name
#FROM `user` u
#WHERE u.user_id = ?
#LIMIT 1
#ENDSQL
#;
#  $sth = $rusty->DBH->prepare_cached($query);
#  $sth->execute($rusty->{core}->{'user_id'});
#  ($photo_info->{profile_name}) = $sth->fetchrow;
#  $sth->finish;
#  $rusty->benchmark->stop('photo.pl-query-notjoined');
#}

unless ($fullsize) { # If fullsize pic requested, leave filename as is.
  if ($thumbnail_nocrop) { # Elsif no crop requested, give thumbnail with no cropping.
    $photo_info->{filename} = $photo_info->{thumbnail_nocrop_filename};
  } else { # Else give cropped 100x100 thumbnail.
    $photo_info->{filename} = $photo_info->{thumbnail_filename};
  }
}
my $photo_upload_directory = $rusty->photo_upload_directory;

# This will be a reference to the global cache for 
# each of our default images.. (For mod_perl speediness!)
my $cached_picture;

my $filename;

if ($photo_info->{deleted_date}) {
  
  #Someone is trying to view a deleted photo! How odd..
  warn "photo requested is marked as deleted: '$photo_info->{filename}'";
  $filename = $photo_upload_directory . "/" . "default.png";
  $cached_picture = \$DEFAULT_PICTURE;
  
} elsif ($photo_info->{filename}) {
  
  $photo_info->{filename} = $photo_upload_directory
                          . "/" . $photo_info->{profile_name}
                          . "/" . $photo_info->{filename};
  
  # If the photo does not exist (should not happen),
  # leave them with the 'no photos' icon and warn someone!
  if (!-e $photo_info->{filename}) {
    
    warn "photo not found for user: '$photo_info->{filename}'";
    $filename = $photo_upload_directory . "/" . "default.png";
    $cached_picture = \$DEFAULT_PICTURE;
    
  # If the current user has paid to see all photos or is viewing
  # one of their own photos in admin mode, let them see it!
  } elsif ($pornpass
      || ($adminmode && ($profile_id == $photo_info->{'profile_id'}))) {
    
    $filename = $photo_info->{filename};
    
  } elsif ($photo_info->{adult}) {
    
    $filename = $photo_upload_directory
              . "/" . "adult.png";
    $cached_picture = \$ADULT_PICTURE;
    
  } elsif (!$photo_info->{checked_date}) {
    
    $filename = $photo_upload_directory
              . "/" . "pending.png";
    $cached_picture = \$PENDING_PICTURE;
    
  } else {
    
    $filename = $photo_info->{filename};
    
  }
} else {
  
  $filename = $photo_upload_directory . "/" . "default.png";
  $cached_picture = \$DEFAULT_PICTURE;
  
}

my $mime_types = {
  jpeg => "image/jpeg", #is it worth doing 'pjpeg'?
  jpg  => "image/jpeg",
  jpe  => "image/jpeg",
  png  => "image/png",
  gif  => "image/gif",
  bmp  => "application/x-MS-bmp",
};

if ($filename =~ /\.([^\.]+)$/o) {
  my $extension = lc($1);
  if (my $mime_type = $mime_types->{$extension}) {
    
    print $rusty->CGI->header("Content-type: $mime_type");
    
  } else {
    
    warn "mime type not found in list for extension '$extension' (filename: '$filename')";
    
  }
} else {
  
  warn "no extension was found for file '$filename'";
}


binmode STDOUT;
$| = 1;

# If this is one of our chacheable pictures and if we have
# already cached it (in a previous mod_perl call for this photo)
if (ref($cached_picture) and defined($$cached_picture)) {
  
  # Print the cached version!
  #warn "printing cached version of $filename";
  print $$cached_picture;
  
} else  {
  
  # Read the file for the first time..
  open IMAGE, $filename or die "$filename: $!";
  binmode IMAGE;
  my $holdTerminator = $/;
  undef $/;
  
  # If this is a cacheable picture
  if (ref($cached_picture)) {
    
    # Cache it this time!
    #warn "printing and caching $filename";
    $$cached_picture = <IMAGE>;
    print $$cached_picture;
    
  } else {
    
    # Or just chuck it out like normal..
    #warn "printing $filename";
    print <IMAGE>;
    
  }
  
  $/ = $holdTerminator;
  close IMAGE;
  
}


$rusty->benchmark->stop('photo.pl');
$rusty->exit;
