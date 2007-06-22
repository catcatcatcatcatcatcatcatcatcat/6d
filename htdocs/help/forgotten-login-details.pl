#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

require Email;
#use Email qw( send_email );

use rusty::Profiles;

our $rusty = rusty::Profiles->new;

use vars qw ( $dbh $query $sth );

$dbh = $rusty->DBH;




# Subroutine prototypes

sub email_login_details();




$rusty->{ttml} = "help/forgotten-login-details.ttml";

use vars qw($real_name $profile_name $password $email $popup);

$profile_name = $rusty->{data}->{profile_name} = lc($rusty->{params}->{profile_name});
$email = $rusty->{data}->{email} = lc($rusty->{params}->{email});
$popup = $rusty->{data}->{popup} = $rusty->{params}->{popup};

if ($rusty->{params}->{'sent'}) {
  
  $rusty->{data}->{sent} = $rusty->{params}->{'sent'};
  
} elsif ($profile_name) {
  
  unless ($rusty->ensure_post()) {
    $rusty->{data}->{'not_posted'} = 1;
    $rusty->process_template();
    $rusty->exit;
  }
  
  # If the user has entered a profile name
  
  $query = <<ENDSQL
SELECT u.email, u.password, ui.real_name
FROM `user` u
INNER JOIN `user~info` ui ON ui.user_id = u.user_id
INNER JOIN `user~profile` up ON up.user_id = u.user_id
WHERE up.profile_name = ?
LIMIT 1
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_name);
  $sth->finish;
  
  if (($email, $password, $real_name) = $sth->fetchrow_array()) {
    
    email_login_details();
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?sent=1&profile_name=$profile_name"
                                       . ($popup == 1 ? '&popup=1' : '') );
    $rusty->exit;
    
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?sent=2&profile_name=$profile_name"
                                       . ($popup == 1 ? '&popup=1' : '') );
    $rusty->exit;
    
  }
  
} elsif ($email) {
  
  unless ($rusty->ensure_post()) {
    $rusty->{data}->{'not_posted'} = "1";
    $rusty->process_template();
    $rusty->exit;
  }
  
  # If the user has entered an email address
  
  $query = <<ENDSQL
SELECT up.profile_name, u.password, ui.real_name
FROM `user` u
INNER JOIN `user~info` ui ON ui.user_id = u.user_id
INNER JOIN `user~profile` up ON up.user_id = u.user_id
WHERE u.email = ?
LIMIT 1
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute($email);
  
  if (($profile_name, $password, $real_name) = $sth->fetchrow_array()) {
    
    email_login_details();
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?sent=1&email=$email"
                                       . ($popup == 1 ? '&popup=1' : '') );
    $rusty->exit;
    
  } else {
    
    print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?sent=2&email=$email"
                                       . ($popup == 1 ? '&popup=1' : '') );
    $rusty->exit;
    
  }
  
  $sth->finish;
  
}

$rusty->process_template;
$rusty->exit;




sub email_login_details() {
  
  # Send out email to new user with link to validate email
  
  my $textmessage = <<ENDMSG
Hi $real_name,
Forgotten your password eh?
Well here are your login details:

    Username: $profile_name \n"
    Password: $password


Look after them this time! :)
ENDMSG
;
  
  my $htmlmessage = Email::create_html_from_text($textmessage);
  
  Email::send_email( To => [ "$real_name <$email>", ],
                     Subject => 'Login Details',
                     TextMessage => $textmessage,
                     HtmlMessage => $htmlmessage );
  
}

