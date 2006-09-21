#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

our $rusty = rusty::Profiles->new;

$rusty->{ttml} = "help/faq.ttml";
$rusty->{data}->{title} = "Frequently Asked Questions";

$rusty->process_template;
$rusty->exit;
