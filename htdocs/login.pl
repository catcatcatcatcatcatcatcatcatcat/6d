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



my $ref = $rusty->{params}->{ref};

if ($rusty->{core}->{'user_id'}) {
  # This user is already logged on and trying to access the login page.
  # Send them back! (No other site does this, it may be a bad idea -
  # the others all log you in again.. Hmmm? Hmmm. Hmmm!)
  $ref ||= $rusty->{params}->{login} == 1 ? '/?login=1' : '/';
  print $rusty->CGI->redirect( -url => $ref );
  $rusty->exit;
}



$rusty->{ttml} = "login.ttml";

my $ip_address = $ENV{'REMOTE_ADDR'};

my $profile_name = $rusty->{params}->{profile_name};
my $password = $rusty->{params}->{password};
my $mode = $rusty->{params}->{mode};

# Open up the optional login box up above..
$rusty->{core}->{openloginnav} = 1;

if ($mode eq 'login') {
  
  $rusty->{data}->{'profile_name'} = $profile_name;
  
  # If first call to login (with username & password),
  # First, let's catch out the smart-ass monster-truckers..
  
  unless ($rusty->ensure_post()) {
    $rusty->{data}->{'not_posted'} = "1";
    $rusty->process_template();
    $rusty->exit;
  }
  
  if (!$profile_name) {
    $rusty->{data}->{'invalid_login'} = "1";
    $rusty->{data}->{'no_username'} = "1";
    $rusty->process_template();
    $rusty->exit;
  } elsif (!$password) {
    $rusty->{data}->{'invalid_login'} = "1";
    $rusty->{data}->{'no_password'} = "1";
    $rusty->process_template();
    $rusty->exit;
  }
  
  
  # Then make sure the login info given checks out..
  $query = <<ENDSQL
SELECT up.user_id
FROM `user~profile` up
INNER JOIN `user` u ON u.user_id = up.user_id
WHERE up.profile_name = ?
  AND u.password = ?
LIMIT 1
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_name, $password);
  my $user_id = $sth->fetchrow_array();
  $sth->finish;
  
  if (!$user_id) {
    
    $rusty->{data}->{'invalid_login'} = "1";
    $rusty->process_template();
    $rusty->exit;
  }
  
  # Assuming the login info was alright at this point;
  # First check that the user isn't already logged on.
  # Note: There can be more than one valid session left
  # awaiting cleanup (if user logs in and out repeatedly
  # within half an hour), so we only pick the latest one!
  # Also check created is not null - so that this isn't a
  # failed test session to see if cookies were working!
  $query = <<ENDSQL
SELECT ip_address, session_id
FROM `user~session`
WHERE user_id = ?
  AND created IS NOT NULL
  AND updated > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
ORDER BY updated DESC
LIMIT 1
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute($user_id);
  my ($session_ip_address, $session_id) = $sth->fetchrow_array();
  $sth->finish();
  
  # If there is a session left over from the user trying to log in now
  # which was updated in the last 30 mins, let's look deeper into this..
  if ($session_id) {
    
    # User must already be logged on somewhere.
    if ($session_ip_address eq $ip_address) {
      
      # If they're logged on on this machine, make sure that
      # they still have the valid session cookie set.
      if (my $cookie_session_id = $rusty->CGI->cookie( -name => "session" ) ) {
        
        if ($session_id eq $cookie_session_id) {
          
          # They shouldn't be logging in - send them back!
          warn "Recent session exists and cookie matches - request ignored";
          print $rusty->CGI->redirect( -url => ($ref || '/') );
          $rusty->exit;
          
        } else {
          
          # Their cookie has been messed with so continue as usual.
          warn "Recent session exists but cookie session id does not match";
        }
      } else {
        
        # Their cookie has been removed so continue as usual.
        # UPDATE: But what if they're just on a different browser on the
        # same machine/network?  Haha. The key is to not allow any more than
        # one session at the time!  UserID is now a unique key on `user~session`
        # so it never happens..
        warn "Recent session already exists for this user but no cookie found";
      }
      
    # If that valid session exists but the IP address is different..
    } else {
      
      
      # Fuck all the stuff below, just create a warning and create new session.
      
      
      # User is logged on somewhere else! =O Naughty, naughty boy.
      # Log the other one out and notify this user about it.
      #
      # NOTE: this logs them out by setting their session to expired.
      # More precisely, 10 years old going mouldy kind of expired..
      # This means that their stats will be preserved and added by the
      # garbageman but they will lose their session.  Perfect!
      #
      # Faceparty/Out/Boyfriend allow the same person to log in many times on
      # different machines.  Gaydar does not.  I think logging them
      # out is what i want to do unless i can find a good reason not to.
      #
      # NB. Be careful putting all of this 'time forward by 10 years' stuff
      # back in here - it is not being checked for anywhere else anymore! :)
      #
      #$query = " UPDATE `user~session` "
      #       . " SET updated = DATE_SUB(updated, INTERVAL 10 YEAR), "
      #       . " created = DATE_SUB(created, INTERVAL 10 YEAR) "
      #       . " WHERE session_id = ? "
      #       . " LIMIT 1 ";
      #
      #$sth = $dbh->prepare_cached($query);
      #
      #$sth->execute($session_id)
      #  || print $rusty->CGI->header
      #     && die "Could not invalidate other user's session: ".$dbh->errstr;
      #
      # If it's proxies (ie. AOL) then it could be the same user
      # logging in over the top of an existing login session.
      # So rather than showing an error, we are going to not show this
      # - just log the other person out and log the error as below.
      
      warn "Duplicate login attempted for '$profile_name' "
         . "(user_id $user_id): ip $session_ip_address was logged on when ip "
         . $ip_address." tried to login. ";
      
      #$rusty->exit;
    }
  }
  
  # We will be creating a new session in a second so we must first 
  # garbage collect all sessions for this user (should only be one max!).
  $rusty->cleanUpOldUserSession($user_id);
  
  # Log a session id to this ip address, without setting
  # the creation datetime (updated will be set anyway)
  
  # NOTE: You will need to load Apache's mod_unique_id
  # to get this UNIQUE_ID from the server.
  
  $session_id = $ENV{'UNIQUE_ID'};
  
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
  
  if ($rusty->{params}->{remember_me}) {
    # Does this person want to be remembered after this login?  If so,
    # set him a nice cookie to do so and make sure is stays for a while!
    push @{$rusty->{cookies}}, $rusty->CGI->cookie( -name    => "forgetmenot",
                                                    -value   => $profile_name,
                                                    -expires => '+10y' );
  } elsif ($rusty->{core}->{remembered_profile_name}) {
    # If profile name is already being remembered, (this variable is set
    # on object creation from the remembered profile name) -
    # they have chosen to unset it so let's deletify it! :)
    push @{$rusty->{cookies}}, $rusty->CGI->cookie( -name    => "forgetmenot",
                                                    -value   => '',
                                                    -expires => '-1d' );
  }
  
  # Create the session cookie with just session id contained.
  push @{$rusty->{cookies}}, $rusty->CGI->cookie( -name    => "test",
                                                  -value   => $session_id );
  
  if ($ref) {
    # On first call to login, escape the referrer's url..
    require URI::Escape;
    $ref = URI::Escape::uri_escape($ref);
  }
  # Call self with test parameter and test cookie (plus remember me cookie, if set)
  print $rusty->CGI->redirect( -url    => $rusty->CGI->url( -relative => 1 ) .
                                          "?mode=test" .
                                          ($ref ? "&ref=$ref" : ''),
                               -cookie => $rusty->{cookies} );
  $rusty->exit;
  
} elsif ($mode =~ /test/o) {
  
  # We are now being called from the line above to test cookies.
  # At this point, the login is verified and just needs this
  # final cookie check before we log them in and send them back.
  
  my $session_id = $rusty->CGI->cookie( -name => "test" );
  
  if (!$session_id) {
    
    # Cookies do not seem to be enabled..
    
    if ($mode eq 'signup_test') {
      
      # If a user is logging in after the initial signup,
      # log in the stats if they have cookies not enabled.
      # This will give us an overview of how many signups
      # did not have cookies enabled and when divided by
      # the num of signups that day, ooh it will give us
      # a pretty number! Whoop de jour.
      
      $query = <<ENDSQL
INSERT INTO `site~stats`
SET nocookies = 1,
    date = CURRENT_DATE()
ON DUPLICATE KEY
UPDATE nocookies = nocookies + 1
ENDSQL
;
      $sth = $dbh->prepare_cached($query);
      $sth->execute();
      $sth->finish;
    }
    
    # Redirect to the referring page with a little notice about enabling cookies
    # and a link that to a pretty page that tells you how to do it!
    # Doing a redirect stops peple refreshing to repeat the above step.
    # With URL to send user back to, add the nocookies=1 parameter to the
    # query string if it exists or add it as a query string if not - we
    # could do this ourselves but using URI::QueryParam is safer and easier! :)
    #print $rusty->CGI->redirect( -url => '/?nocookies=1' );
    #$rusty->exit;
    if ($ref) {
      require URI;
      require URI::QueryParam;
      my $uri = URI->new($rusty->{params}->{ref});
      $uri->query_param_append('nocookies','1');
      $ref = $uri->as_string;
    } else {
      $ref = '/?nocookies=1';
    }
    
    print $rusty->CGI->redirect( -url => $ref );
    $rusty->exit;

    
  } else {
    
    # Make sure session info in test cookie checks out - if yes,
    # set created datetime to the current time (to track how long a
    # user has spent online and when to logout due to inactivity).
    
    $query = <<ENDSQL
UPDATE `user~session`
SET created = NOW()
WHERE session_id = ?
  AND ip_address = ?
  AND created IS NULL
LIMIT 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($session_id, $ip_address);
    $sth->finish;
    
    if ($rusty->{core}->{'visitor_id'}) {
      
      # Remember what the user has been doing prior to logging in
      # (all activity within the last 30 mins) and add it to the
      # newly created user session..  This is not that important, it's
      # just a nice assumption that gives us more of an idea of how
      # much people are using the site and means less visitors' visits
      # are counted when they are really real people, really.
      $rusty->convertVisitorSessionToUserSession($rusty->{core}->{'visitor_id'}, $session_id);
    }
    
    # Update user statistics to reflect successful login
    $query = <<ENDSQL
UPDATE `user~stats` stats
INNER JOIN `user~session` session
        ON session.user_id = stats.user_id
SET stats.num_logins = stats.num_logins + 1
WHERE session.session_id = ?
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    my $rows = $sth->execute($session_id);
    $sth->finish;
    
    warn "user_id $rusty->{core}->{user_id} has no `user~stats` entry to update"
      if $rows eq '0E0';
    
    
    # Update site stats for number of logins per day
    $query = <<ENDSQL
INSERT INTO `site~stats`
SET logins = 1,
    date = CURRENT_DATE()
ON DUPLICATE KEY UPDATE logins = logins + 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute();
    $sth->finish;
    
    
    # Then set the test cookie to be deleted and create session cookie
    my $test_cookie_delete = $rusty->CGI->cookie( -name    => "test",
                                                  -value   => '',
                                                  -expires => '-1d' );
    
    my $session_cookie_add = $rusty->CGI->cookie( -name    => "session",
                                                  -value   => $session_id );
    
    # Go back to main page (no nasty long urls that confuse dimwits),
    # assuming that is the only place you can login (like facepatty).
    # This saves putting login crap everywhere and uglifying things,
    # just a "logged in" thingemy somewhere nice and discrete like.
    
    # Also set test cookie to be deleted and session cookie to be added.
    # And redirect back to original page OR if no referring url set (most
    # likely coming from the login page then, send to index page!).
    
    # With URL to send user back to, add the login=1 parameter to the
    # query string if it exists or add it as a query string if not - we
    # could do this ourselves but using URI::QueryParam is safer and easier! :)
    
    # And finally, if this is the login directly after successful signup,
    # display a special welcome page with link to ref.
    
    if ($mode eq 'signup_test') {
      
      $ref = "/?welcome=1&ref=" . URI::Escape::uri_escape($rusty->{params}->{ref});
      
    } elsif ($ref) {
      
      require URI;
      require URI::QueryParam;
      my $uri = URI->new($rusty->{params}->{ref});
      $uri->query_param_append('login','1');
      $ref = $uri->as_string;
      
    } else {
      
      $ref = '/?login=1';
    }

    
    print $rusty->CGI->redirect( -url => $ref,
                                 -cookie => [ $test_cookie_delete,
                                              $session_cookie_add ] );
    $rusty->exit;
  }
  
} else {
  
  # Make sure we do not redirect them back to this page..
  #undef $rusty->{core}->{'self_url'};
  
  # If called with a ref to a page, then let's make sure
  # we take them back there after logging in!
  if ($ref) {
    $rusty->{core}->{'ref'} = $ref;
    $rusty->{data}->{'redirected'} = 1;
  }
  
  $rusty->{data}->{genders} = [
    { value => "select", name => "Please Select", },
    { value => "male", name => "Male", },
    { value => "female",  name => "Female", },
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
  
  $rusty->process_template();
  $rusty->exit;
  
}
#elsif ($ENV{'QUERY_STRING'} eq "") {
#  
#  # Make sure that this page does not set itself for the referer after login
#  # otherwise it will loop! :)  Undefining it will be fine.. T'is the default.
#  undef $rusty->{core}->{'self_url'};
#  $rusty->process_template();
#  $rusty->exit;
#  
#} else {
#  
#  #print $rusty->CGI->header;
#  #die "Invalid query string '".$ENV{'QUERY_STRING'}."'";
#  print $rusty->CGI->redirect( -url => $rusty->CGI->url( -relative => 1 ) );
#  $rusty->exit;
#
#}

