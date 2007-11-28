#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use Email qw( send_email );

use rusty::Profiles;

our $rusty = rusty::Profiles->new;

use vars qw ( $dbh $query $sth );

$dbh = $rusty->DBH;


$rusty->{ttml} = "help/resend-activation.ttml";

if (!$rusty->{core}->{'user_id'}) {
  
  warn "user tried to access resend-activation while not logged in";
  print $rusty->redirect( -url => "/login.pl" );
  $rusty->exit;
  
} elsif ($rusty->{core}->{'email_validated'}) {
  
  warn "account is already activated (user_id: $rusty->{core}->{'user_id'})";
  $rusty->{data}->{error} = "Your account is already activated!";
  
} elsif ($rusty->{params}->{'sent'}) {
  
  $rusty->{data}->{sent} = 1;
  
} else {
  
  $query = <<ENDSQL
SELECT u.email, u.email_validation_code, u.email_validated,
       ui.real_name, up.profile_name
FROM `user` u
INNER JOIN `user~info` ui ON ui.user_id = u.user_id
INNER JOIN `user~profile` up ON up.user_id = u.user_id
WHERE u.user_id = ?
LIMIT 1
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute($rusty->{core}->{'user_id'});
  my $user_info = $sth->fetchrow_hashref();
  $sth->finish;
  
  # Send out email to new user with link to validate email
  
  # Merge user info with existing data
  $rusty->{data} ||= {};
  $rusty->{data} = { %{$rusty->{data}}, %$user_info };
  
  if ($rusty->{params}->{'send'}) {
    
    require URI::Escape; # 'uri_escape';
    my $activation_link = "http://" . $rusty->CGI->server_name
                        . "/email-validation.pl"
                        . "?email=" . URI::Escape::uri_escape($user_info->{email})
                        . "&profile=$user_info->{profile_name}"
                        . "&validation=$user_info->{email_validation_code}";
    
    my $textmessage = <<ENDMSG
Hi $user_info->{real_name},
Didn't you get this email the first time?
To activate your account and gain full access to the site, click here:

$activation_link

ENDMSG
;
    
    my $htmlmessage = Email::create_html_from_text($textmessage);
    
    Email::send_email( To => [ "$user_info->{real_name} <$user_info->{email}>" ],
                       Subject => 'Activate your account',
                       TextMessage => $textmessage,
                       HtmlMessage => $htmlmessage );
    
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?sent=1" );
    $rusty->exit;
    
  }
  
}

$rusty->process_template;
$rusty->exit;
