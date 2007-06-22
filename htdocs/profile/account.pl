#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

use vars qw($rusty $query $sth);

$rusty = rusty::Profiles->new;


$rusty->{ttml} = "profile/account.ttml";

$rusty->{param_info} = {
  
  # free text (VARCHAR(100)):
  fave_food           => { title => 'Food', size => 30, maxlength => 100 },
  fave_music          => { title => 'Music', size => 30, maxlength => 100 },
  fave_tvshow         => { title => 'TV Show', size => 30, maxlength => 100 },
  fave_author         => { title => 'Author', size => 30, maxlength => 100 },
  fave_movie          => { title => 'Movie', size => 30, maxlength => 100 },
  fave_club_bar       => { title => 'Nightclub', size => 30, maxlength => 100 },
  fave_animal         => { title => 'Animal', size => 30, maxlength => 100 },
  fave_person         => { title => 'Person', size => 30, maxlength => 100 },
  fave_website        => { title => 'Website', size => 30, maxlength => 100 },
  fave_place          => { title => 'Place', size => 30, maxlength => 100 },
  fave_thing          => { title => 'Thing', size => 30, maxlength => 100 },
  
  # lookups (TINYINT(3)):
  starsign_id            => { title => 'Star sign', type => 'select', minnum => 0, maxnum => 255 },
  relationship_status_id => { title => 'Relationship status', type => 'select', minnum => 0, maxnum => 255 },
  smoker_id              => { title => 'Smoker', type => 'select', minnum => 0, maxnum => 255 },
  drinker_id             => { title => 'Drinker', type => 'select', minnum => 0, maxnum => 255 },
  drug_user_id           => { title => 'Drug user', type => 'select', minnum => 0, maxnum => 255 },
  body_type              => { title => 'Body type', type => 'select', minnum => 0, maxnum => 255 },
  body_hair              => { title => 'Body hair', type => 'select', minnum => 0, maxnum => 255 },
  thought_type_id        => { title => 'Question', type => 'select', minnum => 1, maxnum => 255 },
  eye_colour_id          => { title => 'Eye colour', type => 'select', minnum => 0, maxnum => 255 },
  ethnic_origin_id       => { title => 'Ethnic origin', type => 'select', minnum => 0, maxnum => 255 },
  
  # integers (TINYINT(3) & SMALLINT(5)):
  height              => { title => 'Height', minnum => 0, maxnum => 255 },
  waist               => { title => 'Waist/Dress size', minnum => 0, maxnum => 255 },
  weight              => { title => 'Weight', minnum => 1, maxnum => 16777215, allow_empty => 1 },
  
  # free text (MYSQL VARCHAR(50)):
  profession          => { title => 'Profession', size => 30, maxlength => 50 },
  website             => { title => 'Personal website', size => 30, maxlength => 50 },
  hair                => { title => 'Hair', size => 30, maxlength => 50 },
  
  # textareas (TEXT):
  perfect_partner     => { title => 'Perfect partner', cols => 25, rows => 4, maxlength => 65535 },
  interests           => { title => 'My interests', cols => 25, rows => 4, maxlength => 65535 },
  happy               => { title => 'Makes me happy', cols => 25, rows => 4, maxlength => 65535 },
  sad                 => { title => 'Makes me sad', cols => 25, rows => 4, maxlength => 65535 },
  bad_habits          => { title => 'Bad habits', cols => 25, rows => 4, maxlength => 65535 },
  own_words           => { title => 'In my own words', cols => 25, rows => 4, maxlength => 65535 },
  thought_text        => { title => 'Final Thought', cols => 25, rows => 4, maxlength => 65535 },
  
  # select (ENUM('lbs','kg','st')):
  weight_type         => { title => 'Units', type => 'select', regexp => '(lbs|kg|st)' },
  
  # boolean (TINYINY(1)) - but checkbox so vals are '1' or '':
  email_alert         => { title => 'Email alerts', regexp => '^1?$' },
  hide_empty_info     => { title => 'Hide empty info', regexp => '^1?$' },
  
  # hidden fields
  profile_id          => { minnum => 1, maxnum => 65535, allow_empty => 1 },
};

# merge hash %param_info into hash %{$rusty->{param_info}} (two versions shown)
# $rusty->param_info = { %{$rusty->{param_info}}, %{$param_info} }; #SLOWER
# $rusty->{param_info}->{ keys %{$param_info} } = values %{$param_info}; #FASTER

$rusty->{data}->{param_info} = $rusty->{param_info};

my $ref = $rusty->{core}->{'ref'} = $rusty->{params}->{'ref'};




# Grab existing profile info for this user if it exists

unless ($rusty->{core}->{'user_id'} > 0) {
  print $rusty->CGI->redirect( -url => "/login.pl?ref=/profile/account.pl" );
  $rusty->exit;
  # If user not logged in, redirect to original signup.
  # So we're assuming here that signup has logged them in..
} elsif ($rusty->{core}->{profile_info}->{'deleted_date'}) {
  $rusty->process_template;
  $rusty->exit;
}

$query = <<ENDSQL
SELECT ui.gender, up.profile_name
FROM `user~profile` up
LEFT JOIN `user~info` ui ON ui.user_id = up.user_id
WHERE up.user_id = ?
LIMIT 1
ENDSQL
;
$sth = $rusty->DBH->prepare_cached($query);
$sth->execute($rusty->{core}->{'user_id'});
( $rusty->{params}->{'gender'},
  $rusty->{params}->{'profile_name'} ) = $sth->fetchrow_array;
$sth->finish;

unless ($rusty->{params}->{'gender'} &&
        $rusty->{params}->{'profile_name'} ) {
  # The user has signed up and is logged in
  # without a gender or profile name? Naaah!
  die "Your account appears to be corrupted.  Technical support will fix it!"
}

my $existing_profile = $rusty->{core}->{'profile_info'};

my $num_param_errors = 0;

if ($rusty->{params}->{'submitting'}) {
  
  # If this is 2nd call to signup (with 'submitting' set),
  # First, let's catch out the smart-ass monster-truckers..
  unless ($rusty->ensure_post()) {
    $rusty->{data}->{not_posted} = 1;
    $rusty->process_template();
    $rusty->exit;
  }
  
  # Check that all the data we've been given is right.
  $num_param_errors = $rusty->validate_params();
  
  require Data::Validate::URI; # 'is_uri';
  $rusty->{params}->{website} =~ s!^http://!!oi;
  if (!Data::Validate::URI::is_http_uri('http://'.$rusty->{params}->{website})) {
    $rusty->{param_errors}->{website}->{error} = "does not look like a valid URL!";
    $rusty->{param_errors}->{website}->{title} = $rusty->{params}->{website}->{title};
    $num_param_errors++;
  }
  $rusty->{params}->{fave_website} =~ s!^http://!!oi;
  if (!Data::Validate::URI::is_http_uri('http://'.$rusty->{params}->{fave_website})) {
    $rusty->{param_errors}->{fave_website}->{error} = "does not look like a valid URL!";
    $rusty->{param_errors}->{fave_website}->{title} = $rusty->{params}->{fave_website}->{title};
    $num_param_errors++;
  }
  
  if ($num_param_errors > 0) {
    
    # List errors in attempt to add/edit a profile
    $rusty->{data}->{errors} = $rusty->{param_errors};
    
  } else {
    
    # No errors in data - now insert/update the profile.
    
    # First convert all weights into grams (all stored
    # in DB as grams) from their chosen unit's figure.
    my $weight_in_grams = $rusty->{params}->{weight};
    if ($rusty->{params}->{weight}) {
      if ($rusty->{params}->{weight_type} eq "lbs") {
        $weight_in_grams =
          $rusty->lbsToGrams($weight_in_grams);
      } elsif ($rusty->{params}->{weight_type} eq "st") {
        $weight_in_grams =
          $rusty->stToGrams($weight_in_grams);
      } elsif ($rusty->{params}->{weight_type} eq "kg") {
        $weight_in_grams =
          $rusty->kgToGrams($weight_in_grams);
      }
    }
    $rusty->{params}->{email_alert} ||= 0;
    $rusty->{params}->{hide_empty_info} ||= 0;
    
    if (!$existing_profile->{'profile_id'}) {
      
      # New profile - create new profile..
      $rusty->{data}->{msg} = "Your profile has been added successfully";
      
      $query = <<ENDSQL
INSERT INTO `user~profile`
(created, updated,
 email_alert, weight,
 hair, eye_colour_id,
 website, profession,
 ethnic_origin_id, perfect_partner,
 smoker_id, drinker_id,
 drug_user_id, relationship_status_id,
 bad_habits, happy,
 sad, own_words,
 height, waist,
 starsign_id, interests,
 weight_type, body_type_id,
 body_hair_id, fave_food,
 fave_music, fave_tvshow,
 fave_author, fave_movie,
 fave_club_bar, fave_animal,
 fave_person, fave_website,
 fave_place, fave_thing,
 thought_type_id, thought_text,
 hide_empty_info, user_id)
VALUES
(NOW(), NOW(),
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?,
 ?, ?)
ENDSQL
;
      $sth = $rusty->DBH->prepare_cached($query);
      $sth->execute(
        $rusty->{params}->{email_alert},      $weight_in_grams,
        $rusty->{params}->{hair},             $rusty->{params}->{eye_colour_id},
        $rusty->{params}->{website},          $rusty->{params}->{profession},
        $rusty->{params}->{ethnic_origin_id}, $rusty->{params}->{perfect_partner},
        $rusty->{params}->{smoker_id},        $rusty->{params}->{drinker_id},
        $rusty->{params}->{drug_user_id},     $rusty->{params}->{relationship_status_id},
        $rusty->{params}->{bad_habits},       $rusty->{params}->{happy},
        $rusty->{params}->{sad},              $rusty->{params}->{own_words},
        $rusty->{params}->{height},           $rusty->{params}->{waist},
        $rusty->{params}->{starsign_id},      $rusty->{params}->{interests},
        $rusty->{params}->{weight_type},      $rusty->{params}->{body_type},
        $rusty->{params}->{body_hair},        $rusty->{params}->{fave_food},
        $rusty->{params}->{fave_music},       $rusty->{params}->{fave_tvshow},
        $rusty->{params}->{fave_author},      $rusty->{params}->{fave_movie},
        $rusty->{params}->{fave_club_bar},    $rusty->{params}->{fave_animal},
        $rusty->{params}->{fave_person},      $rusty->{params}->{fave_website},
        $rusty->{params}->{fave_place},       $rusty->{params}->{fave_thing},
        $rusty->{params}->{thought_type_id},  $rusty->{params}->{thought_text},
        $rusty->{params}->{hide_empty_info},  $rusty->{core}->{'user_id'}
      );

      my $inserted_profile_id = $rusty->DBH->{'mysql_insert_id'};
      if ($inserted_profile_id > 0) {
	  $query = <<ENDSQL
UPDATE `user` SET profile_id = ? WHERE user_id = ? LIMIT 1
ENDSQL
;
	  my $sth_update_profile_id_in_user_table = $rusty->DBH->prepare_cached($query);
	  $sth_update_profile_id_in_user_table->execute($inserted_profile_id, $rusty->{core}->{'user_id'});
	  $sth_update_profile_id_in_user_table->finish;
      }
      $sth->finish;
      
      if ($ref) {
        # If we had somewhere that they were redirected here from, take them back there! :)
        require URI::Escape;
        print $rusty->CGI->redirect( -url => $ref );
        $rusty->exit;
      }
      
    } else {
      
      # Existing profile - update details..
      $rusty->{data}->{msg} = "Your profile has been updated successfully";
      
      $query = <<ENDSQL
UPDATE `user~profile` SET
updated = NOW(),
email_alert = ?, weight = ?,
hair = ?, eye_colour_id = ?,
website = ?, profession = ?,
ethnic_origin_id = ?, perfect_partner = ?,
smoker_id = ?, drinker_id = ?,
drug_user_id = ?, relationship_status_id = ?,
bad_habits = ?, happy = ?,
sad = ?, own_words = ?,
height = ?, waist = ?,
starsign_id = ?, interests = ?,
weight_type = ?, body_type_id = ?,
body_hair_id = ?, fave_food = ?,
fave_music = ?, fave_tvshow = ?,
fave_author = ?, fave_movie = ?,
fave_club_bar = ?, fave_animal = ?,
fave_person = ?, fave_website = ?,
fave_place = ?, fave_thing = ?,
thought_type_id = ?, thought_text = ?,
hide_empty_info = ?
WHERE
user_id = ?
ENDSQL
;
      $sth = $rusty->DBH->prepare_cached($query);
      $sth->execute(
        $rusty->{params}->{email_alert},      $weight_in_grams,
        $rusty->{params}->{hair},             $rusty->{params}->{eye_colour_id},
        $rusty->{params}->{website},          $rusty->{params}->{profession},
        $rusty->{params}->{ethnic_origin_id}, $rusty->{params}->{perfect_partner},
        $rusty->{params}->{smoker_id},        $rusty->{params}->{drinker_id},
        $rusty->{params}->{drug_user_id},     $rusty->{params}->{relationship_status_id},
        $rusty->{params}->{bad_habits},       $rusty->{params}->{happy},
        $rusty->{params}->{sad},              $rusty->{params}->{own_words},
        $rusty->{params}->{height},           $rusty->{params}->{waist},
        $rusty->{params}->{starsign_id},      $rusty->{params}->{interests},
        $rusty->{params}->{weight_type},      $rusty->{params}->{body_type},
        $rusty->{params}->{body_hair},        $rusty->{params}->{fave_food},
        $rusty->{params}->{fave_music},       $rusty->{params}->{fave_tvshow},
        $rusty->{params}->{fave_author},      $rusty->{params}->{fave_movie},
        $rusty->{params}->{fave_club_bar},    $rusty->{params}->{fave_animal},
        $rusty->{params}->{fave_person},      $rusty->{params}->{fave_website},
        $rusty->{params}->{fave_place},       $rusty->{params}->{fave_thing},
        $rusty->{params}->{thought_type_id},  $rusty->{params}->{thought_text},
        $rusty->{params}->{hide_empty_info},  $rusty->{core}->{'user_id'}
      );
      $sth->finish;
    }
    
    # Put the existing data we got from the DB into the form values
    # (we want to make sure that the fields are filled out with the
    # real data
    # UPDATE: No!  We want to put the data they tried to input back
    # into the fields so they can try again! No? :)
    #$rusty->{params} = { %{$rusty->{params}}, %{$existing_profile} };
    
  }
}

# If we had errors in a submit, we should not get any new values from the DB
#if (!$param_errors) {
# Only get new values if we're on first call to the page (easier, eh?)
if (!$rusty->{params}->{'submitting'}) {
  
  $existing_profile = $rusty->getProfileInfo($rusty->getProfileIdFromUserId($rusty->{core}->{'user_id'}));
  
  if ($existing_profile->{'profile_id'}) {
    ###############################################################
    # Put the existing data we got from the DB into the form values
    # (by merging the existing data hash into the hash of params).
    ###############################################################
    # We do this in every case because if we have not yet updated our
    # profile, and are just viewing it, we want to have the stored info (obviously)..
    # But if we just created or updated our profile then we don't want to
    # see the parameters we passed in as they may have been chewed up by
    # the database and will just keep re-appearing if you keep hitting
    # refresh.. We need to overwrite them with the stored values in every case.
    ###############################################################
    #$rusty->{params}->{ keys %{$existing_profile} } = values %{$existing_profile};
    $rusty->{params} = { %{$rusty->{params}}, %{$existing_profile} };
  }

}

#$rusty->{data}->{ keys %{$rusty->{params}} } = values %{$rusty->{params}};
$rusty->{data} = { %{$rusty->{data}}, %{$rusty->{params}} };


$rusty->{data}->{starsigns} =
  [{ value => 0,  name => "Rather not say", },
   $rusty->get_ordered_lookup_list(
    table => "lookup~starsign",
    id    => "starsign_id",
    data  => "name" )];

$rusty->{data}->{relationship_statuses} =
  [{ value => 0,  name => "Rather not say", },
   $rusty->get_ordered_lookup_list(
    table => "lookup~relationship_status",
    id    => "relationship_status_id",
    data  => "name" )];

$rusty->{data}->{smokers} =
  [{ value => 0,  name => "Rather not say", },
   $rusty->get_ordered_lookup_list(
    table => "lookup~smoker",
    id    => "smoker_id",
    data  => "name" )];

$rusty->{data}->{drinkers} =
  [{ value => 0,  name => "Rather not say", },
   $rusty->get_ordered_lookup_list(
    table => "lookup~drinker",
    id    => "drinker_id",
    data  => "name" )];

$rusty->{data}->{drug_users} =
  [{ value => 0,  name => "Rather not say", },
   $rusty->get_ordered_lookup_list(
    table => "lookup~drug_user",
    id    => "drug_user_id",
    data  => "name" )];

$rusty->{data}->{ethnic_origins} =
  [{ value => 0,  name => "Rather not say", },
   $rusty->get_ordered_lookup_list(
    table => "lookup~ethnic_origin",
    id    => "ethnic_origin_id",
    data  => "name" )];

$rusty->{data}->{eye_colours} = 
  [{ value => 0,  name => "Rather not say", },
   $rusty->get_ordered_lookup_list(
    table => "lookup~eye_colour",
    id    => "eye_colour_id",
    data  => "name" )];

my @height_options = ();
push @height_options, { value => 0, name => "Rather not say", };
push @height_options, { value => 1, name => "Under 4'0\" (121cm)", };
foreach my $f (4..6) {
  foreach my $i (0..11) {
    my $cm = int($rusty->feetAndInchesToCm($f, $i)) + 1;
    push @height_options, { value => $cm, name => "$f'$i\" (${cm}cm)" };
  }
}
push @height_options, { value => 213,  name => "7'0\" (213cm)", };
push @height_options, { value => 255,  name => "Over 7' (213cm)", };
$rusty->{data}->{heights} = \@height_options;


my @waist_options = ();
push @waist_options, { value => 0,  name => "Rather not say", };

if ($rusty->{data}->{gender} eq "male") {

  push @waist_options, { value => 1,  name => "Under 28\" (70cm)", };
  foreach my $i (29..48) {
    my $cm = int($rusty->inchesToCm($i));
    push @waist_options, { value => $cm, name => "$i\" (${cm}cm)" };
  }
  push @waist_options, { value => 255,  name => "Over 48\" (121cm)", };

} elsif ($rusty->{data}->{gender} eq "female") {

  push @waist_options, { value => 1,  name => "Under 6", };
  for (my $i=6; $i<=20; $i+=1) {
    push @waist_options, { value => $i, name => $i };
  }
  push @waist_options, { value => 255,  name => "Over 20", };
  
} else{
  
  warn "not male of female?? what??";
  
}

$rusty->{data}->{waists} = \@waist_options;

$rusty->{data}->{weight_types} = [{ value  => "lbs", name => "lbs" },
                                  { value  => "kg",  name => "kg" },
                                  { value  => "st",  name => "st" }];

$rusty->{data}->{body_types} = 
  [{ value => 0,  name => "Rather not say", },
   $rusty->get_ordered_lookup_list(
    table => "lookup~body_type",
    id    => "body_type_id",
    data  => "name" )];

$rusty->{data}->{body_hairs} = 
  [{ value => 0,  name => "Rather not say", },
   $rusty->get_ordered_lookup_list(
    table => "lookup~body_hair",
    id    => "body_hair_id",
    data  => "name" )];

$rusty->{data}->{thought_types} = 
  [$rusty->get_ordered_lookup_list(
    table => "lookup~thought_type",
    id    => "thought_type_id",
    data  => "name" )];

$rusty->process_template;
$rusty->exit;
