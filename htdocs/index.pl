#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

my $rusty = rusty::Profiles->new;

my ($dbh, $query, $sth);

$dbh = $rusty->DBH;

$rusty->{ttml} = "index.ttml";

$rusty->{data}->{'title'} = "Welcome ".$ENV{'REMOTE_ADDR'};


if ($rusty->{core}->{'user_id'}) {
  
  $rusty->populate_user_stats($rusty->{core}->{'user_id'});
}

$rusty->populate_site_stats();

$rusty->process_template;
$rusty->exit;
