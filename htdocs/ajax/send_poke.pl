#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use rusty::Profiles;

# We're going to have to create an object here.  Might be slower but
# ideally we should have this efficient unless otherwise requested
# maybe an ajax-init function for new objects from here..

use vars qw($rusty);

$rusty = rusty::Profiles->new;

if (!$rusty->{core}->{profile_id}) {
  # Require login
  print "Status: 401\n\n";
  $rusty->exit;
}

# If a profile name has been specified, check it exists
# and get the associated profile id.  If not, send back with error.
if (length($rusty->{params}->{profile_name}) > 0) {
  
  $rusty->{data}->{profile_name} = $rusty->{params}->{profile_name};
  
  if (!($rusty->{data}->{profile_id} =
    $rusty->getProfileIdFromProfileName($rusty->{params}->{profile_name}))) {
    
    print "Status: 404\n\n";
    $rusty->exit;
    
  }
  
# If a profile id has been specified, check it exists
# and get the associated profile name.  If not, send back with error.
} elsif ($rusty->{params}->{profile_id} > 0) {
  
  $rusty->{data}->{profile_id} = $rusty->{params}->{profile_id};
  
  if (!($rusty->{data}->{profile_name} =
    $rusty->getProfileNameFromProfileId($rusty->{data}->{profile_id}))) {
    
    print "Status: 404\n\n";
    $rusty->exit;
    
  }
  
# If the fool has not specified any profile name or id, send them back!
} else {
  
  print "Status: 404\n\n";
  $rusty->exit;
  
}

# If profile id we're trying to poke is our own, say oops i'm a teapot!
if ($rusty->{core}->{profile_id} == $rusty->{data}->{profile_id}) {
  
  # Poking yourself?  Respond with HTTP Status 418: "I'm a little teapot"
  # http://en.wikipedia.org/wiki/List_of_HTTP_status_codes
  # http://www.ietf.org/rfc/rfc2324.txt
  print "Status: 418\n\n";
  $rusty->exit;
}

my $status = $rusty->sendPoke($rusty->{data}->{profile_id});

if (!$status) {
  # Cannot poke for some reason - say forbidden
  print "Status: 403\n\n";
  $rusty->exit;
}

print "Status: 200\n\n";

$rusty->exit;
