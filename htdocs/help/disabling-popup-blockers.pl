#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

our $rusty = rusty::Profiles->new;

$rusty->{ttml} = "help/disabling-popup-blockers.ttml";

$rusty->process_template;
$rusty->exit;
