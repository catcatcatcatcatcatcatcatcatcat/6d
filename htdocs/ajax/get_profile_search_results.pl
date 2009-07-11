#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use rusty::Profiles;

# We're going to have to create an object here.  Might be slower but
# ideally we should have this efficient unless otherwise requested
# maybe an ajax-init function for new objects from here..

use vars qw($rusty $query $sth);

$rusty = rusty::Profiles->new;

if (!$rusty->{params}->{search_id}) {
  print "Status: 404\n\n";
  $rusty->exit;
}

# If this is a request for a page of results (called after initial search
# is run) and on subsequent search result page requests, both of which will
# want a subset of results from a user's search..
my $search_results = $rusty->getSearchResults($rusty->{params}->{search_id},
                                              $rusty->{params}->{offset},
                                              $rusty->{params}->{num_results_per_page},
                                              $rusty->{params}->{rejoin_search});
if (!$search_results) {
  if ($! == Constants::STATUS_REQUIRE_LOGIN) {
    # Require login
    print "Status: 401\n\n";
    $rusty->exit;
  } else {
    # Cannot retrieve
    print "Status: 404\n\n";
    $rusty->exit;
  }
}
$rusty->{data}->{search_age_in_mins}    = $search_results->{search_age_in_mins};
$rusty->{data}->{search_string}         = $search_results->{search_string};
$rusty->{data}->{num_results}           = $search_results->{num_results};
$rusty->{data}->{num_results_per_page}  = $search_results->{num_results_per_page};
$rusty->{data}->{offset}                = $search_results->{offset};
$rusty->{data}->{prev_page_offset}      = $search_results->{prev_page_offset};
$rusty->{data}->{next_page_offset}      = $search_results->{next_page_offset};
$rusty->{data}->{first_results_page}    = $search_results->{first_results_page};
$rusty->{data}->{last_results_page}     = $search_results->{last_results_page};
$rusty->{data}->{results_pages}         = $search_results->{results_pages};
$rusty->{data}->{total_results_pages}   = $search_results->{total_results_pages};
$rusty->{data}->{current_results_page}  = $search_results->{current_results_page};
$rusty->{data}->{profiles}              = $search_results->{profiles};
$rusty->{data}->{num_profiles_returned} = scalar @{$search_results->{profiles}};

$rusty->{data}->{search_id} = $rusty->{params}->{search_id};

print "Content-type: application/json; charset=UTF-8\n\n";

#$rusty->{ttml} = "profile/includes/search-results-profile-block.ttml";
#my $output = $rusty->process_template( noheader => 1,
#                                       return_output => 1 );
#print json_encode(%$search_results, 'profiles_html' => $output);

$rusty->{ttml} = "ajax/get-profile-search-results.ttml";
my $output = $rusty->process_template( noheader => 1,
                                       return_output => 1 );

print $output;

$rusty->exit;
