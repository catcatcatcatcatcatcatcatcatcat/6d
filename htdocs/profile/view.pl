#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw( all );

no warnings qw( uninitialized );

use CarpeDiem;

use rusty::Profiles;

use vars qw( $rusty $query $sth );

$rusty = rusty::Profiles->new;

$rusty->{params}->{profile_name} =~ s/\s//o;

$rusty->{ttml} = "profile/view.ttml";


if ($rusty->{params}->{from_search} && $rusty->{params}->{search_id}) {
  
  # If this profile has been viewed from clicking on a search result,
  # update our search cache so we know how much the search has been used
  # (how many profiles have been requested from the search results)
  # but only do so if this search belongs to the current user/visitor..
  $query = <<ENDSQL
UPDATE `user~profile~search~cache`
SET profiles_viewed_from_search = profiles_viewed_from_search + 1
WHERE search_id = ?
  AND ( ( user_id > 0
          AND user_id = ? )
        OR
        ( visitor_id > 0
          AND visitor_id = ? )
      )
LIMIT 1
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute($rusty->{params}->{search_id},
                ($rusty->{core}->{user_id} || 0),
                ($rusty->{core}->{visitor_id} || 0));
  $sth->finish;
  
  print $rusty->CGI->redirect( -url => "/profile/view.pl?"
                                     . "profile_name=" . $rusty->{params}->{profile_name}
                                     . "&search_id=" . $rusty->{params}->{search_id} );
  $rusty->exit;
}



my $profile_name = $rusty->getProfileNameFromUserId($rusty->{core}->{'user_id'})
  if $rusty->{core}->{'user_id'};

# If no profile name was specified,
if (!$rusty->{params}->{'profile_name'}) {
  # If this is a logged in user, show them their own profile (if it exists).
  if ($profile_name) {
    $rusty->{params}->{'profile_name'} = $profile_name;
  } else {
    $rusty->process_template;
    $rusty->exit;
  }
}




$query = <<ENDSQL
SELECT u.user_id, up.profile_id, u.profile_name,
ui.gender, ui.sexuality,
(YEAR(CURDATE()) - YEAR(ui.dob)) - (RIGHT(CURDATE(), 5) < RIGHT(ui.dob, 5)) AS age,
lco.name AS country, lci.name AS city,
us.joined, us.last_session_end, us.num_logins, us.mins_online, us.num_clicks,
usess.updated AS online_now,
up.height, up.weight, up.waist,
up.hair, up.website, up.profession,
up.perfect_partner, up.bad_habits,
up.happy, up.sad, up.own_words,
up.interests, up.weight_type,
up.fave_food, up.fave_music, up.fave_tvshow,
up.fave_author, up.fave_movie, up.fave_club_bar,
up.fave_animal, up.fave_person, up.fave_website,
up.fave_place, up.fave_thing,
up.thought_text, ltt.name,
lbh.name AS body_hair, lbt.name AS body_type,
ldi.name AS drinker, ldu.name AS drug_taker,
leo.name AS ethnic_origin, lec.name AS eye_colour,
lrs.name AS relationship_status, ls.name AS smoker,
lst.name AS starsign, ltt.name AS thought_type,
up.hide_empty_info, up.updated, up.created, up.total_visit_count,
DATE_FORMAT(up.deleted_date, '%a %d/%m/%y %H:%i') AS deleted_date

FROM `user~profile` up
INNER JOIN `user` u ON up.user_id = u.user_id
LEFT JOIN `user~stats` us ON up.user_id = us.user_id
LEFT JOIN `user~session` usess ON up.user_id = usess.user_id
                              AND usess.updated > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
                              AND usess.created IS NOT NULL
LEFT JOIN `lookup~body_hair` lbh ON up.body_hair_id = lbh.body_hair_id
LEFT JOIN `lookup~body_type` lbt ON up.body_type_id = lbt.body_type_id
LEFT JOIN `lookup~drinker` ldi ON up.drinker_id = ldi.drinker_id
LEFT JOIN `lookup~drug_user` ldu ON up.drug_user_id = ldu.drug_user_id
LEFT JOIN `lookup~ethnic_origin` leo ON up.ethnic_origin_id = leo.ethnic_origin_id
LEFT JOIN `lookup~eye_colour` lec ON up.eye_colour_id = lec.eye_colour_id
LEFT JOIN `lookup~relationship_status` lrs ON up.relationship_status_id = lrs.relationship_status_id
LEFT JOIN `lookup~smoker` ls ON up.smoker_id = ls.smoker_id
LEFT JOIN `lookup~starsign` lst ON up.starsign_id = lst.starsign_id
LEFT JOIN `lookup~thought_type` ltt ON up.thought_type_id = ltt.thought_type_id
LEFT JOIN `user~info` ui ON up.user_id = ui.user_id
LEFT JOIN `lookup~country` lco ON ui.country_id = lco.country_id
LEFT JOIN `lookup~country~uk_city` lci ON ui.city_id = lci.city_id

WHERE u.profile_name = ?
LIMIT 1
ENDSQL
;

$sth = $rusty->DBH->prepare_cached($query);
$sth->execute($rusty->{params}->{'profile_name'});
my $profile = $sth->fetchrow_hashref;
$sth->finish;

if (!$profile->{'profile_id'}) {
  
  # If profile simply does not exist!
  $rusty->{data} = $profile;
  $rusty->{data}->{profile_name} = $rusty->{params}->{profile_name};
  $rusty->{data}->{title} = "Profile Not Found: $rusty->{data}->{profile_name}";
  $rusty->process_template;
  $rusty->exit;
  
} elsif ($profile->{deleted_date}) {
  
  $rusty->{data} = $profile;
  $rusty->{data}->{profile_name} = $rusty->{params}->{profile_name};
  $rusty->{data}->{title} = "Profile Deleted: $rusty->{data}->{profile_name}";
  $rusty->process_template;
  $rusty->exit;
  
} else {

  # If profile does already exist,
  
  # First convert all weights from grams (all stored
  # in DB as grams) into their correct unit's figure.
  if ($profile->{weight_type} eq "lbs") {
    $profile->{weight} =
      $rusty->gramsToLbs($profile->{weight});
  } elsif ($profile->{weight_type} eq "st") {
    $profile->{weight} =
      $rusty->gramsToSt($profile->{weight});
  } elsif ($profile->{weight_type} eq "kg") {
    $profile->{weight} =
      $rusty->gramsToKg($profile->{weight});
  }

}

$profile->{own_profile} = 0;

# Grab existing profile info for this user if it exists
if ($rusty->{core}->{'user_id'} > 0) {
  
  # If logged in user is viewing a profile, catch their tracks!
  if ($rusty->{core}->{'profile_id'} > 0) {
    # Are they looking at their own profile?
    if ($rusty->{core}->{'profile_id'} != $profile->{'profile_id'}) {
      $rusty->profileLogVisit($profile->{'profile_id'}, $rusty->{core}->{'profile_id'});
    } else {
      $profile->{own_profile} = 1;
    }
  }
} else {
  
  # If profile is being visited from someone not logged in, store this!
  $rusty->incrementExternalVisitCount($profile->{'profile_id'});
}

$rusty->incrementVisitCount($profile->{'profile_id'}) unless $profile->{own_profile};

$rusty->{data}->{title} = "$profile->{profile_name}'s Profile";


# Sort out main profile photo and caption
$profile->{'main_photo'} = $rusty->getMainPhoto($profile->{'profile_id'});
$profile->{'photo_count'} = $rusty->getPhotoCount($profile->{'profile_id'});

#$profile->{website} = lc($profile->{website});
$profile->{website} =~ s@^(?!(:ht|f)tps?://)@@o;

$profile->{height_cm} = $profile->{height};
my $ftin = $rusty->cmToFeetInches($profile->{height_cm});
$profile->{height_ft} = int $ftin->{feet};
$profile->{height_in} = int $ftin->{inches};

$profile->{waist_cm} = $profile->{waist};
$profile->{waist_in} = int($rusty->cmToInches($profile->{waist}));

#$profile->{fave_website} = lc($profile->{website});
$profile->{fave_website} =~ s@^(?!(:ht|f)tps?://)@@o;

# Let's see if we are blocking this person..
$profile->{block} = $rusty->findBlockLink($rusty->{core}->{'profile_id'}, $profile->{'profile_id'});
$profile->{friend} = $rusty->findFriendLink($rusty->{core}->{'profile_id'}, $profile->{'profile_id'});
$profile->{fave} = $rusty->findExistingFaveLink($rusty->{core}->{'profile_id'}, $profile->{'profile_id'});

if ($profile->{linked_friends} = $rusty->getAllFriends($profile->{'profile_id'})) {
  my $random_pick = int(rand(@{$profile->{linked_friends}}));
  my $random_photo = $rusty->getMainPhoto(${$profile->{linked_friends}}[$random_pick]->{requestee_profile_id});
  $profile->{random_friend}->{thumbnail} = $random_photo->{thumbnail};
  $profile->{random_friend}->{name} = ${$profile->{linked_friends}}[$random_pick]->{requestee_profile_name};
}


if ($profile->{own_profile}) {
  $query = <<ENDSQL
SELECT v.visit_id, v.visitor_id, u.profile_name
FROM `user~profile~visit` v
INNER JOIN `user~profile` up ON up.profile_id = v.visitor_id
INNER JOIN `user` u ON u.user_id = up.user_id
WHERE v.profile_id = ?
ORDER BY v.visit_id DESC
LIMIT 10
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute($profile->{'profile_id'});
  my @visitors;
  while (my $visitor = $sth->fetchrow_hashref) {
    push @visitors, $visitor;
  }
  $sth->finish;
  
  if (@visitors) {
    $profile->{last_visitor}->{profile_name} = $visitors[0]->{profile_name};
    $profile->{last_visitor}->{main_photo} = $rusty->getMainPhoto($visitors[0]->{visitor_id});
    
    # Delete all visits stored since the 10th oldest (last retrieved) to keep
    # this database table nice and sparse!  We don't care after 10 per user..
    $query = <<ENDSQL
DELETE FROM `user~profile~visit`
WHERE profile_id = ?
  AND visit_id < ?
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($profile->{'profile_id'}, $visitors[$#visitors]->{visit_id});
    $sth->finish;
    $profile->{visitors} = \@visitors;
  }
}

$rusty->{data}->{search_id} = $rusty->{params}->{search_id};

$rusty->{data} = { %{$rusty->{data}}, %$profile };

$rusty->process_template;
$rusty->exit;

