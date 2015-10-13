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

my $pokes = $rusty->getPokes($rusty->{core}->{profile_id});

if (!$pokes) {
  # Cannot retrieve
  print "Status: 404\n\n";
  $rusty->exit;
}

print "Content-type: application/json; charset=UTF-8\n\n";
print json_encode(@$pokes);

$rusty->exit;
