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
  
  my $profile_id = $rusty->{params}->{pr};
  my $photo_id = $rusty->{params}->{ph};
  $rusty->{data}->{adminmode} = $rusty->{params}->{a};
  
  my $query = <<ENDSQL
SELECT upp.photo_id, upp.caption, upp.total_visit_count,
       upp.uploaded_date, upp.profile_id, u.profile_name
FROM `user~profile~photo` upp
INNER JOIN `user~profile` up ON up.profile_id = upp.profile_id
INNER JOIN `user` u ON u.user_id = up.user_id
WHERE upp.photo_id = ?
LIMIT 1
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute($photo_id);
  ($rusty->{data}->{photo}->{photo_id},
   $rusty->{data}->{photo}->{caption},
   $rusty->{data}->{photo}->{total_visit_count},
   $rusty->{data}->{photo}->{uploaded},
   $rusty->{data}->{photo}->{'profile_id'},
   $rusty->{data}->{photo}->{profile_name}) = $sth->fetchrow_array;
  $sth->finish;
  
  if ($profile_id ne $rusty->{data}->{photo}->{'profile_id'}) {
    
    warn "photo id $photo_id requested for non-matching profile id $profile_id"
       . " instead of correct profile id $rusty->{data}->{photo}->{'profile_id'}";
    $rusty->{data}->{error} = "Profile id and photo id do not match";
    
  # As long as we aren't looking at our own photo or in admin mode (although
  # in admin mode, we would only be looking at our own photos!), update visit count.
  } elsif (!$rusty->{data}->{adminmode} &&
           ($rusty->{core}->{'profile_id'} != $rusty->{data}->{photo}->{'profile_id'})) {
    
    $query = <<ENDSQL
UPDATE `user~profile~photo` SET
total_visit_count = total_visit_count + 1
WHERE photo_id = ?
LIMIT 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($photo_id);
    $sth->finish;
    
    $rusty->{data}->{photo}->{total_visit_count}++;
    
  }
  
  $rusty->process_template;
}

