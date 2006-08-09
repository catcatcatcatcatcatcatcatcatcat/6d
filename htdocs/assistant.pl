#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty;

my $rusty = rusty->new;

my ($dbh, $query, $sth);

$dbh = $rusty->DBH;
 


$rusty->{ttml} = "assistant.ttml";
$rusty->{data}->{session_cookie} = $rusty->session_cookie;
$rusty->{data}->{word1} = $rusty->random_word();
$rusty->{data}->{word2} = $rusty->random_word();



if ($rusty->{params}->{firstopen}) {
  # If first call to assistant, do things you need to
  # (just self.focus() at the moment! :) and call the
  # normal version of the script in a refresh soon after!
  $rusty->{data}->{firstopen} = 1;
  $rusty->process_template( refresh => '10; URL=/assistant.pl',
                            nocache => 1,
                            nopageclick => 1 );
} else {
  # Out refreshes every 120, gaydar 160 & faceparty 120.
  # Faceparty refreshes using javascript (YUK!)
  # I do 60 just to get instant messaging responses feeling
  # faster for users! Hee hee. Maybe someone will notice.
  # Probably the overloaded server. Agh well. Can be changed.
  $rusty->process_template( refresh => '60',
                            nocache => 1,
                            nopageclick => 1 );
}


$rusty->exit;

