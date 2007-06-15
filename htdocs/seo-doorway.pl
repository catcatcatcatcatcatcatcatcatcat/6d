#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

our $rusty = rusty::Profiles->new;

$rusty->{data}->{keyword} = $rusty->{params}->{keyword};

if ($rusty->{data}->{keyword} !~ /^(?:backpackers|hostels|friends|travels)$/) {
  # redirect to frontpage keyword given is not one we have configured
  print $rusty->CGI->redirect( -url => '/' );
  $rusty->exit;
}
$rusty->{ttml} = "seo-doorway.ttml";

$rusty->process_template;
$rusty->exit;
