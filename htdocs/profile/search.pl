#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use rusty::Profiles;

use Constants;

use vars qw($rusty $query $sth);

$rusty = rusty::Profiles->new;


# Prototypes:
sub populate_common_data();
sub _retrieve_previous_search($);
sub populate_previous_search($);


if ($rusty->{params}->{'nomatches'}) {
  $rusty->{data} = $rusty->{params}; #dirty but it works for now..
  $rusty->{data}->{'nomatches'} = 1;
} elsif ($rusty->{params}->{'search_id_invalid'}) {
  $rusty->{data} = $rusty->{params}; #dirty but it works for now..
  $rusty->{data}->{'search_id_invalid'} = 1;
} elsif ($rusty->{params}->{'search_id_missing'}) {
  $rusty->{data} = $rusty->{params}; #dirty but it works for now..
  $rusty->{data}->{'search_id_missing'} = 1;
} elsif ($rusty->{params}->{'advancedsearch'}) {
  $rusty->{data} = $rusty->{params}; #dirty but it works for now..
  $rusty->{data}->{'advancedsearch'} = 1;
} elsif ($rusty->{params}->{'advancedsearchtips'}) {
  $rusty->{data} = $rusty->{params}; #dirty but it works for now..
  $rusty->{data}->{'advancedsearch'} = 1;
  $rusty->{data}->{'advancedsearchtips'} = 1;
}




$rusty->{param_info} = {
  country_code           => { title => "Country" },
  subentity_code         => { title => "City" },
  gender                 => { title => "Gender",
                             regexp => '^(?:any|male|female)$' },
  sexuality              => { title => "Sexuality",
                             regexp => '^(?:any|straight|gay/lesbian|bisexual/curious)$' },
  age_min                => { title => "Minimum age",
                             regexp => '^(?:any|\\d+)$' },
  age_max                => { title => "Maximum age",
                             regexp => '^(?:any|\\d+)$' },
  relationship_status_id => { title => "Relationship Status",
                             regexp => '^(?:any|\\d+)$' },
  profile_name           => { title => "Profile Name",
                             regexp => '^\\^?[a-zA-Z0-9_\\*\\?]*\\$?$', maxlength => 20 },
  profile_name_search    => { title => "Search Type",
                             regexp => '^(?:partial|full|start|end)$' },
  onlyphotos             => { title => "Only Profiles with Photos",
                             regexp => '^1?$' },
  onlyonline             => { title => "Only People Online Now",
                             regexp => '^1?$' },
  onlyadult              => { title => "Only Adult Profiles",
                             regexp => '^1?$' },
  num_results_per_page   => { title => "Results per Page",
                             regexp => '^\\d+$' },
  offset                 => { title => "Page Offset",
                             regexp => '^\\d*$' }
};




if ($rusty->{params}->{'mode'} eq 'search') {
  
  # If this is 2nd call to search (with 'search' set),
  # we need to create the search result set and store
  # it in the database for this user so that any subsequent
  # requests for pages of results come from this cache and
  # don't keep asking the database for the original query..
  
  # Check that all the data we've been given is right.
  my $number_of_errors = $rusty->validate_params();
  
  if ($number_of_errors > 0) {
    
    # List errors in search submit set
    # (there should never be any except 'profile_name').
    $rusty->{data} = $rusty->{params}; #THIS IS LAZY BUT MEH.
    populate_common_data();
    
    if ($rusty->{core}->{'user_id'}) {
      $rusty->{data}->{search_prefs} = retrieve_search_prefs();
      $rusty->{data}->{remember} = $rusty->{data}->{search_prefs}->{remember_previous_search};
      populate_previous_search($rusty->{data}->{search_prefs}->{search_id})
        if $rusty->{data}->{search_prefs}->{search_id};
    }
    
    $rusty->{data}->{errors} = $rusty->{param_errors};
    $rusty->{ttml} = "profile/search.ttml";
    $rusty->process_template;
    $rusty->exit;
    
  }
  
  # User could be requesting that we fill up their cities list (no JS/AJAX)
  if ($rusty->{params}->{reloadareas}) {
    $rusty->{data} = $rusty->{params};
    populate_common_data();
    $rusty->{ttml} = "profile/search.ttml";
    $rusty->process_template;
    $rusty->exit;
    
  # Or re-allow them to select their countries list (still no JS/AJAX)
  } elsif ($rusty->{params}->{changecountry}) {
    $rusty->{data} = $rusty->{params};
    populate_common_data();
    delete $rusty->{params}->{enable_subentities_list};
    delete $rusty->{params}->{subentity_code};
    delete $rusty->{params}->{subentities};
    $rusty->{ttml} = "profile/search.ttml";
    $rusty->process_template;
    $rusty->exit;
  }
  
  my $countries =
    $rusty->get_lookup_hash(
      table => "lookup_continent_country",
      id    => "country_code",
      data  => "name" );
  
  my $subentities = {};
  if ($rusty->{params}->{country_code} =~ /^\w{2}$/ ) {
    $subentities =
      $rusty->get_lookup_hash(
        table => "lookup_continent_country_city1000",
        id    => "subentity_code",
        data  => "name",
        where => "country_code = '".$rusty->{params}->{country_code}."'" );
    $subentities->{OTHER} = 'Other';
  }
  
  my $relationship_statuses =
    $rusty->get_lookup_hash(
      table => "lookup_relationshipstatus",
      id    => "relationship_status_id",
      data  => "name" );
  
  $query = <<ENDSQL
SELECT up.profile_id
FROM `user_profile` up
INNER JOIN `user_info` ui ON ui.user_id = up.user_id
ENDSQL
;
  
  if ($rusty->{params}->{onlyonline} && $rusty->{params}->{onlyonline} == 1) {
    $query .= <<ENDSQL
LEFT JOIN `user_session` usess ON usess.user_id = up.user_id
ENDSQL
;
  }
  
  if (($rusty->{params}->{onlyadult} && $rusty->{params}->{onlyadult} == 1) ||
      ($rusty->{params}->{onlyphotos} && $rusty->{params}->{onlyphotos} == 1)) {
    $query .= <<ENDSQL
LEFT JOIN `user_profile_photo` ph ON ph.profile_id = up.profile_id
ENDSQL
;

  }
  
  $query .= <<ENDSQL
WHERE up.updated IS NOT NULL
ENDSQL
;
  
  my @bind_vars = ();
  my @search_params = ();
  
  if ($rusty->{params}->{subentity_code} && $rusty->{params}->{subentity_code} ne "any") {
    $query .= " AND ui.subentity_code = ? ";
    push @bind_vars, $rusty->{params}->{subentity_code};
    push @search_params, ucfirst($subentities->{$rusty->{params}->{subentity_code}});
  } else {
    delete $rusty->{params}->{subentity_code};
  }
  
  if ($rusty->{params}->{country_code} && $rusty->{params}->{country_code} ne "any") {
    $query .= " AND ui.country_code = ? ";
    push @bind_vars, $rusty->{params}->{country_code};
    push @search_params, ucfirst($countries->{$rusty->{params}->{country_code}});
  } else {
    delete $rusty->{params}->{country_code};
  }
  
  if ($rusty->{params}->{gender} ne "any") {
    $query .= " AND ui.gender = ? ";
    push @bind_vars, $rusty->{params}->{gender};
    push @search_params, ucfirst($rusty->{params}->{gender});
  } else {
    delete $rusty->{params}->{gender};
  }
  
  if ($rusty->{params}->{sexuality} ne "any") {
    $query .= " AND ui.sexuality = ? ";
    push @bind_vars, $rusty->{params}->{sexuality};
    push @search_params, ucfirst($rusty->{params}->{sexuality});
  } else {
    delete $rusty->{params}->{sexuality};
  }
  
  if ($rusty->{params}->{age_min} eq "any" &&
      $rusty->{params}->{age_max} eq "any") {
    
    undef $rusty->{params}->{age_min};
    undef $rusty->{params}->{age_max};
    
  } elsif ($rusty->{params}->{age_min} eq "any") {
    
    undef $rusty->{params}->{age_min};
    
    $query .= " AND age <= ? \n";
    
    push @bind_vars, $rusty->{params}->{age_max};
    push @search_params, "<".$rusty->{params}->{age_max};
    
  } elsif ($rusty->{params}->{age_max} eq "any") {
    
    undef $rusty->{params}->{age_max};
    
    $query .= " AND age >= ? \n";
    
    push @bind_vars, $rusty->{params}->{age_min};
    push @search_params, $rusty->{params}->{age_min}."+";
    
  } else {
    
    $rusty->{params}->{age_min} = 18
      if $rusty->{params}->{onlyadult} && $rusty->{params}->{age_min} < 18;
    $query .= " AND age >= ? \n";
    $query .= " AND age <= ? \n";
    
    push @bind_vars, ($rusty->{params}->{age_min}, $rusty->{params}->{age_max});
    push @search_params, $rusty->{params}->{age_min}."-".$rusty->{params}->{age_max};
  }
  
  # Make sure nobody can be rude (although these profiles shouldn't exist either!)
  if ($rusty->{params}->{onlyadult}) {
    $query .= " AND age >= 18 \n";
  }
  
  if ($rusty->{params}->{relationship_status_id} ne "any") {
    $query .= " AND up.relationship_status_id = ? \n";
    push @bind_vars, $rusty->{params}->{relationship_status_id};
    push @search_params, ucfirst($relationship_statuses->{$rusty->{params}->{relationship_status_id}});
  } else {
    delete $rusty->{params}->{relationship_status_id};
  }
  
  if (length($rusty->{params}->{profile_name}) > 0) {
    
    # First of all, escape all underscores so they are seen as such!
    (my $profile_name_sql = $rusty->{params}->{profile_name}) =~ s/_/\\_/og;
    
    # Advanced Searches: where a ? in the search term matches
    # a single character (regex style) - so a '_' for the sql 'LIKE'
    $profile_name_sql =~ s/\?/\_/og;
    # and a * in the search term matches 0, 1 or many characters
    # and therefore creates a '%' in the sql 'LIKE' search term.
    $profile_name_sql =~ s/\*/\%/og;
    
    # Regex-like 'start of' and 'end of' characters - if specified,
    # remove them to create no partial search at the start/end
    # otherwise add a '%' to partial match at start/end.
    $profile_name_sql = '%' . $profile_name_sql
      unless $profile_name_sql =~ s/^\^//o;
    $profile_name_sql .= '%'
      unless $profile_name_sql =~ s/\$$//o;
    
    # If an advanced search type has been selected, then set up the
    # search term to behave accordingly (override the stuff above!)
    if ($rusty->{params}->{profile_name_search} eq 'start') {
      push @search_params, "starting with \"$rusty->{params}->{profile_name}\"";
      $profile_name_sql =~ s/^\%//o;
    } elsif ($rusty->{params}->{profile_name_search} eq 'end') {
      push @search_params, "ending in \"$rusty->{params}->{profile_name}\"";
      $profile_name_sql =~ s/\%$//o;
    } elsif ($rusty->{params}->{profile_name_search} eq 'full') {
      push @search_params, "profile name \"$rusty->{params}->{profile_name}\"";
      $profile_name_sql =~ s/\%$//o;
      $profile_name_sql =~ s/^\%//o;
    } else {
      push @search_params, "matching \"$rusty->{params}->{profile_name}\"";
    }
    
    if ($profile_name_sql) {
      $query .= " AND up.profile_name LIKE \"$profile_name_sql\" ";
    }
    
  } else {
    delete $rusty->{params}->{profile_name};
  }
  
  my $profile_type_string = 'showing';
  if ($rusty->{params}->{onlyonline} && $rusty->{params}->{onlyonline} == 1) {
    $query .= " AND usess.updated > DATE_SUB(NOW(), INTERVAL 30 MINUTE) ";
    $profile_type_string .= ' online profiles';
    push @search_params, $profile_type_string . ' only';
  }
  if ($rusty->{params}->{onlyadult} && $rusty->{params}->{onlyadult} == 1) {
    $query .= " AND ph.adult != 0 ";
    push @search_params, $profile_type_string . ' with adult photos only';
  } else {
    delete $rusty->{params}->{onlyadult};
    if ($rusty->{params}->{onlyphotos} && $rusty->{params}->{onlyphotos} == 1) {
      $query .= " AND up.main_photo_id != 0 ";
      push @search_params, $profile_type_string . ' with photos only';
    } else {
      delete $rusty->{params}->{onlyphotos};
    }
  }
  
  $query .= <<ENDSQL
GROUP BY up.profile_id DESC
ORDER BY up.updated DESC
ENDSQL
;
  $query .= "LIMIT " . (Constants::PROFILE_SEARCH_MAX_RESULTS + 1);
  
  #warn "query: $query\n\nvars: ".join(', ',@bind_vars);
  $sth = $rusty->DBH->prepare($query);
  $sth->execute(@bind_vars);
  my $count = 0;
  my @profiles = ();
  
  while (my $profile = $sth->fetchrow_hashref) {
    # If we have got the one extra result past the amount we are
    # allowed on a page, we can tell the user that their search
    # exceeded this and has been truncated to the max allowed..
    last if ++$count > Constants::PROFILE_SEARCH_MAX_RESULTS;
    push @profiles, $profile->{'profile_id'};
  }
  $sth->finish;
  
  $query = <<ENDSQL
INSERT INTO `user_profile_search_cache`
SET user_id = ?,
    visitor_id = ?,
    gender = ?,
    sexuality = ?,
    age_min = ?,
    age_max = ?,
    country_code = ?,
    subentity_code = ?,
    profile_name = ?,
    onlyphotos = ?,
    onlyonline = ?,
    onlyadult = ?,
    relationship_status_id = ?,
    search_string = ?,
    num_results = ?,
    num_results_per_page = ?,
    result_set = ?
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute(
    ($rusty->{core}->{'user_id'} || undef),
    ($rusty->{core}->{'visitor_id'} || undef),
    $rusty->{params}->{gender},
    $rusty->{params}->{sexuality},
    $rusty->{params}->{age_min},
    $rusty->{params}->{age_max},
    $rusty->{params}->{country_code},
    $rusty->{params}->{subentity_code},
    $rusty->{params}->{profile_name},
    $rusty->{params}->{onlyphotos},
    $rusty->{params}->{onlyonline},
    $rusty->{params}->{onlyadult},
    $rusty->{params}->{relationship_status_id},
    join(', ', @search_params),
    ($count || 0),
    $rusty->{params}->{num_results_per_page},
    join(',', @profiles)
  );
  $sth->finish;
  
  # Get the search id of the search cache we just created
  my $search_id = $rusty->DBH->{mysql_insertid};
  
  if ($rusty->{core}->{'user_id'}) {
    
    $query = <<ENDSQL
INSERT DELAYED INTO `user_stats`
SET user_id = ?, num_profile_searches = 1
ON DUPLICATE KEY
UPDATE num_profile_searches = num_profile_searches + 1
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{core}->{'user_id'});
    $sth->finish;
    
    $query = <<ENDSQL
INSERT INTO `user_profile_search_prefs`
SET user_id = ?,
    remember_previous_search = ?,
    search_id = ?,
    num_results_per_page = ?
ON DUPLICATE KEY
UPDATE remember_previous_search = ?,
       search_id = ?,
       num_results_per_page = ?
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute(
      $rusty->{core}->{'user_id'},
      ($rusty->{params}->{remember} || 0),
      $search_id,
      $rusty->{params}->{num_results_per_page},
      ($rusty->{params}->{remember} || 0),
      $search_id,
      $rusty->{params}->{num_results_per_page}
    );
    $sth->finish;
    
  } elsif ($rusty->{core}->{'visitor_id'}) {
    
    $query = <<ENDSQL
UPDATE `visitor_stats`
SET num_profile_searches = num_profile_searches + 1
WHERE visitor_id = ?
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($rusty->{core}->{'visitor_id'});
    $sth->finish;
    
    $query = <<ENDSQL
INSERT INTO `visitor_profile_search_prefs`
SET visitor_id = ?,
    remember_previous_search = ?,
    search_id = ?,
    num_results_per_page = ?
ON DUPLICATE KEY
UPDATE remember_previous_search = ?,
       search_id = ?,
       num_results_per_page = ?
ENDSQL
;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute(
      $rusty->{core}->{'visitor_id'},
      ($rusty->{params}->{remember} || 0),
      $search_id,
      $rusty->{params}->{num_results_per_page},
      ($rusty->{params}->{remember} || 0),
      $search_id,
      $rusty->{params}->{num_results_per_page}
    );
    $sth->finish;
  }
  
  # If no results were found,
  # redirect back to the search page with a nice error message!
  if ($count == 0) {
    #my $url = $rusty->{core}->{'self_url'};
    #$url =~ s/mode=search/nomatches=1/;
    #print $rusty->redirect( -url => $url );
    print $rusty->redirect( -url => '/profile/search.pl?nomatches=1' );
  } else {
    print $rusty->redirect( -url    => $rusty->CGI->url( -relative => 1 ) . "?mode=results&search_id=$search_id" );
  }
  $rusty->exit;
  
} elsif ($rusty->{params}->{'mode'} eq 'results') {
  
  # If this is a request for a page of results (called after initial search
  # is run) and on subsequent search result page requests, both of which will
  # want a subset of results from a user's search .
  
  $rusty->{ttml} = "profile/search-results.ttml";
  
  # I love this feature so now it's on by default (unless it's explictly off (rejoin_search=0)!)
  $rusty->{params}->{rejoin_search} = 1 if !defined($rusty->{params}->{rejoin_search});
  
  # If no search id given, grab the last search they did and send them to those results
  # and if no last search found, send them back to the search page!
  if (!$rusty->{params}->{search_id}) {
    my $search_prefs = $rusty->getSearchPrefs();
    $rusty->{params}->{search_id} = $search_prefs->{search_id};
    if (!$rusty->{params}->{search_id}) {
      print $rusty->redirect( -url => '/profile/search.pl?search_id_missing=1' );
    } else {
      print $rusty->redirect( -url => '/profile/search.pl?mode=results&search_id='
                                    . $rusty->{params}->{search_id} . '&rejoin_search='
                                    . $rusty->{params}->{rejoin_search} );
    }
    $rusty->exit;
  }
  
  my $search_results = $rusty->getSearchResults($rusty->{params}->{search_id},
                                                $rusty->{params}->{offset},
                                                $rusty->{params}->{num_results_per_page},
                                                $rusty->{params}->{rejoin_search});
  if (!$search_results) {
    if ($! == Constants::STATUS_REQUIRE_LOGIN) {
      $rusty->redirectToLoginPage($rusty->{core}->{'self_url'});
    } elsif (!$rusty->{params}->{search_id}) {
      print $rusty->redirect( -url => '/profile/search.pl?search_id_missing=1' );
    } else {
      print $rusty->redirect( -url => '/profile/search.pl?search_id_invalid=1' );
    }
    $rusty->exit;
  }
  
  $rusty->{data}->{search_id}            = $search_results->{search_id};
  $rusty->{data}->{search_age_in_mins}   = $search_results->{search_age_in_mins};
  $rusty->{data}->{search_string}        = $search_results->{search_string};
  $rusty->{data}->{num_results}          = $search_results->{num_results};
  $rusty->{data}->{num_results_per_page} = $search_results->{num_results_per_page};
  $rusty->{data}->{offset}               = $search_results->{offset};
  $rusty->{data}->{prev_page_offset}     = $search_results->{prev_page_offset};
  $rusty->{data}->{next_page_offset}     = $search_results->{next_page_offset};
  $rusty->{data}->{first_results_page}   = $search_results->{first_results_page};
  $rusty->{data}->{last_results_page}    = $search_results->{last_results_page};
  $rusty->{data}->{results_pages}        = $search_results->{results_pages};
  $rusty->{data}->{total_results_pages}  = $search_results->{total_results_pages};
  $rusty->{data}->{current_results_page} = $search_results->{current_results_page};
  $rusty->{data}->{profiles}             = $search_results->{profiles};
  
  $rusty->process_template;
  $rusty->exit;
  
} else {
  
  # Initial call to page - just get lookups and show search form.
  
  if ($rusty->{core}->{'user_id'} || $rusty->{core}->{'visitor_id'}) {
    
    $rusty->{data}->{search_prefs} = $rusty->getSearchPrefs();
    $rusty->{data}->{num_results_per_page} = $rusty->{data}->{search_prefs}->{num_results_per_page};
    if ($rusty->{data}->{search_prefs}->{remember_previous_search} ||
        $rusty->{params}->{'nomatches'} ||
        #$rusty->{params}->{'advancedsearch'} ||
        #$rusty->{params}->{'advancedsearchtips'} ||
        $rusty->{params}->{'repopulate'}) {
      
      $rusty->{data}->{'repopulate'} = 1;
      
      populate_previous_search($rusty->{data}->{search_prefs}->{search_id})
        if $rusty->{data}->{search_prefs}->{search_id};
      
    }
  }
  
  populate_common_data();
  
  if ($rusty->{data}->{search_prefs}->{remember_previous_search} ||
      !$rusty->{data}->{search_prefs}->{search_id}) {
    $rusty->{data}->{remember} = 1;
  } else {
    delete $rusty->{data}->{remember};
  }
  
  $rusty->{ttml} = "profile/search.ttml";
  $rusty->process_template;
  $rusty->exit;
  
}




sub populate_common_data() {
  
  #$rusty->{data}->{countries} = [
  #  $rusty->get_ordered_lookup_list(
  #    table => "lookup_continent_country",
  #    id    => "country_code",
  #    data  => "name",
  #    order => "name",
  #                                 ),
  #                              ];
  # Get bounding box info to display countries on a map nicely :)
  $query = <<ENDSQL
SELECT SQL_CACHE country_code AS value, name AS name,
       bounding_box_west AS west,
       bounding_box_north AS north,
       bounding_box_east AS east,
       bounding_box_south AS south
FROM `lookup_continent_country`
ORDER BY name
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute();
  while (my $countryinfo = $sth->fetchrow_hashref) {
    push @{$rusty->{data}->{countries}}, $countryinfo;
  }
  $sth->finish;
  
  # Truncate long country names
  foreach (@{$rusty->{data}->{countries}}) {
    if (length($_->{name}) > 30) {
      $_->{name} = substr($_->{name},0,27) . ' ...';
    }
  }
  
  $rusty->{data}->{relationship_statuses} =
    [$rusty->get_ordered_lookup_list(
      table => "lookup_relationshipstatus",
      id    => "relationship_status_id",
      data  => "name",
      where => "relationship_status_id != 1" )];
  
  my $country_code = ($rusty->{params}->{country_code} || $rusty->{data}->{country_code});
  
  # TODO: don't we zoom in on a place if it has been remembered from a previous search?
  if ($country_code && $country_code ne 'any') {
    $query = <<ENDSQL
SELECT SQL_CACHE subentity_code, name AS subentity_name
FROM `lookup_continent_country_city1000`
WHERE country_code = ?
ORDER BY name
ENDSQL
    ;
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($country_code);
    $rusty->{params}->{enable_subentities_list} = 1;
    while (my ($subentity_code, $subentity_name) = $sth->fetchrow_array) {
      push @{$rusty->{data}->{subentities}}, { value => $subentity_code, name => $subentity_name };
    }
    $sth->finish;
    
    $query = <<ENDSQL
SELECT SQL_CACHE name, capital, population,
                 areaInSqKm, currency, languages,
                 CONCAT(IF(bounding_box_north>=0,
                           CONCAT(FORMAT(bounding_box_north,3),'&deg;N'),
                           CONCAT(FORMAT(bounding_box_north*-1,3),'&deg;S')), ' - ',
                        IF(bounding_box_south>=0,
                           CONCAT(FORMAT(bounding_box_south,3),'&deg;N'),
                           CONCAT(FORMAT(bounding_box_south*-1,3),'&deg;S'))) AS latitude,
                 CONCAT(IF(bounding_box_east>=0,
                           CONCAT(FORMAT(bounding_box_east,3),'&deg;E'),
                           CONCAT(FORMAT(bounding_box_east*-1,3),'&deg;W')), ' - ',
                        IF(bounding_box_west>=0,
                           CONCAT(FORMAT(bounding_box_west,3),'&deg;E'),
                           CONCAT(FORMAT(bounding_box_west*-1,3),'&deg;W'))) AS longitude
FROM `lookup_continent_country`
WHERE country_code = ?
LIMIT 1
ENDSQL
;
    
    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($country_code);
    $rusty->{data}->{country_info} = $sth->fetchrow_hashref;
    $rusty->{data}->{country_info}->{areaInSqKm} =~ s/\.0$//;
    $rusty->{data}->{country_info}->{capital} ||= 'N/A';
    $rusty->{data}->{country_info}->{currency} ||= 'N/A';
    $rusty->{data}->{country_info}->{languages} ||= 'N/A';
    $sth->finish;
  }

  my $subentity_code = ($rusty->{params}->{subentity_code} || $rusty->{data}->{subentity_code});
  
  if ($subentity_code && $subentity_code ne 'any') {
    $query = <<ENDSQL
SELECT SQL_CACHE c.subentity_code, c.name,
       c.latitude, c.longitude,
       c.population, c.elevation,
       c.TimeZoneId AS timezone,
       t.GMT_offset_2007_01_01 AS timezone_offset,
       IF(c.latitude>=0,
          CONCAT(FORMAT(c.latitude,3),'&deg;N'),
          CONCAT(FORMAT(c.latitude*-1,3),'&deg;S')) AS latitude_formatted,
       IF(c.longitude>=0,
          CONCAT(FORMAT(c.longitude,3),'&deg;E'),
          CONCAT(FORMAT(c.longitude*-1,3),'&deg;W')) AS longitude_formatted
FROM `lookup_continent_country_city1000` c
LEFT JOIN `lookup_continent_country_city1000_timezones` t
       ON t.TimeZoneId = c.TimeZoneId
WHERE c.subentity_code = ?
LIMIT 1
ENDSQL
;

    $sth = $rusty->DBH->prepare_cached($query);
    $sth->execute($subentity_code);
    $rusty->{data}->{subentity_info} = $sth->fetchrow_hashref;
    #$rusty->{data}->{subentity_info}->{languages} ||= 'N/A';
    $rusty->{data}->{subentity_info}->{timezone_offset} =~ s/\.0$//o;
    $rusty->{data}->{subentity_info}->{timezone_offset} =~ s/^(?!-)/\+/;
    $rusty->{data}->{subentity_info}->{timezone_offset} = 'GMT' . $rusty->{data}->{subentity_info}->{timezone_offset};
    $rusty->{data}->{subentity_info}->{elevation} ||= 'unknown';
    utf8::decode($rusty->{data}->{subentity_info}->{subentity_name});
    $sth->finish;
  }
}




sub populate_previous_search($) {
  
  my $search_id = shift or return;
  
  my $query = <<ENDSQL
SELECT search_id, created,
       gender, sexuality, age_min, age_max,
       country_code, subentity_code, profile_name,
       onlyphotos, onlyonline, onlyadult,
       relationship_status_id
FROM `user_profile_search_cache`
WHERE search_id = ?
LIMIT 1
ENDSQL
;
  $sth = $rusty->DBH->prepare_cached($query);
  $sth->execute($search_id);
  my $previous_search = $sth->fetchrow_hashref;
  $sth->finish;
  return unless $previous_search->{search_id};
  
  $rusty->{data}->{search_age_in_mins} = $previous_search->{search_age_in_mins};
  $rusty->{data}->{gender} = $previous_search->{gender};
  $rusty->{data}->{sexuality} = $previous_search->{sexuality};
  $rusty->{data}->{age_min} = $previous_search->{age_min};
  $rusty->{data}->{age_max} = $previous_search->{age_max};
  # Try to recreate the age_range field (if it was used originally)
  # This is a quick hack and should be passed around properly! Or taken out..
  #$rusty->{data}->{age_range} = ($previous_search->{age_min} ? $previous_search->{age_min} : '18')
  #                            . ($previous_search->{age_max} ? $previous_search->{age_max} : 'plus');
  $rusty->{data}->{country_code} = $previous_search->{country_code};
  $rusty->{data}->{subentity_code} = $previous_search->{subentity_code};
  $rusty->{data}->{profile_name} = $previous_search->{profile_name};
  $rusty->{data}->{onlyphotos} = $previous_search->{onlyphotos};
  $rusty->{data}->{onlyonline} = $previous_search->{onlyonline};
  $rusty->{data}->{onlyadult} = $previous_search->{onlyadult};
  $rusty->{data}->{relationship_status_id} = $previous_search->{relationship_status_id};
  $rusty->{data}->{previous_search} = $previous_search;
  
  if ($rusty->{data}->{subentity_code}) {
    $rusty->{params}->{enable_subentities_list} = 1;
  }
}

