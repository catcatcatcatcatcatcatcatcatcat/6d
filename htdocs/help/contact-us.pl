#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

require Email; #qw( send_email create_html_from_text );

use rusty::Profiles;

use vars qw($rusty $query $sth);

$rusty = rusty::Profiles->new;

use vars qw ( $email $confirmemail $name $phone $dept $problem $subject $description $ref $dept_options );


# Subroutine prototypes

sub generate_passphrase(@);

sub email_support();


$rusty->{ttml} = "help/contact-us.ttml";

$dept_options = $rusty->{data}->{dept_options} = { 'support' => 'Technical Support',
                                                   'suggestions' => 'Suggestion4s' };

$email = $rusty->{data}->{email} = lc($rusty->{params}->{email});
$confirmemail = $rusty->{data}->{confirmemail} = lc($rusty->{params}->{confirmemail});
$name = $rusty->{data}->{name} = $rusty->{params}->{name};
$phone = $rusty->{data}->{phone} = $rusty->{params}->{phone};
$dept = $rusty->{data}->{dept} = $rusty->{params}->{dept};
$problem = $rusty->{data}->{problem} = $rusty->{params}->{problem};
$subject = $rusty->{data}->{subject} = $rusty->{params}->{subject};
$description = $rusty->{data}->{description} = $rusty->{params}->{description};
$rusty->{data}->{passphrase_id} = $rusty->{params}->{passphrase_id};

$ref = $rusty->{core}->{'ref'} = $rusty->{params}->{'ref'};

my $num_param_errors = 0;

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
  
  if (!$email) {
    $rusty->{data}->{'error'} = "noemail";
  } elsif ($email ne $confirmemail) {
    $rusty->{data}->{'error'} = "emailmismatch";
  } elsif (!$dept) {
    $rusty->{data}->{'error'} = "noproblemtype";
  } elsif (!$problem) {
    $rusty->{data}->{'error'} = "noproblem";
  } elsif (!$subject) {
    $rusty->{data}->{'error'} = "nosubject";
  } elsif (!$description) {
    $rusty->{data}->{'error'} = "nodescription";
  } elsif ($dept =~ /[^a-z\._]+/i &&
           grep /^$dept$/, keys %$dept_options) {
    $rusty->{data}->{'error'} = "hackedform";
  } elsif (!$rusty->{params}->{passphrase}) {
    $rusty->{param_errors}->{passphrase}->{error} =
      'passphrase needs to be filled in';
    $rusty->{param_errors}->{passphrase}->{title} =
      $rusty->{param_info}->{passphrase}->{title};
    $num_param_errors++;
  } else {
    
    # Verify that the passphrase matches
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
      
      $rusty->{data}->{passphrase_id} = generate_passphrase();
      
    } elsif ($num_param_errors == 0) {
      
      my $passphrase_success_field = 'passphrase_hit';
      
      if ($rusty->{params}->{passphrase} ne $passphrase) {
        
        # Only if the form has no other errors, then check the passphrase.
        # If the passphrase does not match then generate a new passphrase.
        $passphrase_success_field = 'passphrase_miss';
        
        # Was this passphrase attempt a near miss?  Or just plain rubbish?
        for (my $i=0; $i<=length($passphrase)-3; $i++) {
          my $chunk = substr($passphrase, $i, 3);
          if ($rusty->{params}->{passphrase} =~ /\Q$chunk\E/) {
            $passphrase_success_field = 'passphrase_near_miss';
            last;
          }
        }
        
        warn "Passphrase '$passphrase' did not match user's attempt '".
             $rusty->{params}->{passphrase}."'." . ($passphrase_success_field eq 'passphrase_near_miss' ? ' But it was very close!' : '');
        
        $rusty->{param_errors}->{passphrase}->{error} =
          'passphrase was not correct - please enter the new passphrase';
        $rusty->{param_errors}->{passphrase}->{title} =
          $rusty->{param_info}->{passphrase}->{title};
        $num_param_errors++;
        
        # Generate new password for this session
        $rusty->{data}->{passphrase_id} = generate_passphrase($rusty->{params}->{passphrase_id});
      }
      
      # Build query to log successful passphrase hits as well as misses in stats db.
      $query = <<ENDSQL
INSERT DELAYED INTO `site~stats`
SET $passphrase_success_field = 1,
    date = CURRENT_DATE()
ON DUPLICATE KEY UPDATE $passphrase_success_field = $passphrase_success_field + 1
ENDSQL
;
      $sth = $rusty->DBH->prepare_cached($query);
      $sth->execute();
      $sth->finish;
    }
  }
  
  if ($rusty->{data}->{'error'} || $num_param_errors > 0) {
    
    # If errors in form, print signup form with errors flagged.
    $rusty->{data}->{errors} = $rusty->{param_errors};
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
    
    email_support();
    print $rusty->redirect( -url => $rusty->CGI->url( -relative => 1 )
                                       . "?sent=1" );
    $rusty->exit;
  }
  
} else {

  # Only generate captcha if not signed in (should have aleady passed captcha by this point!)
  # We are only doing this to stop bots who are not lovely users
  if ($rusty->{core}->{user_id} == 0) {
    $query = <<ENDSQL
SELECT u.email, ui.real_name
FROM `user` u
INNER JOIN `user~info` ui ON ui.user_id = u.user_id
WHERE u.user_id = ?
LIMIT 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{core}->{user_id});
    ($rusty->{core}->{user_info}->{email}, $rusty->{core}->{user_info}->{real_name}) = $sth->fetchrow_array;
    $sth->finish;
    
    # If this is the 1st call to signup, generate
    # a new passphrase and print blank signup form
    $rusty->{data}->{passphrase_id} = generate_passphrase();
  }
  
}

$rusty->process_template;
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




sub email_support() {
  
  # Send out email to a support dept.
  
  my $current_time = localtime();
  
  my $textmessage = <<ENDMSG
Date:         $current_time
Name:         $name
Email:        $email
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
