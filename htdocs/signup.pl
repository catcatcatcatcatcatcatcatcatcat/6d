#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

#use Email qw( send_email validate_email );
require Email;

our $rusty = rusty->new;

if ($rusty->{core}->{'user_id'}) {
  # This user is already logged on and trying to access the signup page.
  print $rusty->CGI->redirect( -url => '/' );
  $rusty->exit;
}

use vars qw ( $dbh $query $sth $passphrase_id );

$dbh = $rusty->DBH;





$rusty->{ttml} = "signup.ttml";

# Subroutine prototypes

sub signup_form(%);

sub generate_passphrase(@);

sub get_signup_select_options();




$passphrase_id = $rusty->{params}->{passphrase_id};

if (!$passphrase_id) {
  
  # If this is the 1st call to signup, generate
  # a new passphrase and print blank signup form
  
  #$passphrase_id = generate_passphrase();
  $rusty->{data}->{passphrase_id} = generate_passphrase();
  
  #print signup_form();
  
  get_signup_select_options();
  $rusty->process_template;
  $rusty->exit;
  
} else {
  
  # If this is 2nd call to signup (with passphrase),
  
  # First, let's catch out the smart-ass monster-truckers..
  
  unless ($rusty->ensure_post()) {
    $rusty->{data} = $rusty->{params};
    $rusty->{data}->{'not_posted'} = "1";
    get_signup_select_options();
    $rusty->process_template();
    $rusty->exit;
  }
  
  # Make profile name, email and passphrase lowercase
  
  $rusty->{params}->{profile_name} = lc($rusty->{params}->{profile_name});
  $rusty->{params}->{passphrase} = lc($rusty->{params}->{passphrase});
  $rusty->{params}->{email} = lc($rusty->{params}->{email});
  
  # Check that all the data we've been given is right.
  
  my %errors;
  
  my $gender = $rusty->{params}->{gender};
  if ($gender !~ /^(?:male|female)$/i) {
    
    $errors{"gender"} .=
      "Please select your gender. <br />\n";
    
  }
  
  my $sexuality = $rusty->{params}->{sexuality};
  if ($sexuality !~ m!^(?:straight|gay/lesbian|bisexual/curious)$!i) {
    
    $errors{"sexuality"} .=
      "Please select your sexuality. <br />\n";
    
  }
  
  my $country_id = $rusty->{params}->{country_id};
  if ($country_id =~ /^Select$/oi) {
    
    $errors{"country_id"} .=
      "Please select your country. <br />\n";
    
  }
  
  my $city_id = $rusty->{params}->{city_id};
  if ($city_id =~ /^Select$/oi) {
    
    $errors{"city_id"} .=
      "Please select your city. <br />\n";
    
  }
    
  
  my $real_name = $rusty->{params}->{real_name};
  if (length($real_name) < 1) {

    $errors{"real_name"} .=
      "Please enter your name. <br />\n";
  
  }
  
  my $profile_name = $rusty->{params}->{profile_name};
  if ( (length($profile_name) < 1)
    || (length($profile_name) > 20) ) {
    
    $errors{"profile_name"} .=
      "Profile name must be 1-20 characters long. <br />\n";
    
  }
  if ($profile_name =~ /[^a-z0-9_]/oi) {
    
    $errors{"profile_name"} .=
      "Profile name must only contain numbers, letters and underscores. <br />\n";
    
  }
  
  if (not exists $errors{"profile_name"}) {
    
    # Check that profile name isn't already in use.
    $query = "SELECT user_id FROM `user` WHERE profile_name = ? LIMIT 1";
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($profile_name);
    (my $profile_exists) = $sth->fetchrow_array();
    if ($profile_exists > 0) {
      
      $errors{"profile_name"} =
        "'$profile_name' is already in use by another member. <br />";
      
    } else {
      
      # Check profile name against list of directories/aliases.
      #open DIRS, "../conf/directories.txt" or die "can't open file: $!";
      #if (grep {/^$profile_name$/} <DIRS>) {
      #  $errors{"profile_name"} =
      #    "'$profile_name' is a reserved word and cannot be used as a profile name. <br />";
      #}
    }
  }
  
  my $email = $rusty->{params}->{email};
  
  if (!Email::validate_email($email)) {
    
    $errors{"email"} .=
      "Please enter a valid email address. <br />\n";
    
  }
  if (not exists $errors{"email"}) {
    
    $query = <<ENDSQL
SELECT email
FROM `user`
WHERE email = ?
LIMIT 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($email);
    if ($sth->fetchrow_array()) {
      $errors{"email"} .=
        "The email address '$email' is already in use by another member. "
      . "Please choose another. <br />\n";
    }
    $sth->finish;
  }
  
  my $password = $rusty->{params}->{password1};
  my $passwordcheck = $rusty->{params}->{password2};
  if ($password ne $passwordcheck) {
    
    $errors{"passwords"} .=
      "The passwords you have entered do not match. <br />\n";
    
  } else {
    
    if ( (length($password) < 6)
      || (length($password) > 20) ) {
      
      $errors{"passwords"} .=
        "Password must be 6-20 characters long. <br />\n";
      
    }
    if ($password =~ /[^a-z0-9]/oi) {
      
      $errors{"passwords"} .=
        "Password must only contain numbers and letters. <br />\n";
      
    }
  }
  
  $query = <<ENDSQL
SELECT passphrase
FROM `signup~passphrase`
WHERE passphrase_id = ?
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute($passphrase_id);
  my $passphrase = $sth->fetchrow_array();
  $sth->finish;
  
  if (!$passphrase) {
    
    warn "Passphrase id '$passphrase_id' expired.";
    
    $errors{"passphrase_id"} .=
      "That passphrase has expired. Please enter the new passphrase. <br />\n";
    
    $passphrase_id = generate_passphrase();
    
    $rusty->{params}->{passphrase} = "";
    
  } else {
    
    if ($rusty->{params}->{passphrase} eq "") {
      
      $errors{"passphrase"} .=
        "Please enter the passphrase. <br />\n";
      
    } elsif ((keys %errors == 0) && ($rusty->{params}->{passphrase} ne $passphrase)) {
      
      # Only if the form has no other errors, then check the passphrase.
      # If the passphrase does not match then generate a new passphrase.
      
      warn "Passphrase '$passphrase' did not match user's attempt '".
           $rusty->{params}->{passphrase}."'.";
      
      $errors{"passphrase"} .=
        "Passphrase was not correct. "
      . "Please try again with the new passphrase. <br />\n";
      
      $rusty->{params}->{passphrase} = "";
      
      # Generate new password for this session
      
      generate_passphrase($passphrase_id);
      
    }
    
  }
  
  if (keys %errors > 0) {
    
    # If errors in form, print signup form with errors flagged.
    
    #print signup_form(\%errors);
    
    $rusty->{data}->{gender} = $gender;
    $rusty->{data}->{sexuality} = $sexuality;
    $rusty->{data}->{country_id} = $country_id;
    $rusty->{data}->{city_id} = $city_id;
    $rusty->{data}->{real_name} = $real_name;
    $rusty->{data}->{profile_name} = $profile_name;
    $rusty->{data}->{email} = $email;
    $rusty->{data}->{passphrase_id} = $passphrase_id;
    
    $rusty->{data}->{errors} = \%errors;
    
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
    $sth = $dbh->prepare_cached($query);
    $sth->execute($passphrase_id);
    $sth->finish;
    
    # Then add this new user to the database.
    
    $real_name =~ s/'/\\'/og;
    
    my $email_validation_code = $rusty->random_word();

    $query = <<ENDSQL
INSERT INTO `user`
( profile_name, password, email, email_validation_code )
VALUES
( ?, ?, ?, ? )
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($profile_name, $password, $email, $email_validation_code);
    $sth->finish;
    
    # Get the user id of the user we just created
    my $user_id = $dbh->{mysql_insertid};
    
    # Create some basic user info
    
    $query = <<ENDSQL
INSERT INTO `user~info`
( user_id, real_name, gender, sexuality, country_id, city_id )
VALUES
( ?, ?, ?, ?, ?, ? )
ENDSQL
;
    
    $sth = $dbh->prepare_cached($query);
    $sth->execute($user_id, $real_name, $gender, $sexuality, $country_id, $city_id);
    $sth->finish;
    
    # Create stats for user (when they joined)
    
    $query = <<ENDSQL
INSERT INTO `user~stats`
( user_id, joined )
VALUES
( ?, NOW() )
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($user_id);
    $sth->finish;
    
    # Send out email to new user with link to validate email
    require URI::Escape; # 'uri_escape';
    my $activation_link = "http://" . $rusty->CGI->server_name
      . "/email-validation.pl"
      . "?email=" . URI::Escape::uri_escape($email)
      . "&profile=$profile_name"
      . "&validation=$email_validation_code";
      
    my $textmessage = <<ENDEMAIL
Hi $real_name,
Welcome to X.com!
Someone, hopefully you, signed up with this email address
Here are your login details for future reference:

    Username: $profile_name
    Password: $password

To activate your account and gain full access to the site, click here:
$activation_link

If you want to remove yourself, you can do so here:
[PAGE WHICH ASKS FOR USERNAME AND PASSWORD TO REMOVE
USER WHICH ALSO LINKS TO PAGES WHICH SEND LOGIN DETAILS
TO A USERNAME OR PASSWORD SPECIFIED (NOT NEEDED IN THIS
CASE, BUT IS FOR ON THE SPOT REQUESTS]

ENDEMAIL
;
    
    my $htmlmessage = Email::create_html_from_text($textmessage);
    
    Email::send_email( To => [ "$real_name <$email>", ],
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
    $sth = $dbh->prepare_cached($query);
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
    
    $sth = $dbh->prepare_cached($query);
    $sth->execute($session_id, $user_id, $ip_address);
    $sth->finish;
    
    # Create test session cookie and send off to initiate login.
    
    my $test_cookie = $rusty->CGI->cookie( -name    => "test",
                                           -value   => $session_id );
    
    print $rusty->CGI->redirect( -url => "/login.pl?mode=signup_test",
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
    $sth = $dbh->prepare_cached($query);
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
    $sth = $dbh->prepare_cached($query);
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
    { value => 'select', name => 'Please Select', },
    $rusty->get_ordered_lookup_list(
      table => "lookup~country",
      id    => "country_id",
      data  => "name",
                                   ),
                                ];
  
  # Truncate long country names
  foreach (@{$rusty->{data}->{countries}}) {
    if (length($_->{name}) > 30) {
      $_->{name} = substr($_->{name},0,27) . ' ...';
    }
  }
  
  $rusty->{data}->{cities} = [
    { value => 'select', name => 'Please Select', },
    $rusty->get_ordered_lookup_list(
      table => "lookup~country~uk_city",
      id    => "city_id",
      data  => "name",
                                   ),
                             ];
  
  return 1;
}
