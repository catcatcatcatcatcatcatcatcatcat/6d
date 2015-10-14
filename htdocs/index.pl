#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use Constants;

use rusty::Profiles;

my $rusty = rusty::Profiles->new;

my ($dbh, $query, $sth);

$dbh = $rusty->DBH;

$rusty->{ttml} = "index.ttml";

if ($rusty->{core}->{'user_id'}) {
  
  $rusty->populate_user_stats($rusty->{core}->{'user_id'});
}

$rusty->{data}->{'welcome'} = $rusty->{params}->{'welcome'};
$rusty->{core}->{'ref'} = $rusty->{params}->{'ref'};

$rusty->populate_site_stats();

$rusty->{data}->{genders} = [
  { value => "select", name => "Please Select", },
  { value => "male", name => "Male", },
  { value => "female",  name => "Female", },
                            ];

$rusty->{data}->{countries} = [
  { value => 'select', name => 'Please Select', },
  $rusty->get_ordered_lookup_list(
    table => "lookup_continent_country",
    id    => "country_code",
    data  => "name",
    order => "name",
                                 ),
                              ];

# Truncate long country names
foreach (@{$rusty->{data}->{countries}}) {
  if (length($_->{name}) > 30) {
    $_->{name} = substr($_->{name},0,27) . ' ...';
  }
}

# If user is logged in, get their pokes (if any) and show
if ($rusty->{core}->{'profile_name'}) {
  $rusty->{data}->{pokes} = $rusty->getPokes();
}

$rusty->process_template;
$rusty->exit;
