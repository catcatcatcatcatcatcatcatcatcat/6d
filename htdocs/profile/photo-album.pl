#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

use vars qw($rusty $query $sth);

$rusty = rusty::Profiles->new;



$rusty->{ttml} = "profile/photo-album.ttml";

$rusty->{data}->{'error'} = $rusty->{params}->{'error'};
$rusty->{data}->{'profile_id'} = $rusty->{params}->{'profile_id'};

if (!$rusty->{data}->{'profile_id'}) {
  # No profile id specified..
  print $rusty->redirect( -url => "/index.pl" );
  $rusty->exit;
}

$rusty->{data}->{profile_name} =
  $rusty->getProfileNameFromProfileId($rusty->{data}->{'profile_id'});

if (!$rusty->{data}->{profile_name}) {
  # Profile does not exist (or has no name)..
  print $rusty->redirect( -url => "/index.pl" );
  $rusty->exit;
}

$rusty->{data}->{num_photos} = $rusty->getCheckedPhotoCount($rusty->{data}->{'profile_id'});

if ($rusty->{core}->{'user_id'}) {
  
  $rusty->{data}->{photo_album_mode} = "user";
  
  if ($rusty->{data}->{num_photos} <= 1) {
    my $main_photo = $rusty->getMainPhoto($rusty->{data}->{'profile_id'});
    if ($main_photo && ($main_photo->{adult} || !$main_photo->{checked_date})) {
      unless ($rusty->hasAdultPass($rusty->{core}->{'user_id'})) {
        print $rusty->redirect( -url => "/profile/view.pl?profile_id=" . $rusty->{data}->{'profile_id'}
                                        . ($rusty->{params}->{search_id} ? "&search_id=$rusty->{params}->{search_id}" : "")
                                        . "&error=photoalbumnotviewable" );
        $rusty->exit;
      }
    }
    print $rusty->redirect( -url => "/profile/photo-display.pl?photo_id="
                                . $main_photo->{photo_id} . "&profile_id=" . $rusty->{data}->{'profile_id'}
                                . ($rusty->{params}->{search_id} ? "&search_id=$rusty->{params}->{search_id}" : "")
                                . '&warn=This%20is%20the%20only%20photo%20in%20the%20album' );
    $rusty->exit;
  }
  
} else {
  
  $rusty->{data}->{photo_album_mode} = "guest";
  
}

$rusty->{data}->{photos} = $rusty->getAllPhotos($rusty->{data}->{'profile_id'});

$rusty->{data}->{search_id} = $rusty->{params}->{search_id};

$rusty->process_template;
$rusty->exit;
