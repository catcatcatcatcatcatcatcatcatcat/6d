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

# The unread message count info is now collected on new profile object creation..
#$rusty->{data}->{new_messages_count} =
#  $rusty->getNewMessagesCount($rusty->{core}->{'profile_id'});

$rusty->{data}->{friends_online} =
  $rusty->getOnlineFriendProfileNames($rusty->{core}->{'profile_id'});

$rusty->{data}->{faves_online} =
  $rusty->getOnlineFaveProfileNames($rusty->{core}->{'profile_id'});

$rusty->{data}->{recent_visits} =
  $rusty->getRecentProfileVisitors($rusty->{core}->{'profile_id'}, 10);

$rusty->{ttml} = "assistant.ttml";


if ($rusty->{params}->{firstopen}) {
  # If first call to assistant, do things you need to
  # (just self.focus() at the moment! :) and call the
  # normal version of the script in a refresh soon after!
  $rusty->{data}->{firstopen} = 1;
  $rusty->process_template( refresh => '10; URL=/assistant.pl',
                            nocache => 1,
                            nopageclick => 1 );
} else {
  # Others refresh every 120 (x2), 160.
  # One refreshes using javascript (YUK!)
  # I do 60 just to get instant messaging responses feeling
  # faster for users! Hee hee. Maybe someone will notice.
  # Probably the overloaded server. Agh well. Can be changed.
  $rusty->process_template( refresh => '60',
                            nocache => 1,
                            nopageclick => 1 );
}


$rusty->exit;

