#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

use vars qw($rusty $query $sth);

$rusty = rusty::Profiles->new;


if (!$rusty->{core}->{'user_id'}) {
  require URI::Escape;
  print $rusty->CGI->redirect( -url => "/login.pl?ref="
                                     . URI::Escape::uri_escape($rusty->{core}->{'self_url'}) );
  $rusty->exit;
} elsif ($rusty->{core}->{profile_info}->{'deleted_date'}) {
  print $rusty->CGI->redirect( -url => "/profile/account.pl?deleted=1" );
  $rusty->exit;
}

if (!$rusty->{core}->{'profile_id'} && !$rusty->{params}->{prev_action}) {
  
  # If we have no profile & we're not redirected from this (prev_action set)
  require URI::Escape;
  print $rusty->CGI->redirect( -url => "/profile/account.pl?ref="
                                     . URI::Escape::uri_escape($rusty->{core}->{'self_url'}) );
  $rusty->exit;
}


$_ = $rusty->{params}->{mode};
SWITCH:
{
  &list, last SWITCH if /^list$/;
  
  # Default behaviour: list
  $rusty->{data}->{errors}->{mode} = "mode $_ is not defined" if $_;
  &list;
}

$rusty->exit;




sub list {
  
  $rusty->{ttml} = "profile/visitors/list.ttml";
  
  if ($rusty->{core}->{'profile_id'}) {
      $rusty->{data}->{recent_visitors} =
        $rusty->getRecentProfileVisitorsDetailed($rusty->{core}->{'profile_id'},
                                                 101);
  }
  
  $rusty->{data}->{countries} = [
    $rusty->get_ordered_lookup_list(
      table => "lookup~continent~country",
      id    => "country_id",
      data  => "name",
      order => "name",
                                   ),
                                ];
  
  $rusty->{data}->{age_min} = $rusty->{params}->{age_min};
  $rusty->{data}->{age_max} = $rusty->{params}->{age_max};
  $rusty->{data}->{gender} = $rusty->{params}->{gender};
  $rusty->{data}->{country_id} = $rusty->{params}->{country_id};
  
  $rusty->process_template;
}
