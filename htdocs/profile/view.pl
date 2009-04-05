#!/usr/bin/perl -Td

use strict;

use lib '../../lib';


use warnings qw( all );

no warnings qw( uninitialized );


use CarpeDiem;

#use Math::TrulyRandom qw( truly_random_value );
#use Math::Random qw( rand );
# This successfuly gets around the problem of /dev/random providing
# no entropy on our current VM setup!  Wahoo!
if ($ENV{NO_ENTROPY}) {
  eval {
    require Math::Random::MT::Auto;
    import Math::Random::MT::Auto qw( rand srand ), '/dev/urandom';
  }
}

use rusty::Profiles;

use vars qw( $rusty $query $sth );

$rusty = rusty::Profiles->new;

$rusty->{data}->{'error'} = $rusty->{params}->{'error'};
$rusty->{params}->{profile_name} =~ s/\s//o;

$rusty->{ttml} = "profile/view.ttml";

# Get profile id and name and fill up data, depending on which was specified..
if ($rusty->{params}->{profile_name}) {
  $rusty->{data}->{profile_name} = $rusty->{params}->{profile_name};
  $rusty->{data}->{profile_id} = $rusty->getProfileIdFromProfileName($rusty->{params}->{profile_name});
} elsif ($rusty->{params}->{profile_id}) {
  $rusty->{data}->{profile_id} = $rusty->{params}->{profile_id};
  $rusty->{data}->{profile_name} = $rusty->getProfileNameFromProfileId($rusty->{params}->{profile_id});
} else {
  # If no profile name was specified,
  if ($rusty->{core}->{'profile_name'}) {
    # If this is a logged in user, show them their own profile (if it exists).
    $rusty->{data}->{'profile_name'} = $rusty->{core}->{'profile_name'};
  } else {
    $rusty->process_template;
    $rusty->exit;
  }
}


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
  
  print $rusty->redirect( -url => "/profile/view.pl?"
                                     . "profile_name=" . $rusty->{data}->{profile_name}
                                     . "&search_id=" . $rusty->{params}->{search_id} );
  $rusty->exit;
}


$query = <<ENDSQL
SELECT up.user_id, up.profile_id, up.profile_name,
ui.gender, ui.sexuality, ui.age,
lco.name AS country, lcs.name AS subentity,
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
DATE_FORMAT(up.deleted_date, '%a %d/%m/%y %H:%i') AS deleted_date,
up.showfaves, up.showfriends

FROM `user~profile` up
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
LEFT JOIN `lookup~continent~country` lco ON ui.country_code = lco.country_code
LEFT JOIN `lookup~continent~country~city1000` lcs ON ui.subentity_code = lcs.subentity_code

WHERE up.profile_name = ?
LIMIT 1
ENDSQL
;

$sth = $rusty->DBH->prepare_cached($query);
$sth->execute($rusty->{data}->{'profile_name'});
my $profile = $sth->fetchrow_hashref;
$sth->finish;

if (!$profile->{'profile_id'}) {
  
  # If trying to view their own profile, take them to account setup
  if ($rusty->{data}->{'profile_name'} eq $rusty->{core}->{'profile_name'}) {
    print $rusty->redirect( -url => "/profile/account.pl" );
    $rusty->exit;
  }
  
  # If profile simply does not exist!
  $rusty->{data} = $profile;
  $rusty->{data}->{profile_name} = $rusty->{params}->{profile_name};
  $rusty->process_template;
  $rusty->exit;
  
} elsif ($profile->{deleted_date}) {
  
  # If trying to view their own profile, take them to account setup
  if ($rusty->{data}->{'profile_name'} eq $rusty->{core}->{'profile_name'}) {
    print $rusty->redirect( -url => "/profile/account.pl" );
    $rusty->exit;
  }
  
  $rusty->{data} = $profile;
  $rusty->{data}->{profile_name} = $rusty->{params}->{profile_name};
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
    if ($rusty->{core}->{'profile_id'} == $profile->{'profile_id'}) {
      $profile->{own_profile} = 1;
    } else {
      $rusty->profileLogVisit($profile->{'profile_id'}, $rusty->{core}->{'profile_id'});
    }
  }
} else {
  
  # If profile is being visited from someone not logged in, store this!
  $rusty->incrementExternalVisitCount($profile->{'profile_id'});
}

$rusty->incrementVisitCount($profile->{'profile_id'}) unless $profile->{own_profile};

# Sort out main profile photo and caption
$profile->{'main_photo'} = $rusty->getMainPhoto($profile->{'profile_id'});
$profile->{'photo_count'} = $rusty->getCheckedPhotoCount($profile->{'profile_id'});

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

# Let's see if we have blocked/befriended/faved/noted this person..
$profile->{block} = $rusty->findBlockLink($rusty->{core}->{'profile_id'}, $profile->{'profile_id'});
$profile->{friend} = $rusty->findFriendLink($rusty->{core}->{'profile_id'}, $profile->{'profile_id'});
$profile->{fave} = $rusty->findExistingFaveLink($rusty->{core}->{'profile_id'}, $profile->{'profile_id'});
$profile->{note} = $rusty->findExistingProfileNote($rusty->{core}->{'profile_id'}, $profile->{'profile_id'});

# Get 5 most recently added buddies..
if ($profile->{linked_friends} = $rusty->getAllFriends($profile->{'profile_id'}, 5)) {
  my $random_pick = int(rand(@{$profile->{linked_friends}}+0));
  $profile->{random_friend}->{main_photo} = $rusty->getPhotoInfo(${$profile->{linked_friends}}[$random_pick]->{main_photo_id});
  $profile->{random_friend}->{profile_id} = ${$profile->{linked_friends}}[$random_pick]->{profile_id};
  $profile->{random_friend}->{profile_name} = ${$profile->{linked_friends}}[$random_pick]->{profile_name};
}

# Get 5 most recently added favourite profiles..
if ($profile->{faves} = $rusty->getAllFaves($profile->{'profile_id'}, 5)) {
  my $random_pick = int(rand(@{$profile->{faves}}+0));
  $profile->{random_fave}->{main_photo} = $rusty->getPhotoInfo(${$profile->{faves}}[$random_pick]->{main_photo_id});
  $profile->{random_fave}->{profile_id} = ${$profile->{faves}}[$random_pick]->{profile_id};
  $profile->{random_fave}->{profile_name} = ${$profile->{faves}}[$random_pick]->{profile_name};
}


if ($profile->{own_profile}) {
  
  my $visitors = $rusty->getRecentProfileVisitors($rusty->{core}->{profile_id}, 10);
  
  if ($visitors) {
    $profile->{last_visitor}->{profile_name} = ${$visitors}[0]->{profile_name};
    $profile->{last_visitor}->{main_photo} = $rusty->getPhotoInfo(${$visitors}[0]->{main_photo_id});
    $profile->{visitors} = $visitors;
  }
}

$rusty->{data}->{search_id} = $rusty->{params}->{search_id};
$rusty->{data}->{mode} = $rusty->{params}->{mode};

# Catch any processing errors..
$rusty->{data}->{prev_action} = $rusty->{params}->{prev_action};
$rusty->{data}->{success} = $rusty->{params}->{success};
$rusty->{data}->{reason} = $rusty->{params}->{reason};


$rusty->{data} = { %{$rusty->{data}}, %$profile };

$rusty->process_template;
$rusty->exit;

