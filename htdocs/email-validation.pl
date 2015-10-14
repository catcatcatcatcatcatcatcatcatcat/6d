#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

our $rusty = rusty::Profiles->new;

my ($dbh, $query, $sth);

$dbh = $rusty->DBH;




$rusty->{ttml} = "email-validation.ttml";

(my $email = $rusty->{data}->{email}) = $rusty->{params}->{email};
(my $profile_name = $rusty->{data}->{profile_name}) = $rusty->{params}->{profile};
(my $email_validation_code = $rusty->{data}->{email_validation_code}) = $rusty->{params}->{validation};

unless ($email && $profile_name && $email_validation_code) {
  
  $rusty->{data}->{error} = "The following fields were missing.  Please check the URL.";
  
} else {
  
  $query = <<ENDSQL
SELECT u.email, u.email_validation_code, u.email_validated, ui.real_name
FROM `user` u
INNER JOIN `user_info` ui ON ui.user_id = u.user_id
INNER JOIN `user_profile` up ON up.user_id = u.user_id
WHERE up.profile_name = ?
LIMIT 1
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_name);
  my $real_values = $sth->fetchrow_hashref();
  $sth->finish;
  
  if (not exists $real_values->{email}) {
    
    $rusty->{data}->{error} = "The profile '$profile_name' does not exist";
    
  } elsif ($real_values->{email} ne $email) {
    
    $rusty->{data}->{error} = "'$email' is not the correct email address for '$profile_name'";
    
  } elsif ($real_values->{email_validated}) {
    
    $rusty->{data}->{error} = "Profile '$profile_name' is already validated";
    
  } elsif ($real_values->{email_validation_code} ne $email_validation_code) {
    
    $rusty->{data}->{error} = "'$email_validation_code' is not the correct validation word for '$profile_name'";
    
  } else {
    
    $query = <<ENDSQL
UPDATE `user` u
INNER JOIN `user_profile` up ON up.user_id = u.user_id
SET u.email_validation_code = NULL,
    u.email_validated = NOW()
WHERE up.profile_name = ?
  AND u.email = ?
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($profile_name, $email);
    $sth->finish;
  }
}

$rusty->process_template;
$rusty->exit;
