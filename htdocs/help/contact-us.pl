#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

require Email; #qw( send_email create_html_from_text );

use rusty::Profiles;

our $rusty = rusty::Profiles->new;

use vars qw ( $email $confirmemail $name $phone $dept $problem $subject $description $ref $dept_options );


# Subroutine prototypes

sub email_support();


$rusty->{ttml} = "help/contact-us.ttml";

$dept_options = $rusty->{data}->{dept_options} = { 'support' => 'Technical Support',
						   'suggestions' => 'Suggestions' };

$email = $rusty->{data}->{email} = lc($rusty->{params}->{email});
$confirmemail = $rusty->{data}->{confirmemail} = lc($rusty->{params}->{confirmemail});
$name = $rusty->{data}->{name} = $rusty->{params}->{name};
$phone = $rusty->{data}->{phone} = $rusty->{params}->{phone};
$dept = $rusty->{data}->{dept} = $rusty->{params}->{dept};
$problem = $rusty->{data}->{problem} = $rusty->{params}->{problem};
$subject = $rusty->{data}->{subject} = $rusty->{params}->{subject};
$description = $rusty->{data}->{description} = $rusty->{params}->{description};

$ref = $rusty->{core}->{'ref'} = $rusty->{params}->{'ref'};

if ($rusty->{params}->{'error'}) {
  
  $rusty->{data}->{'error'} = $rusty->{params}->{'error'};
  
} elsif ($rusty->{params}->{'sent'} == 1) {
  
  $rusty->{data}->{'sent'} = $rusty->{params}->{'sent'};
  
} elsif ($rusty->{params}->{'send'} == 1) {
  
  unless ($rusty->ensure_post()) {
    $rusty->{data}->{'not_posted'} = 1;
    $rusty->process_template();
    $rusty->exit;
  }
  
  # If the user has entered a profile name
  
  if (!$email) {
    $rusty->{data}->{'error'} = "noemail";
    #print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
    #                                   . "?error=noemail" );
    #$rusty->exit;
  } elsif ($email ne $confirmemail) {
    $rusty->{data}->{'error'} = "emailmismatch";
    #print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
    #                                   . "?error=emailmismatch" );
    #$rusty->exit;
  } elsif (!$dept) {
    $rusty->{data}->{'error'} = "noproblemtype";
    #print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
    #                                   . "?error=noproblemtype" );
    #$rusty->exit;
  } elsif (!$problem) {
    $rusty->{data}->{'error'} = "noproblem";
    #print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
    #                                   . "?error=noproblem" );
    #$rusty->exit;
  } elsif (!$subject) {
    $rusty->{data}->{'error'} = "nosubject";
    #print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
    #                                   . "?error=nosubject" );
    #$rusty->exit;
  } elsif (!$description) {
    $rusty->{data}->{'error'} = "nodescription";
    #print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
    #                                   . "?error=nodescription" );
    #$rusty->exit;
  } elsif ($dept =~ /[^a-z\._]+/i &&
	   grep /^$dept$/, keys %$dept_options) {
    $rusty->{data}->{'error'} = "hackedform";
    #print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
    #                                   . "?error=hackedform" );
    #$rusty->exit;
  } else {
    
    email_support();
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?sent=1" );
    $rusty->exit;
  }
  
} else {
  
  if ($rusty->{core}->{user_id} > 0) {
    my $query = <<ENDSQL
SELECT u.email, ui.real_name
FROM `user` u
INNER JOIN `user~info` ui ON ui.user_id = u.user_id
WHERE u.user_id = ?
LIMIT 1
ENDSQL
;
    my $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{core}->{user_id});
    ($rusty->{core}->{user_info}->{email}, $rusty->{core}->{user_info}->{real_name}) = $sth->fetchrow_array;
    $sth->finish;
  }
  
}

$rusty->process_template;
$rusty->exit;




sub email_support() {
  
  # Send out email to a support dept.
  
  my $current_time = localtime();
  
  my $textmessage = <<ENDMSG
Date: $current_time
Name: $name
Email: $email
Phone Number: $phone

ENDMSG
;
  if ($rusty->{core}->{user_id}) {
    $textmessage .= <<ENDMSG
=============
User ID: $rusty->{core}->{user_id}
Email: $rusty->{core}->{email}
Profile Name: $rusty->{core}->{profile_name}
=============
ENDMSG
;
  } else {
    $textmessage .= <<ENDMSG
========
Visitor ID: $rusty->{core}->{visitor_id}
========
ENDMSG
;
  }
  
  $textmessage .= <<ENDMSG

Problem Type: $problem

Subject: $subject

Ref: $ref

============

Description:

$description

ENDMSG
;
  
  my $htmlmessage = Email::create_html_from_text($textmessage);
  
  Email::send_email( 'To'          => [ "$dept\@backpackingbuddies.com", ],
                     'Reply-To'    => [ "$name <$email>", ],
                     'Subject'     => "Support Request ($problem): $subject",
                     'TextMessage' => $textmessage,
                     'HtmlMessage' => $htmlmessage );
  
}
