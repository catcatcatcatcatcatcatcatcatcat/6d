package rusty::Profiles::Search;

use strict;

use lib "../..";

use warnings qw( all );

no warnings qw( uninitialized );

use Constants;


sub getSearchResults($) {
  
  my $self = shift;
  
  my $search_id = shift;
  my $offset = shift;
  my $num_results_per_page = shift;
  my $rejoin_search = shift;
  
  return undef unless $search_id;
  
  my $dbh = $self->DBH;
  
  # This is the stuff we send back..
  my $search_results;
  
  my $query = <<ENDSQL
SELECT FLOOR((UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(created)) / 60) AS search_age_in_mins,
       search_id,
       user_id, visitor_id,
       search_string, num_results,
       result_set, last_page_offset,
       num_results_per_page,
       onlyonline
FROM `user~profile~search~cache`
WHERE search_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $self->DBH->prepare_cached($query);
  $sth->execute($search_id);
  my $search_cache = $sth->fetchrow_hashref;
  $sth->finish;
  
  $search_results->{search_age_in_mins} = $search_cache->{search_age_in_mins};
  $search_results->{onlyonline} = $search_cache->{onlyonline};
  $num_results_per_page ||= $search_cache->{num_results_per_page};
  
  if (!$search_cache->{search_id}) {
    
    warn "user trying to view search result that doesn't exist!";
    return undef;
    
  }
  
  # If we are logged in..
  if ($self->{core}->{'user_id'}) {
    
    # If logged in and search we are trying to view is linked to a user
    if ($search_cache->{'user_id'}) {
      
      # If the search they are requesting is linked to a user, check the
      # search they are requesting belongs to them..  If not, complain!
      if ($search_cache->{'user_id'} != $self->{core}->{'user_id'}) {
        
        warn "user trying to view search result that isn't theirs! (user_id: "
           . $self->{core}->{'user_id'} . " trying to view search_id: $search_id)";
        return undef;
        
      }
      
    # If logged in and the search they are requesting is linked only to a visitor
    } else {
      
      # If we still have a visitor id from before we logged in,
      # check to see if it is them as a visitor just before they logged in
      # and if it is, then add this user as the owner, letting them access
      # it and stop future checks.
      if ($self->{core}->{'visitor_id'} &&
          $self->{core}->{'visitor_id'} == $search_cache->{'visitor_id'}) {
        
        $query = <<ENDSQL
UPDATE `user~profile~search~cache`
SET user_id = ?
WHERE search_id = ?
user_id IS NULL
visitor_id = ?
ENDSQL
;
        $sth = $self->DBH->prepare_cached($query);
        my $rows = $sth->execute($self->{core}->{'user_id'},
                                 $search_id,
                                 $self->{core}->{'visitor_id'});
        $sth->finish;
        warn "converted search result from visitor to logged in user for search $search_id";
        
      # If not, give an error. :)
      } else {
        
        warn "user trying to view search result that isn't theirs!";
        return undef;
        
      }
    }
    
  # If we are not logged in but we have a visitor id
  } elsif ($self->{core}->{'visitor_id'}) {
    
    # ..and the search we are looking for isn't ours
    if ($search_cache->{'visitor_id'} != $self->{core}->{'visitor_id'}) {
      
      # If the person viewing the search is not logged in but has a visitor
      # session (cookies enabled), check the search belongs to them..
      # If not, complain!
      warn "visitor trying to view search result that isn't theirs! (visitor_id: "
         . $self->{core}->{'visitor_id'} . " trying to view search_id: $search_id)";
      $! = Constants::STATUS_REQUIRE_LOGIN;
      return undef;
    
    } else {
      
      warn "whoop de jour";
    }
    
  # If we are not logged in or have a visitor id (cookies not enabled)
  } else {
    
    # If this user doesn't have cookies enabled so is neither logged in nor
    # tracked as a visitor, then let them see this search result (as long
    # as it is also not linked to a visitor or a user!) - i am not sure why
    # i am doing this option but hey ho, completeness is fun and perhaps
    # we should make the site work for everyone we can before they sign up!
    # this shouldn't be open to abuse as there won't be many people without
    # cookies and nobody else would ever guess their search id!
    if (!$search_cache->{'user_id'} && !$search_cache->{'visitor_id'}) {
      
      warn "someone requesting search results without a user_id or visitor_id"
         . " (almost certainly not got cookies enabled)";
      
    # Disallow access if this search belongs to someone else and they have zero
    # credentials.. :)
    } else {
      
      warn "non-user and non-visitor trying to view search result that is linked to (visitor_id: "
         . $search_cache->{'visitor_id'} . " or user: " . $search_cache->{'visitor_id'}
         . "for search id: $search_id)";
      $! = Constants::STATUS_REQUIRE_LOGIN;
      return undef;
    }
  }
  
  $search_results->{search_string} = $search_cache->{search_string};
  $search_results->{search_string} ||= "All Profiles";
  $search_results->{num_results} =
    $search_cache->{num_results} > Constants::PROFILE_SEARCH_MAX_RESULTS ?
      "over " . Constants::PROFILE_SEARCH_MAX_RESULTS : $search_cache->{num_results};
  
  if ($rejoin_search == 1 && !defined($offset)) {
    $offset = $search_cache->{last_page_offset};
  }
  
  $offset ||= 0;
  
  my $page_limit = $num_results_per_page;
  
  # If the offset requested will get profiles past our total limit,
  # change the number retrieved for the page to end at this limit.
  if (($offset + $num_results_per_page) > Constants::PROFILE_SEARCH_MAX_RESULTS) {
    $page_limit = Constants::PROFILE_SEARCH_MAX_RESULTS - $offset;
  }
  
  # Generate link back to first X results (we are offset already).
  if ($offset > 0) {
    my $last_page_offset = $offset - $num_results_per_page;
    $last_page_offset = 0 if ($last_page_offset < 0);
    $search_results->{prev_page_offset} = $last_page_offset;
  }
  
  my @profile_ids = split /,/, $search_cache->{result_set};
  
  # Do extra robust check just to make sure that our indexes are not going to
  # take us out of the array of results (shouldn't happen, but good to check!
  if ($offset > $#profile_ids) {
    # If the lower boundary is out of array range, send them to the search page.
    print $self->redirect( -url => '/profile/search.pl?outofrange=1' );
    $self->exit;
  } elsif (($offset + ($page_limit - 1)) > $#profile_ids) {
    # If just the upper boundary is out of array range, lower it to end of array.
    $page_limit = @profile_ids - $offset; #is this right??
  }
  
  my @desired_profile_ids = splice(@profile_ids, $offset, $page_limit);
  
  $query = <<ENDSQL
SELECT DISTINCT(up.profile_name) AS profile_name, up.profile_id,
ui.gender, ui.sexuality, ui.age,
lco.name AS country, lcs.name AS subentity
#up.height, up.weight, up.waist,
#up.hair, up.website, up.profession,
#up.perfect_partner, up.bad_habits,
#up.happy, up.sad, up.own_words,
#up.interests, up.weight_type,
#up.fave_food, up.fave_music, up.fave_tvshow,
#up.fave_author, up.fave_movie, up.fave_club_bar,
#up.fave_animal, up.fave_person, up.fave_website,
#up.fave_place, up.fave_thing,
#up.thought_text
FROM `user~profile` up
INNER JOIN `user~info` ui ON ui.user_id = up.user_id
LEFT JOIN `lookup~continent~country` lco ON lco.country_code = ui.country_code
LEFT JOIN `lookup~continent~country~city1000` lcs ON lcs.subentity_code = ui.subentity_code
LEFT JOIN `user~profile~photo` ph ON ph.profile_id = up.profile_id
WHERE up.updated IS NOT NULL
AND up.profile_id = ?
ENDSQL
;
  $sth = $self->DBH->prepare_cached($query);
  
  foreach my $profile_id (@desired_profile_ids) {
    # Just get the info we need.
    #my $profile = $self->getProfileInfo($profile_id);
    $sth->execute($profile_id);
    my $profile = $sth->fetchrow_hashref;
    
    $profile->{photo} = $self->getMainPhoto($profile_id);
    $profile->{adult} = $self->hasAdultPics($profile_id);
    push @{$search_results->{profiles}}, $profile;
  }
  $sth->finish;
  
  # Update our search cache so we know how much the search has been used
  # (how many search results pages have been requested)
  $query = <<ENDSQL
UPDATE `user~profile~search~cache`
SET results_pages_requested = results_pages_requested + 1,
    last_page_offset = ?,
    num_results_per_page = ?,
    last_request_date = NOW()
WHERE search_id = ?
LIMIT 1
ENDSQL
;
  $sth = $self->DBH->prepare_cached($query);
  $sth->execute($offset, $num_results_per_page, $search_id);
  $sth->finish;
  

  # Generate link for next X results (if there are any more to come
  # and if there are any more allowed (this should already be limited
  # by the original search to be within the max limit..)).
  if ((($offset + $num_results_per_page) < $search_cache->{num_results}) &&
      (($offset + $num_results_per_page) < Constants::PROFILE_SEARCH_MAX_RESULTS)) {
    $search_results->{next_page_offset} = $offset + $num_results_per_page;
  }
  
  # Generate links for the 'pages' (groups of results containing the current
  # results per page or less) before and after this one.
  $search_results->{results_pages} = [];
  
  # same as current_results_page=CEIL((offset+num_results_per_page)/num_results_per_page) but CEIL does not exist! :(
  my $current_results_page = int(($offset + ($num_results_per_page * 2) - 1) / $num_results_per_page);
  my $remaining_results_pages = int(($search_cache->{num_results} - ($offset + 1)) / $num_results_per_page);
  my $total_results_pages = $current_results_page + $remaining_results_pages;
  my $num_total_pages_to_show = 9; #default max if possible
  my $num_previous_pages_to_show = 4; #default max if possible
  if ($remaining_results_pages < 4) {
    $num_previous_pages_to_show = $num_total_pages_to_show - $remaining_results_pages - 1;
  }
  # only allow as many previous as we actually have at our disposal
  if ($num_previous_pages_to_show >= $current_results_page) {
    $num_previous_pages_to_show = $current_results_page - 1;
  }
  if (($num_previous_pages_to_show + $remaining_results_pages + 1) < $num_total_pages_to_show) {
    $num_total_pages_to_show = $num_previous_pages_to_show + $remaining_results_pages + 1;
  }
  my $results_page_list_start = 1;
  if ($current_results_page > $num_previous_pages_to_show) {
    $results_page_list_start = $current_results_page - $num_previous_pages_to_show;
  }
  for (my $i = 1; $i <= $num_total_pages_to_show; $i++) {
    my $this_results_page_num = ($results_page_list_start + $i) - 1;
    my $this_results_page_offset = $offset + ($num_results_per_page * ($this_results_page_num - $current_results_page));
    if ($this_results_page_offset < 0) {
      $this_results_page_offset = 0;
    }
    push @{$search_results->{results_pages}}, { 'offset' => $this_results_page_offset,
                                                'number' => $this_results_page_num }
  }
  # work out last or first page links if rqd (not in this range)
  if ($results_page_list_start != 1) {
    $search_results->{first_results_page} = { 'offset' => 0,
                                              'number' => 1 };    
  }
  if ($total_results_pages > ($results_page_list_start + $num_total_pages_to_show)) {
    $search_results->{last_results_page} = { 'offset' => $offset + ($num_results_per_page * $remaining_results_pages),
                                             'number' => $total_results_pages };
  }
  $search_results->{total_results_pages} = $total_results_pages;
  $search_results->{current_results_page} = $current_results_page;
  
  $search_results->{offset} = $offset;
  $search_results->{search_id} = $search_id;
  $search_results->{num_results_per_page} = $num_results_per_page;
  
  return $search_results;
}





sub getSearchPrefs() {
  
  my $self = shift;
  
  my $dbh = $self->DBH;
  
  if ($self->{core}->{'user_id'}) {
    
    my $query = <<ENDSQL
SELECT remember_previous_search, search_id, num_results_per_page,
       show_search_history, show_advanced_search
FROM `user~profile~search~prefs`
WHERE user_id = ?
LIMIT 1
ENDSQL
;
    my $sth = $dbh->prepare_cached($query);
    $sth->execute($self->{core}->{'user_id'});
    my $search_prefs = $sth->fetchrow_hashref;
    $sth->finish;
    return $search_prefs;
    
  } elsif ($self->{core}->{'visitor_id'}) {
    
    my $query = <<ENDSQL
SELECT remember_previous_search, search_id, num_results_per_page,
       show_search_history, show_advanced_search
FROM `visitor~profile~search~prefs`
WHERE visitor_id = ?
LIMIT 1
ENDSQL
;
    my $sth = $dbh->prepare_cached($query);
    $sth->execute($self->{core}->{'visitor_id'});
    my $search_prefs = $sth->fetchrow_hashref;
    $sth->finish;
    return $search_prefs;
  }
}



1;
