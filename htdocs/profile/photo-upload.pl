#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

use Image::Magick;

use vars qw($rusty $query $sth);

$rusty = rusty::Profiles->new;

$CGI::POST_MAX = $rusty->max_file_size;
$CGI::POST_MAX += 0; # keep -w happy;


use constant MAX_IMAGE_WIDTH => 800;
use constant MAX_IMAGE_HEIGHT => 600;
use constant THUMB_WIDTH => 100;
use constant THUMB_HEIGHT => 100;



if (!$rusty->{core}->{'user_id'}) {
  $rusty->redirectToLoginPage($rusty->{core}->{'self_url'});
  $rusty->exit;
}

$query = <<ENDSQL
SELECT user_id, profile_name, profile_id,
       updated, main_photo_id
FROM `user_profile`
WHERE user_id = ?
LIMIT 1
ENDSQL
;
$sth = $rusty->DBH->prepare_cached($query);
$sth->execute($rusty->{core}->{'user_id'});
my $profile = $sth->fetchrow_hashref;
$sth->finish;
$rusty->{data}->{profile} = $profile;

if (!$rusty->{core}->{profile_info}->{'updated'}) {
  print $rusty->redirect( -url => "/profile/account.pl" );
  $rusty->exit;
} elsif ($rusty->{core}->{profile_info}->{'deleted_date'}) {
  print $rusty->redirect( -url => "/profile/account.pl?deleted=1" );
  $rusty->exit;
}

$rusty->{data}->{num_photos} = $rusty->getPhotoCount($rusty->{core}->{profile_id});

$rusty->{ttml} = "profile/photo-upload.ttml";


if ($rusty->{data}->{num_photos} >= 50) {
  $rusty->process_template;
  $rusty->exit;
}

unless ($rusty->{params}->{upload} == 1) {
  $rusty->{data}->{error} = $rusty->{params}->{error};
  $rusty->{data}->{reason} = $rusty->{params}->{reason};
  $rusty->{data}->{uploaded} = $rusty->{params}->{uploaded};
  $rusty->{data}->{photo_info} = $rusty->getPhotoInfo($rusty->{params}->{uploaded});
  $rusty->{data}->{msg} = $rusty->{params}->{msg};
  
  $rusty->process_template;
  $rusty->exit;
}




my $photo;
$photo->{uploaded_filehandle} = $rusty->CGI->upload('photo');
$photo->{uploaded_file} = $rusty->CGI->param('photo');
#$photo->{uploaded_file} = $rusty->{params}->{photo};
#warn "uploaded filehandle: $photo->{uploaded_filehandle}";
#warn "uploaded file: $photo->{uploaded_file}";
if (!$photo->{uploaded_file}) {
  print $rusty->redirect( -url => "/profile/photo-upload.pl"
                                     . "?error=1&reason=nouploadfile" );
  $rusty->process_template;
  $rusty->exit;
}

($photo->{original_filename} = $photo->{uploaded_file}) =~ s/^.*[\/\\]([^\/\\]*)$/$1/o;




# Check for profile's image directory and create it if it doesn't exist
# Also make dir for the resized images and the full, original images..

mkdir($rusty->photo_upload_directory . "/" . $profile->{profile_name}, 0777)
  unless -d ($rusty->photo_upload_directory . "/" . $profile->{profile_name});
  
die "cannot create profile photo directory: "
  . $rusty->photo_upload_directory . "/" . $profile->{profile_name}
  unless -d ($rusty->photo_upload_directory . "/" . $profile->{profile_name});
  
mkdir($rusty->photo_upload_directory . "/$profile->{profile_name}/rs", 0777)
  unless -d ($rusty->photo_upload_directory . "/$profile->{profile_name}/rs");
  
die "cannot create profile resized photo directory: "
  . $rusty->photo_upload_directory . "/$profile->{profile_name}/rs"
  unless -d ($rusty->photo_upload_directory . "/$profile->{profile_name}/rs");
  
mkdir($rusty->photo_upload_directory . "/$profile->{profile_name}/tn", 0777)
  unless -d ($rusty->photo_upload_directory . "/$profile->{profile_name}/tn");
  
die "cannot create profile photo thumbnail directory: "
  . $rusty->photo_upload_directory . "/$profile->{profile_name}/tn"
  unless -d ($rusty->photo_upload_directory . "/$profile->{profile_name}/tn");

mkdir($rusty->photo_upload_directory . "/$profile->{profile_name}/tnnc", 0777)
  unless -d ($rusty->photo_upload_directory . "/$profile->{profile_name}/tnnc");
  
die "cannot create profile photo thumbnail (no crop) directory: "
  . $rusty->photo_upload_directory . "/$profile->{profile_name}/tnnc"
  unless -d ($rusty->photo_upload_directory . "/$profile->{profile_name}/tnnc");



# Copy the file to a temp file before trying to fiddle with it
# This is nasty and wasteful but nevermind..  For some reason 
# it wasn't working when we asked our image processing (ImageMagick)
# to play with it directly from the temporary uploaded file.. =(
my $upload_tmp;
do { $upload_tmp = $rusty->photo_upload_directory
                 . "/$profile->{profile_name}/upload"
                 . int(rand(1000)) . ".tmp" }
  until (!-e $upload_tmp); # Until that filename does not already exist!

open UPLOADFILE, ">" . $upload_tmp or die $!;
binmode UPLOADFILE;
$photo->{bytes} = 0;
# Read in the file at 100kb at a time.
while (my $bytes_read = read($photo->{uploaded_file}, my $buff, 100240)) {
  $photo->{bytes} += $bytes_read;
  # This should never happen if CGI.pm is limiting it properly
  last if $photo->{bytes} > $rusty->max_file_size;
  binmode UPLOADFILE;
  print UPLOADFILE $buff;
}
close UPLOADFILE;

if ($photo->{bytes} == 0) {
  
  # If file uploaded was zero bytes
  unlink($upload_tmp);
  warn "file uploaded was <=0 bytes: " . $photo->{original_filename};
  print $rusty->redirect( -url => "/profile/photo-upload.pl"
                                     . "?error=1&reason=emptyuploadfile" );
  $rusty->exit;
  
} elsif ((stat $upload_tmp)[7] <= 0) {
  
  # If file created is zero bytes
  unlink($upload_tmp);
  warn "file created was <=0 bytes: " . $photo->{original_filename};
  print $rusty->redirect( -url => "/profile/photo-upload.pl"
                                     . "?error=1&reason=emptyserverfile" );
  $rusty->exit;
  
} elsif ($photo->{bytes} > $rusty->max_file_size) {
  
  # If file uploaded is greater than max allowed
  # This should never happen if CGI.pm is limiting it properly
  unlink($upload_tmp);
  warn "file created was over max file size allowed:" . $photo->{original_filename};
  print $rusty->redirect( -url => "/profile/photo-upload.pl"
                                     . "?error=1&reason=overmaxsize" );
  $rusty->exit;
}




# Read in the uploaded image.
my $uploaded = Image::Magick->new;
my $err = $uploaded->Read( $upload_tmp );
warn $err if $err;


# It seems that CGI just works out the MIME type based on the extension.
# Well, it is doing at the moment.. How stupid!  Maybe a firefox thing..  Yes it is!
# IE is silly in that it returns MIME types 'pjpeg' instead of 'jpeg' and
# 'x-png' instead of 'png' but at least it gives it based on the image and not just
# the extension like firefox!  hehehe..
# So we will get Image::Magick to determine the mime type much more accurately.
#my $mime_type = $rusty->CGI->uploadInfo($photo->{uploaded_file})->{'Content-Type'};
#warn "CGI MIME: $mime_type";

# There is no documentation on which of these two image::magick refs to use
# ($image->Get('mime') or $image->Get('MIME')) - the documentation
# says they do different things but it isn't clear what this difference
# is and they sound and seem to behave the same. So i am going to throw
# a warning if they are not the same just out of plain darn curiosity!
# And use 'mime' instead of 'MIME' - why not?
my $mime_type = $uploaded->Get('mime');
#warn "got mime type: $mime_type";
warn "mimes not the same (mime: '" . $mime_type . "', MIME: '"
   . $uploaded->Get('MIME') . "') for file: " . $photo->{original_filename}
      if $mime_type ne $uploaded->Get('MIME');
undef $uploaded;



# The first extension in these lists is also the one to use for files.
my $mime_extensions = {
  "image/jpeg" => [ "jpg", "jpeg", "jpe" ],
  "image/pjpeg" => [ "jpg", "jpeg", "jpe" ], # This is for IE! GRRR..
  "image/png" => [ "png" ],
  "image/x-png" => [ "png" ],
  "image/gif" => [ "gif" ],
};

unless (grep /^$mime_type$/, keys %$mime_extensions) {
  require URI::Escape;
  print $rusty->redirect( -url => "/profile/photo-upload.pl"
                                     . "?error=1&reason=unknownmimetype"
                                     . "&mime=" . URI::Escape::uri_escape($mime_type) );
  $rusty->process_template;
  $rusty->exit;
} else {
  $photo->{correct_extension} = ${$mime_extensions->{$mime_type}}[0];
}




if ($photo->{uploaded_file} !~ /\.([^\.]+)$/) {
  
  $rusty->{data}->{msg} = "File '$photo->{original_filename}' had no extension "
                        . "but the file contains valid image data";
  
} else {
  
  my $extension = lc($1);
  my @mime_types_expected_from_extension;
  foreach (keys %$mime_extensions) {
    push @mime_types_expected_from_extension, $_
      if grep /^$extension$/, @{$mime_extensions->{$_}}
  }
  
  #warn "extension possible MIME: "
  #   . join ", ", @mime_types_expected_from_extension;
     
  if (!@mime_types_expected_from_extension) {
    
    $rusty->{data}->{msg} = "Extension '.$extension' "
                          . "is not normally allowed nor correct for this file, "
                          . "but the file contains valid image data";
                          
  } elsif (!grep /^$mime_type$/, @mime_types_expected_from_extension) {
    
    $rusty->{data}->{msg} = "Extension '.$extension' "
                          . "is not correct for this file, "
                          . "but the file contains valid image data"
                          . " (mime type is '$mime_type' and the "
                          . "mime type(s) expected are '"
                          . join ("', '", @mime_types_expected_from_extension)
                          . "')";
                          
  }
  
}




# Create new filename
$photo->{local_filename} = $profile->{profile_name} . "~"
                         . sprintf("%04d_%02d_%02d\@%02d-%02d-%02d",
                                   (localtime)[5]+1900,
                                   (localtime)[4]+1,
                                   (localtime)[3,2,1,0]);

$photo->{local_filename} .= "~" while -e $rusty->photo_upload_directory . "/"
                                       . $profile->{profile_name} . "/"
                                       . $photo->{local_filename} . "."
                                       . $photo->{correct_extension};
$photo->{local_resized_filename} = "rs/" . $photo->{local_filename}
                                 . "-rs.jpg";
$photo->{local_thumb_filename} = "tn/" . $photo->{local_filename}
                               . "-tn.jpg";
$photo->{local_thumb_nocrop_filename} = "tnnc/" . $photo->{local_filename}
                               . "-tnnc.jpg";
$photo->{local_filename} = $photo->{local_filename} . "."
                         . $photo->{correct_extension};

$photo->{local_filepath} = $rusty->photo_upload_directory . "/"
                         . $profile->{profile_name} . "/"
                         . $photo->{local_filename};
$photo->{local_resized_filepath} = $rusty->photo_upload_directory . "/"
                                 . $profile->{profile_name} . "/"
                                 . $photo->{local_resized_filename};
$photo->{local_thumb_filepath} = $rusty->photo_upload_directory . "/"
                               . $profile->{profile_name} . "/"
                               . $photo->{local_thumb_filename};
$photo->{local_thumb_nocrop_filepath} = $rusty->photo_upload_directory . "/"
                               . $profile->{profile_name} . "/"
                               . $photo->{local_thumb_nocrop_filename};
                               



rename( $upload_tmp, $photo->{local_filepath} );




# Read in the original image (now that we've moved it around).
my $resized = Image::Magick->new;
$err = $resized->Read( $photo->{local_filepath} );
warn "$err" if "$err";

if ($err+0 > 1) {
  warn "animated gif uploaded! taking first image only: "
     . $photo->{local_filepath};
  @$resized = ${$resized}[0];
}

# Create clones of the original object before we go off playing with it :)
my $thumbnailed = $resized->Clone();
my $thumbnail_nocrop = $resized->Clone();

# Resize larger images without mashing them up
# (to within a the specified geometry, maintaining aspect ratio
#  but only if the image is larger than the specified geometry).
$err = $resized->Resize( geometry => '>' . MAX_IMAGE_WIDTH
                                   . 'x' . MAX_IMAGE_HEIGHT );
warn $err if $err;



######################################
#
# Add watermark
# Taken out for now until we can make a
# new watermark for the new site name/branding!
#my $overlay;
#if (!$overlay) {
#  $overlay = Image::Magick->new;
#  $overlay->Read( 'png:' . $rusty->photo_upload_directory . '/watermark.png' );
#}
#$resized->Composite( image => $overlay, compose => 'over', gravity => 'SouthWest');
#
######################################



$err = $resized->Write( filename    => $photo->{local_resized_filepath},
#$err = $overlay->Write( filename    => $photo->{local_resized_filepath},
                        compression => "JPEG",
                        quality     => 75 );
warn $err if $err;


$photo->{width} = $thumbnailed->Get('columns');
$photo->{height} = $thumbnailed->Get('rows');

# Crop the image so it fits our desired aspect ratio and then resize it
# (this way the image does not look funny, we just remove the edges!)
my $aspect_ratio = $photo->{width} / $photo->{height};
my $target_aspect_ratio = THUMB_WIDTH / THUMB_HEIGHT;

if ($aspect_ratio > $target_aspect_ratio) {
  # If the image is too wide for the aspect ratio,
  # crop the width so that it fits aspect ratio.
  #warn "aspect ratio ($aspect_ratio) > target aspect ratio ($target_aspect_ratio)";
  my $new_width = $photo->{height} * $target_aspect_ratio;
  #warn "setting width to $new_width";
  $err = $thumbnailed->Crop( width => $new_width,
                             x     => int(($photo->{width} - $new_width) / 2) );
  warn $err if $err;
} elsif ($aspect_ratio < $target_aspect_ratio) {
  # If the image is too tall for the aspect ratio,
  # crop the height so that it fits aspect ratio.
  #warn "aspect ratio ($aspect_ratio) < target aspect ratio ($target_aspect_ratio)";
  my $new_height = $photo->{width} / $target_aspect_ratio;
  #warn "setting height to $new_height";
  $err = $thumbnailed->Crop( height => $new_height,
                             y      => int(($photo->{height} - $new_height) / 2) );
  warn $err if $err;
}
# Now create the thumbnail from the cropped image.
# '!' - Resize to width and height exactly, losing original aspect ratio.
$err = $thumbnailed->Thumbnail( geometry => THUMB_WIDTH.'x'.THUMB_HEIGHT.'!');
warn $err if $err;

$err = $thumbnailed->Write( filename    => $photo->{local_thumb_filepath},
                            compression => "JPEG",
                            quality     => 90 );
warn $err if $err;

# Now make another thumbnail which doesn't have any cropping, just shrinkage
# and maintains the original aspect ratio (longest side will be 100px or less).
# '>' = Resize only if the image is greater than the geometry specification.
$err = $thumbnail_nocrop->Thumbnail( geometry => THUMB_WIDTH.'x'.THUMB_HEIGHT.'>');
warn $err if $err;

$err = $thumbnail_nocrop->Write( filename    => $photo->{local_thumb_nocrop_filepath},
                                 compression => "JPEG",
                                 quality     => 90 );
warn $err if $err;


# Calculate filesize in kilobytes - if file is greater than zero
# but less than 1KB then make it 1KB (otherwise someone could
# upload unlimited 0.9KB files and kill our little server..
# (unless we limit the number of photos allowed, but we are not
# going to do that just yet.. Why not? Because it's late. Baah!
if ($photo->{bytes} > 1024) {
  $photo->{kilobytes} = int($photo->{bytes} / 1024);
} elsif ($photo->{bytes} > 0) {
  $photo->{kilobytes} = 1;
}

$query = <<ENDSQL
INSERT INTO `user_profile_photo`
( profile_id, filename,
  resized_filename, thumbnail_filename, original_filename,
  kilobytes, width, height,
  thumbnail_nocrop_filename, tnnc_width, tnnc_height,
  caption, uploaded_date )
VALUES ( ?, ?,
         ?, ?, ?,
         ?, ?, ?,
         ?, ?, ?,
         ?, NOW() )
ENDSQL
;
$sth = $rusty->DBH->prepare_cached($query);
$sth->execute( $profile->{'profile_id'},
               $photo->{local_filename},
               $photo->{local_resized_filename},
               $photo->{local_thumb_filename},
               $photo->{original_filename},
               $photo->{kilobytes},
               $photo->{width}, $photo->{height},
               $photo->{local_thumb_nocrop_filename},
               $thumbnail_nocrop->Get('width'),
               $thumbnail_nocrop->Get('height'),
               $rusty->{params}->{caption} );
$sth->finish;

$rusty->{data}->{photo_id} = $rusty->DBH->{mysql_insertid};

# If we didn't previously have a main photo set in the profile, set it to this one!
if (!$profile->{main_photo_id}) {
  $query = <<ENDSQL
UPDATE `user_profile`
SET main_photo_id = ? WHERE profile_id = ?
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute($rusty->{data}->{photo_id}, $profile->{'profile_id'});
  $sth->finish;
}

require Email; #qw( send_email create_html_from_text );
require URI::Escape; # 'uri_escape';

# Send out email to a support dept.

my $current_time = localtime();

my $textmessage = <<ENDMSG
  =============
  Date:         $current_time
  User ID:      $rusty->{core}->{user_id}
  Email:        $rusty->{core}->{email}
  Real Name:    $rusty->{core}->{user_info}->{real_name}
  Profile Name: $rusty->{core}->{profile_name}
  Photo ID:     $rusty->{data}->{photo_id}
  =============
ENDMSG
;
$textmessage .= "\n  Caption:  " . $rusty->{params}->{caption}
              . "\n  FileName: " . $photo->{original_filename}
              . "\n  Thumb:    http://$rusty->{core}->{server_name}/photos/$rusty->{core}->{profile_name}/"
              . URI::Escape::uri_escape($photo->{local_thumb_filename})
              . "\n  NoCrop:   http://$rusty->{core}->{server_name}/photos/$rusty->{core}->{profile_name}/"
              . URI::Escape::uri_escape($photo->{local_thumb_nocrop_filename})
              . "\n  Resized: http://$rusty->{core}->{server_name}/photos/$rusty->{core}->{profile_name}/"
              . URI::Escape::uri_escape($photo->{local_resized_filename});
$textmessage .= <<ENDMSG
  
  APPROVE?  http://$rusty->{core}->{server_name}/admin/photo-approvals.pl?mode=approve\&photo_id=$rusty->{data}->{photo_id}\&profile_id=$rusty->{core}->{profile_id}
  ADULT?    http://$rusty->{core}->{server_name}/admin/photo-approvals.pl?mode=mark_as_adult\&photo_id=$rusty->{data}->{photo_id}\&profile_id=$rusty->{core}->{profile_id}
  REJECT?   http://$rusty->{core}->{server_name}/admin/photo-approvals.pl?mode=reject\&photo_id=$rusty->{data}->{photo_id}\&profile_id=$rusty->{core}->{profile_id}
  See all photos requiring approval:   http://$rusty->{core}->{server_name}/admin/photo-approvals.pl
ENDMSG
;

my $htmlmessage = Email::create_html_from_text($textmessage);
$htmlmessage .= <<ENDHTML
<img src="http://$rusty->{core}->{server_name}/photos/$rusty->{core}->{profile_name}/$photo->{local_resized_filename}" />
ENDHTML
;
    
Email::send_email( 'To'          => [ "support\@backpackingbuddies.com", ],
                   'Reply-To'    => [ "$rusty->{core}->{user_info}->{real_name} ($rusty->{core}->{profile_name}) <$rusty->{core}->{email}>", ],
                   'Subject'     => "Photo uploaded",
                   'TextMessage' => $textmessage,
                   'HtmlMessage' => $htmlmessage );


print $rusty->redirect( -url => $rusty->CGI->url(-relative=>1)
                                   . "?uploaded="
                                   . $rusty->{data}->{photo_id}
                                   . ($rusty->{data}->{msg} ? "&msg="
                                      . URI::Escape::uri_escape($rusty->{data}->{msg})
                                      : '')
                            );
#$rusty->{data}->{uploaded} = 1;
#$rusty->process_template;

$rusty->exit;
