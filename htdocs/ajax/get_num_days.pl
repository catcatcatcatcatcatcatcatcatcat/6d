#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use rusty;

rusty::init();

my $params = rusty::get_utf8_params();



require Time::DaysInMonth;

die unless $params->{year} > 0 && 
           $params->{month} >= 1 && 
           $params->{month} <= 12;

my $days = Time::DaysInMonth::days_in($params->{year}, $params->{month});

print "Content-type: text/plain\n\n$days";
