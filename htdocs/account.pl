#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

#use Email qw( send_email validate_email );
require Email;

use rusty::Profiles;

use vars qw($rusty $query $sth);

$rusty = rusty::Profiles->new;





$rusty->{ttml} = "account.ttml";

# Subroutine prototypes

sub signup_form(%);

sub generate_passphrase(@);

sub get_signup_select_options();



$rusty->{param_info} = {
  gender              => { title => 'Gender', type => 'select', regexp => '^(?:male|female)$' },
  sexuality           => { title => 'Sexuality', type => 'select', regexp => '^(?:straight|gay/lesbian|bisexual/curious)$' },
  dob_year            => { title => 'Year of birth', type => 'select', regexp => '^\d{4}$' },
  dob_month           => { title => 'Month of birth', type => 'select', minnum => 1, maxnum => 12 },
  dob_day             => { title => 'Day of birth', type => 'select', minnum => 1, maxnum => 31 },
  country_code        => { title => 'Country', type => 'select', notregexp => '^select$' },
  subentity_code      => { title => 'Location', type => 'select', notregexp => '^select$' },
  real_name           => { title => 'Real name', maxlength => 50, regexp => '\S' },
  profile_name        => { title => 'Profile name', maxlength => 20, regexp => '^[a-z0-9_\-]+$' },
  email               => { title => 'Email', maxlength => 50, regexp => '\S' },
  confirmemail        => { title => 'Email confirmation', maxlength => 50, regexp => '\S' },
  password1           => { title => 'Password', minlength => 6, maxlength => 20, notregexp => '[^a-z0-9]' },
  password2           => { title => 'Password confirmation', minlength => 6, maxlength => 20, notregexp => '[^a-z0-9]' },
  passphrase          => { title => 'Passphrase', regexp => '\S' }
};


my $ref = $rusty->{core}->{'ref'} = $rusty->{params}->{'ref'}
  unless $rusty->{params}->{'ref'} eq '/';


# User could be requesting that we fill up their cities list (no JS/AJAX)
if ($rusty->{params}->{reloadareas}) {
  $rusty->{data} = $rusty->{params};
  get_signup_select_options();
  $rusty->process_template;
  $rusty->exit;
  
# Or re-allow them to select their countries list (still no JS/AJAX)
} elsif ($rusty->{params}->{changecountry}) {
  $rusty->{data} = $rusty->{params};
  get_signup_select_options();
  delete $rusty->{params}->{enable_subentities_list};
  delete $rusty->{params}->{subentity_code};
  delete $rusty->{params}->{subentities};
  $rusty->process_template;
  $rusty->exit;
}


# This user is already logged on so mode is edit account, not signup
if ($rusty->{core}->{'user_id'}) {
  
  if ($rusty->{params}->{'submitting'}) {
    
    # Do all of the cleverness right about here for users editing accounts...
    
    # First, let's catch out the smart-ass monster-truckers..
    unless ($rusty->ensure_post()) {
      $rusty->{data} = $rusty->{params};
      $rusty->{data}->{not_posted} = 1;
      get_signup_select_options();
      $rusty->process_template();
      $rusty->exit;
    }
    
    $rusty->{params}->{email} = lc($rusty->{params}->{email});
    $rusty->{params}->{confirmemail} = lc($rusty->{params}->{confirmemail});
    
    $rusty->{data}->{param_info} = $rusty->{param_info};
    
    # Don't worry if email isn't being changed..
    delete $rusty->{param_info}->{email}->{regexp};
    delete $rusty->{param_info}->{confirmemail}->{regexp};
    # Profile name won't be changed on account edit..
    delete $rusty->{param_info}->{profile_name}->{regexp};
    # And passphrase won't be required..
    delete $rusty->{param_info}->{passphrase}->{regexp};
    # Check that all the data we've been given is right.
    my $num_param_errors;
    $num_param_errors = $rusty->validate_params();
    
    if ($rusty->{param_errors}->{dob_year} ||
        $rusty->{param_errors}->{dob_month} ||
        $rusty->{param_errors}->{dob_day}) {
      
      delete $rusty->{param_errors}->{dob_year};
      delete $rusty->{param_errors}->{dob_month};
      delete $rusty->{param_errors}->{dob_day};
      $rusty->{param_errors}->{dob}->{error} = "select all fields";
      $rusty->{param_errors}->{dob}->{title} = 'Date of Birth';
      $num_param_errors++;
      
    } else {
      
      require Time::DaysInMonth;
      my $days_in_month = Time::DaysInMonth::days_in($rusty->{params}->{dob_year},
                                                     $rusty->{params}->{dob_month});
      unless ($rusty->{params}->{dob_day} <= $days_in_month) {
        
        $rusty->{param_errors}->{dob}->{error} = "select a valid date";
        $rusty->{param_errors}->{dob}->{title} = 'Date of Birth';
        $num_param_errors++;
      }
    }
    
    if ($rusty->{params}->{email} eq '') {
      
      delete $rusty->{param_errors}->{email};
      $num_param_errors--;
      
    } elsif (exists $rusty->{param_errors}->{email}) {
      
      delete $rusty->{param_errors}->{confirmemail};
      
    } else {
      
      if ($rusty->{params}->{email} ne $rusty->{params}->{confirmemail}) {
        
        $rusty->{param_errors}->{email}->{error} =
          "email addresses do not match";
        $rusty->{param_errors}->{email}->{title} =
          $rusty->{param_info}->{email}->{title};
        $num_param_errors++;
        
      } elsif (!Email::validate_email($rusty->{params}->{email})) {
        
        $rusty->{param_errors}->{email}->{error} =
          'is not a valid email address';
        $rusty->{param_errors}->{email}->{title} =
          $rusty->{param_info}->{email}->{title};
        $num_param_errors++;
      }
    }
    
    if (not exists $rusty->{param_errors}->{email}) {
      
      $query = <<ENDSQL
SELECT email
FROM `user`
WHERE email = ?
LIMIT 1
ENDSQL
;
      $sth = $rusty->DBH->prepare_cached($query);
      $sth->execute($rusty->{params}->{email});
      if ($sth->fetchrow_array()) {
        
        $rusty->{param_errors}->{email}->{error} =
          'is already in use by another member - please choose another';
        $rusty->{param_errors}->{email}->{title} =
          $rusty->{param_info}->{email}->{title};
        $num_param_errors++;
      }
      $sth->finish;
    }
    
    if ($rusty->{params}->{password1} eq '') {
      
      delete $rusty->{param_errors}->{password1};
      delete $rusty->{param_errors}->{password2};
      $num_param_errors--;
      
    } elsif ($rusty->{param_errors}->{password1}) {
      
      $rusty->{param_errors}->{passwords} = $rusty->{param_errors}->{password1};
      delete $rusty->{param_errors}->{password1};
      delete $rusty->{param_errors}->{password2};
      
    } elsif ($rusty->{params}->{password1} ne $rusty->{params}->{password2}) {
      
      $rusty->{param_errors}->{passwords}->{error} =
        'passwords do not match';
      $rusty->{param_errors}->{passwords}->{title} =
        $rusty->{param_info}->{password1}->{title};
      $num_param_errors++;
    }
    
    if ($num_param_errors > 0) {
      
      # If errors in form, print signup form with errors flagged.
      $rusty->{data}->{errors} = $rusty->{param_errors};
      
    } else {
      
      # If the form was filled out correctly;
      
      # Update basic user info
      $query = <<ENDSQL
UPDATE `user~info` SET
real_name = ?,
gender = ?,
dob = ?,
age = ?,
sexuality = ?,
country_code = ?,
subentity_code = ?
WHERE user_id = ?
ENDSQL
;
      my $dob = sprintf("%4d-%02d-%02d",
                        $rusty->{params}->{dob_year},
                        $rusty->{params}->{dob_month},
                        $rusty->{params}->{dob_day});
      
      my @localtime = localtime();
      my $age = (($localtime[5]+1900) - $rusty->{params}->{dob_year}) -
                  (int(($localtime[4]+1).sprintf("%02d",$localtime[3])) < 
                   int($rusty->{params}->{dob_month}.sprintf("%02d",$rusty->{params}->{dob_day})));
      
      $sth = $rusty->DBH->prepare_cached($query);
      $sth->execute($rusty->{params}->{real_name},
                    $rusty->{params}->{gender},
                    $dob, $age,
                    $rusty->{params}->{sexuality},
                    $rusty->{params}->{country_code},
                    $rusty->{params}->{subentity_code},
                    $rusty->{core}->{user_id});
      $sth->finish;
      
      # If requesting a password change..
      if ($rusty->{params}->{password1}) {
        
        # Update password
        $query = <<ENDSQL
UPDATE `user` SET
password = ?
WHERE user_id = ?
ENDSQL
;
        $sth = $rusty->DBH->prepare_cached($query);
        $sth->execute($rusty->{params}->{password1},
                      $rusty->{core}->{user_id});
        $sth->finish;
        
      }
      
      # If requesting an email change..
      if ($rusty->{params}->{email}) {
        
        my $email_validation_code = $rusty->random_word();
        
        # Update email info
        $query = <<ENDSQL
UPDATE `user` SET
email = ?,
email_validated = NULL,
email_validation_code = ?
WHERE user_id = ?
ENDSQL
;
        $sth = $rusty->DBH->prepare_cached($query);
        $sth->execute($rusty->{params}->{email},
                      $email_validation_code,
                      $rusty->{core}->{user_id});
        $sth->finish;
        
        # Send out email if email changed with link to validate new email
        require URI::Escape; # 'uri_escape';
        my $activation_link = "http://" . $rusty->CGI->server_name
          . "/email-validation.pl"
          . "?email=" . URI::Escape::uri_escape($rusty->{params}->{email})
          . "&profile=" . $rusty->{core}->{profile_name}
          . "&validation=$email_validation_code";
        
        my $textmessage = <<ENDEMAIL
Hi,
The user '$rusty->{core}->{profile_name}' from BackpackingBuddies.com
requested to change their email address to this one.
Please confirm that this is your email address by clicking on the link
provided below:

$activation_link

If this request did not come from you, please delete this email and
no further action is required.
ENDEMAIL
;
        
      }
      
      $rusty->{data}->{msg} = "Your account was updated successfully";
      
    }
  }
  
  # Now get the user's info so we can fill out their form for them..
  
  $query = <<ENDSQL
SELECT real_name, gender,
      DATE_FORMAT(dob, "%Y") AS dob_year,
      DATE_FORMAT(dob, "%c") AS dob_month,
      DATE_FORMAT(dob, "%e") AS dob_day,
      sexuality, subentity_code, country_code
FROM `user~info`
WHERE user_id = ?
LIMIT 1
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute($rusty->{core}->{'user_id'});
  my $user_info = $sth->fetchrow_hashref();
  $sth->finish;
  $rusty->{data}->{email} = $rusty->{core}->{email};
  $rusty->{data}->{profile_name} = $rusty->{core}->{profile_name};
  $rusty->{data}->{real_name} = $user_info->{real_name};
  $rusty->{data}->{gender} = $user_info->{gender};
  $rusty->{data}->{dob_year} = $user_info->{dob_year};
  $rusty->{data}->{dob_month} = $user_info->{dob_month};
  $rusty->{data}->{dob_day} = $user_info->{dob_day};
  $rusty->{data}->{sexuality} = $user_info->{sexuality};
  $rusty->{data}->{subentity_code} = $user_info->{subentity_code};
  $rusty->{data}->{country_code} = $user_info->{country_code};
  
  get_signup_select_options();
  
  $rusty->process_template;
  $rusty->exit;
  
} elsif (!$rusty->{params}->{passphrase_id}) {
  
  # If this is the 1st call to signup, generate
  # a new passphrase and print blank signup form
  $rusty->{data}->{passphrase_id} = generate_passphrase();
  
  $rusty->{data}->{email} = $rusty->{params}->{email};
  $rusty->{data}->{real_name} = $rusty->{params}->{real_name};
  $rusty->{data}->{gender} = $rusty->{params}->{gender};
  $rusty->{data}->{country_code} = $rusty->{params}->{country_code};
  
  get_signup_select_options();
  
  if ($rusty->{params}->{country_code}) {
    
    $query = <<ENDSQL
SELECT subentity_code, name
FROM `lookup~continent~country~city1000`
WHERE country_code = ?
ORDER BY name
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{params}->{country_code});
    while (my ($subentity_code, $subentity_name) = $sth->fetchrow_array) {
      push @{$rusty->{data}->{subentities}}, { value => $subentity_code,
                                               name  => $subentity_name };
    }
    $sth->finish;
  }
  
  $rusty->process_template;
  $rusty->exit;
  
} else {
  
  # If this is 2nd call to signup (with passphrase),
  
  # Hoorah for being lazy!
  $rusty->{data} = $rusty->{params};
  
  # First, let's catch out the smart-ass monster-truckers..
  unless ($rusty->ensure_post()) {
    $rusty->{data} = $rusty->{params};
    $rusty->{data}->{not_posted} = 1;
    get_signup_select_options();
    $rusty->process_template();
    $rusty->exit;
  }
  
  # Make profile name, email and passphrase lowercase
  $rusty->{params}->{profile_name} = lc($rusty->{params}->{profile_name});
  $rusty->{params}->{passphrase} = lc($rusty->{params}->{passphrase});
  $rusty->{params}->{email} = lc($rusty->{params}->{email});
  $rusty->{params}->{confirmemail} = lc($rusty->{params}->{confirmemail});
  
  $rusty->{data}->{param_info} = $rusty->{param_info};
  
  # Check that all the data we've been given is right.
  my $num_param_errors;
  $num_param_errors = $rusty->validate_params();
  
  if ($rusty->{param_errors}->{dob_year} ||
      $rusty->{param_errors}->{dob_month} ||
      $rusty->{param_errors}->{dob_day}) {
    
    delete $rusty->{param_errors}->{dob_year};
    delete $rusty->{param_errors}->{dob_month};
    delete $rusty->{param_errors}->{dob_day};
    $rusty->{param_errors}->{dob}->{error} = "select all fields";
    $rusty->{param_errors}->{dob}->{title} = 'Date of Birth';
    $num_param_errors++;
    
  } else {
    
    require Time::DaysInMonth;
    my $days_in_month = Time::DaysInMonth::days_in($rusty->{params}->{dob_year},
                                                   $rusty->{params}->{dob_month});
    unless ($rusty->{params}->{dob_day} <= $days_in_month) {
      
      $rusty->{param_errors}->{dob}->{error} = "select a valid date";
      $rusty->{param_errors}->{dob}->{title} = 'Date of Birth';
      $num_param_errors++;
    }
  }
  
  if (not exists $rusty->{param_errors}->{profile_name}) {
    
    # Check that profile name isn't already in use.
    $query = "SELECT user_id FROM `user~profile` WHERE profile_name = ? LIMIT 1";
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{params}->{profile_name});
    (my $profile_exists) = $sth->fetchrow_array();
    $sth->finish;
    if ($profile_exists > 0) {
      
      $rusty->{param_errors}->{profile_name}->{error} =
        "is already in use by another member";
      $rusty->{param_errors}->{profile_name}->{title} =
        $rusty->{param_info}->{profile_name}->{title};
      $num_param_errors++;
      
    } else {
      
      # Check profile name against list of directories/aliases.
      #open DIRS, "../conf/directories.txt" or die "can't open file: $!";
      #if (grep {/^$rusty->{params}->{profile_name}$/} <DIRS>) {
      #  $rusty->{param_errors}->{profile_name}->{error} =
      #    "'$rusty->{params}->{profile_name}' is a reserved word and cannot be used as a profile name. <br />";
      #$rusty->{param_errors}->{profile_name}->{title} =
      #  $rusty->{params}->{profile_name}->{title};
      #$num_param_errors++;
      #}
    }
  }
  
  if (exists $rusty->{param_errors}->{email}) {
    
    delete $rusty->{param_errors}->{confirmemail};
    
  } else {
    
    if ($rusty->{params}->{email} ne $rusty->{params}->{confirmemail}) {
      
      $rusty->{param_errors}->{email}->{error} =
        "email addresses do not match";
      $rusty->{param_errors}->{email}->{title} =
        $rusty->{param_info}->{email}->{title};
      $num_param_errors++;
      
    } elsif (!Email::validate_email($rusty->{params}->{email})) {
      
      $rusty->{param_errors}->{email}->{error} =
        'is not a valid email address';
      $rusty->{param_errors}->{email}->{title} =
        $rusty->{param_info}->{email}->{title};
      $num_param_errors++;
    }
  }
  
  if (not exists $rusty->{param_errors}->{email}) {
    
    $query = <<ENDSQL
SELECT email
FROM `user`
WHERE email = ?
LIMIT 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{params}->{email});
    if ($sth->fetchrow_array()) {
      
      $rusty->{param_errors}->{email}->{error} =
        'is already in use by another member - please choose another';
      $rusty->{param_errors}->{email}->{title} =
        $rusty->{param_info}->{email}->{title};
      $num_param_errors++;
    }
    $sth->finish;
  }
  
  if ($rusty->{param_errors}->{password1}) {
    
    $rusty->{param_errors}->{passwords} = $rusty->{param_errors}->{password1};
    delete $rusty->{param_errors}->{password1};
    delete $rusty->{param_errors}->{password2};
    
  } elsif ($rusty->{params}->{password1} ne $rusty->{params}->{password2}) {
    
    $rusty->{param_errors}->{passwords}->{error} =
      'passwords do not match';
    $rusty->{param_errors}->{passwords}->{title} =
      $rusty->{param_info}->{password1}->{title};
    $num_param_errors++;
  }
  
  $query = <<ENDSQL
SELECT passphrase
FROM `signup~passphrase`
WHERE passphrase_id = ?
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute($rusty->{params}->{passphrase_id});
  my $passphrase = $sth->fetchrow_array();
  $sth->finish;
  
  if (!$passphrase) {
    
    warn "Passphrase id '$rusty->{params}->{passphrase_id}' expired.";
    
    $rusty->{param_errors}->{passphrase}->{error} =
      'previous passphrase has expired - please enter the new passphrase';
    $rusty->{param_errors}->{passphrase}->{title} =
      $rusty->{param_info}->{passphrase}->{title};
    $num_param_errors++;
    
    $rusty->{params}->{passphrase_id} = generate_passphrase();
    
    $rusty->{params}->{passphrase} = '';
    
  } else {
    
    my $passphrase_success_field = 'passphrase_hit';
    
    if (($num_param_errors == 0) && ($rusty->{params}->{passphrase} ne $passphrase)) {
      
      # Only if the form has no other errors, then check the passphrase.
      # If the passphrase does not match then generate a new passphrase.
      $passphrase_success_field = 'passphrase_miss';
      
      # Was this passphrase attempt a near miss?  Or just plain rubbish?
      for (my $i=0; $i<=length($passphrase)-3; $i++) {
        if ($rusty->{params}->{passphrase} =~ /$passphrase[$i..$i+2]/) {
          $passphrase_success_field = 'passphrase_near_miss';
          last;
        }
      }
      
      warn "Passphrase '$passphrase' did not match user's attempt '".
           $rusty->{params}->{passphrase}."'." . ($passphrase_near_miss ? ' But it was very close!' : '');
      
      $rusty->{param_errors}->{passphrase}->{error} =
        'passphrase was not correct - please enter the new passphrase';
      $rusty->{param_errors}->{passphrase}->{title} =
        $rusty->{param_info}->{passphrase}->{title};
      $num_param_errors++;
      
      $rusty->{params}->{passphrase} = '';
      
      # Generate new password for this session
      generate_passphrase($rusty->{params}->{passphrase_id});
    }
    
    # Build query to log successful passphrase hits as well as misses in stats db.
    $query = <<ENDSQL
INSERT INTO `site~stats`
SET $passphrase_success_field = 1,
    date = CURRENT_DATE()
ON DUPLICATE KEY UPDATE $passphrase_success_field = $passphrase_success_field + 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute();
    $sth->finish;
  }
  
  
  if ($num_param_errors > 0) {
    
    # If errors in form, print signup form with errors flagged.
    $rusty->{data}->{errors} = $rusty->{param_errors};
    get_signup_select_options();
    $rusty->process_template;
    $rusty->exit;
    
  } else {
    
    # If the form was filled out correctly;
    # First, remove old passphrase session so it cannot be re-used.
    $query = <<ENDSQL
DELETE FROM `signup~passphrase`
WHERE passphrase_id = ?
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{params}->{passphrase_id});
    $sth->finish;
    
    my $email_validation_code = $rusty->random_word();
    
    $query = <<ENDSQL
INSERT INTO `user`
( password, email, email_validation_code )
VALUES
( ?, ?, ? )
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{params}->{password1},
                  $rusty->{params}->{email},
                  $email_validation_code);
    $sth->finish;
    
    # Get the user id of the user we just created
    my $user_id = $rusty->DBH->{mysql_insertid};
    
    # Insert the profile_name into empty profile entry
    $query = <<ENDSQL
INSERT INTO `user~profile`
( user_id, profile_name )
VALUES
( ?, ? )
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($user_id,
                  $rusty->{params}->{profile_name});
    $sth->finish;
    
    # Get the profile id of the profile we just created
    my $profile_id = $rusty->DBH->{mysql_insertid};
    
    # Create reference to profile_id in the user table
    # (I know, we're duplicating key references, but
    # it REALLY speeds up a lot of lookups and removes
    # one table from all of these lookup's joins.. :)
    $query = <<ENDSQL
UPDATE `user`
SET profile_id = ?
WHERE user_id = ?
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($profile_id, $user_id);
    $sth->finish;
    
    # Create some basic user info
    $query = <<ENDSQL
INSERT INTO `user~info`
( user_id, real_name, gender, dob, age, sexuality, country_code, subentity_code )
VALUES
( ?, ?, ?, ?, ?, ?, ?, ? )
ENDSQL
;
    my $dob = sprintf("%4d-%02d-%02d",
                      $rusty->{params}->{dob_year},
                      $rusty->{params}->{dob_month},
                      $rusty->{params}->{dob_day});
    
    my @localtime = localtime();
    my $age = (($localtime[5]+1900) - $rusty->{params}->{dob_year}) -
                (int(($localtime[4]+1).sprintf("%02d",$localtime[3])) < 
                 int($rusty->{params}->{dob_month}.sprintf("%02d",$rusty->{params}->{dob_day})));
    
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($user_id,
                  $rusty->{params}->{real_name},
                  $rusty->{params}->{gender},
                  $dob, $age,
                  $rusty->{params}->{sexuality},
                  $rusty->{params}->{country_code},
                  $rusty->{params}->{subentity_code});
    $sth->finish;
    
    # Create stats for user (when they joined)
    $query = <<ENDSQL
INSERT INTO `user~stats`
( user_id, joined )
VALUES
( ?, NOW() )
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($user_id);
    $sth->finish;
    
    # Send out email to new user with link to validate email
    require URI::Escape; # 'uri_escape';
    my $activation_link = "http://" . $rusty->CGI->server_name
      . "/email-validation.pl"
      . "?email=" . URI::Escape::uri_escape($rusty->{params}->{email})
      . "&profile=" . $rusty->{params}->{profile_name}
      . "&validation=$email_validation_code";
    
    my $textmessage = <<ENDEMAIL
Hi $rusty->{params}->{real_name},
Welcome to BackpackingBuddies.com!
Someone, hopefully you, signed up with this email address
Here are your login details for future reference:

    Username: $rusty->{params}->{profile_name}
    Password: $rusty->{params}->{password1}

To activate your account and gain full access to the site, click here:
$activation_link
ENDEMAIL
;
    
    my $htmlmessage = Email::create_html_from_text($textmessage);
    
    Email::send_email( To => [ "$rusty->{params}->{real_name} <$rusty->{params}->{email}>", ],
                       Subject => 'Activate your account',
                       TextMessage => $textmessage,
                       HtmlMessage => $htmlmessage );
    
    # Update site stats for number of signups per day
    $query = <<ENDSQL
INSERT INTO `site~stats`
SET signups = 1,
date = CURRENT_DATE()
ON DUPLICATE KEY UPDATE signups = signups + 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute();
    $sth->finish;
    
    # Now log in the user and take to main config page (to add profiles)
    my $ip_address = $ENV{'REMOTE_ADDR'};
    
    my $session_id = $ENV{'UNIQUE_ID'};
    
    $query = <<ENDSQL
INSERT INTO `user~session`
( session_id, user_id, ip_address )
VALUES
( ?, ?, ? )
ENDSQL
;
    
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($session_id, $user_id, $ip_address);
    $sth->finish;
    
    # Create test session cookie and send off to initiate login.
    my $test_cookie = $rusty->CGI->cookie( -name    => "test",
                                           -value   => $session_id );
    
    require URI::Escape;
    print $rusty->redirect( -url => "/login.pl?mode=signup_test"
                                       . ($ref ? "&ref=" . URI::Escape::uri_escape($ref) : ''),
                                 -cookie => $test_cookie );
    
    $rusty->exit;
    
  }

}

$rusty->exit;




sub generate_passphrase(@) {
  
  my $phrase_id = shift;
  
  my $phrase = $rusty->random_word();
  
  if ($phrase_id) {
    
    # If we were handed a passphrase id, we are
    # generating a new passphrase for this session
    $query = <<ENDSQL
UPDATE `signup~passphrase`
SET passphrase = ?
WHERE passphrase_id = ?
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($phrase, $phrase_id);
    $sth->finish;
    
  } else {
    
    # Otherwise, we are creating a brand new passphrase
    # (in event of new signup or passphrase expiry).
    # So put generated passphrase with id into db
    # and, if successful, return the associated id.
    $phrase_id = $ENV{'UNIQUE_ID'};
    
    $query = <<ENDSQL
INSERT INTO `signup~passphrase`
( passphrase_id, passphrase )
VALUES
( ?, ? )
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($phrase_id, $phrase);
    $sth->finish;
  }
  
  return $phrase_id;
}




sub get_signup_select_options() {

  $rusty->{data}->{genders} = [
    { value => "select", name => "Please Select", },
    { value => "male", name => "Male", },
    { value => "female",  name => "Female", },
                              ];
  
  $rusty->{data}->{sexualities} = [
    { value => 'select', name => 'Please Select', },
    { value => 'straight', name => 'Straight', },
    { value => 'bisexual/curious',  name => 'Bisexual/Curious', },
    { value => 'gay/lesbian',  name => 'Gay/Lesbian', },
                                  ];
  
  $rusty->{data}->{countries} = [
    $rusty->get_ordered_lookup_list(
      table => "lookup~continent~country",
      id    => "country_code",
      data  => "name",
      order => "name",
                                   ),
                                ];
  
  # Truncate long country names
  foreach (@{$rusty->{data}->{countries}}) {
    if (length($_->{name}) > 30) {
      $_->{name} = substr($_->{name},0,27) . ' ...';
    }
  }
  
  if ($rusty->{params}->{country_code} && $rusty->{params}->{country_code} ne 'select') {
    my $query = <<ENDSQL
SELECT subentity_code, name
FROM `lookup~continent~country~city1000`
WHERE country_code = ?
ORDER BY name
ENDSQL
    ;
    my $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{params}->{country_code});
    $rusty->{params}->{enable_subentities_list} = 1;
    while (my ($subentity_code, $subentity_name) = $sth->fetchrow_array) {
      push @{$rusty->{data}->{subentities}}, { value => $subentity_code, name => $subentity_name};
    }
    $sth->finish;
  }
  
  return 1;
}
