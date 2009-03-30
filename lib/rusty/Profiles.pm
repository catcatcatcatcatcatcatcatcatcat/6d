package rusty::Profiles;

use strict;

use lib "..";



use warnings qw( all );

no  warnings qw( uninitialized );

use CarpeDiem;

use rusty;

# These are not our children, these are our little helpers!
# (splitting up old functions that used to be in here..)
use rusty::Profiles::Photo;
use rusty::Profiles::Message;
use rusty::Profiles::FriendsAndBlocks;
our @ISA = qw( rusty
               rusty::Profiles::Photo
               rusty::Profiles::Message
               rusty::Profiles::FriendsAndBlocks );




sub new() {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  #my $self = SUPER->new;
  my $self = $class->rusty::new();
  #bless $self, $class;
  
  if ($self->{core}->{'user_id'}) {
    $self->{core}->{'profile_id'}   = $self->getProfileIdFromUserId($self->{core}->{'user_id'});
    $self->{core}->{'profile_name'} = $self->getProfileNameFromUserId($self->{core}->{'user_id'});
    $self->{core}->{'profile_info'} = $self->getProfileInfo($self->{core}->{'profile_id'});
  }
  
  return $self;
}




#sub DESTROY() {
#  my $self = shift;
#  $self->init();
#  # Bless into SUPER class so SUPER::DESTROY is called on it! :)
#  bless $self, $ISA[0];
#}

# Make sure we start with fresh data since DESTROY 
# doesn't seem to get called until it's too late (it
# relies on garbage collection's timing.)
sub init() {
  
  my $self = shift;
  
  # Make sure all of our profile info lookups cached
  # are lost for between calls if mod_perl is in action..
  &_profile_info_DESTROY;
  
  # Call parent class' init method..
  $self->SUPER::init();
}



# converts centimetres to feet and inches, returns result in assoc. array w/keys "feet", "inches"
sub cmToFeetInches($) {
  my ($this, $cm) = @_;
  my $inches = $this->cmToInches($cm);
  return { feet => int($inches / 12), inches => $inches % 12 };
}


# converts feet and inches to centimetres
sub feetAndInchesToCm($$) {
  return (($_[1] * 12) + $_[2]) * 2.54;
}


sub inchesToCm($) {
  return $_[1] * 2.54;
}


sub cmToInches($) {
  return $_[1] / 2.54;
}


sub lbsToGrams($) {
  return int(2205 * $_[1]);
}


sub kgToGrams($) {
  return int(1000 * $_[1]);
}


sub stToGrams($) {
  return int(30870 * $_[1]);
}


sub gramsToLbs($) {
  return int($_[1] / 2205);
}


sub gramsToKg($) {
  return int($_[1] / 1000);
}


sub gramsToSt($) {
  return int($_[1] / 30870);
}

{
  # This set of subs allows many lookups between database fields
  # but only requires one database call for as many as you like!
  # On the first call, lookup tables are populated with all info
  # and can be retrieved on future lookups. How efficient!
  # They will be destroyed after each request to stop mod_perl
  # keeping their values (leaking memory & using old stale data).
  # All encapsulated too so you "can't touch this". Hee hee.
  
  my (%profile_info_on_user_id,
      %profile_info_on_profile_id,
      %profile_info_on_profile_name);
  
  sub _profile_info_DESTROY() {
    undef %profile_info_on_user_id;
    undef %profile_info_on_profile_id;
    undef %profile_info_on_profile_name;
  }
  
  my ($self, $user_id);
  
  sub getProfileIdFromUserId($) {
    
    $self = shift;
    
    my $user_id = shift;
    
    _lookup_profile_info( user_id => $user_id ) unless exists($profile_info_on_user_id{$user_id});
    
    return $profile_info_on_user_id{$user_id}->{profile_id};
  }
  
  sub getUserIdFromProfileId($) {
    
    $self = shift;
    
    my $profile_id = shift;
    
    _lookup_profile_info( profile_id => $profile_id ) unless exists($profile_info_on_profile_id{$profile_id});
    
    return $profile_info_on_profile_id{$profile_id}->{user_id};
  }
  
  sub getProfileNameFromProfileId($) {
    
    $self = shift;
    
    my $profile_id = shift;
    
    _lookup_profile_info( profile_id => $profile_id ) unless exists($profile_info_on_profile_id{$profile_id});
    
    return $profile_info_on_profile_id{$profile_id}->{profile_name};
  }
  
  sub getProfileIdFromProfileName($) {
    
    $self = shift;
    
    my $profile_name = shift;
    
    _lookup_profile_info( profile_name => $profile_name ) unless exists($profile_info_on_profile_name{$profile_name});
    
    return $profile_info_on_profile_name{$profile_name}->{profile_id};
  }
  
  sub getProfileNameFromUserId($) {
    
    $self = shift;
    
    my $user_id = shift;
    
    _lookup_profile_info( user_id => $user_id ) unless exists($profile_info_on_user_id{$user_id});
    
    return $profile_info_on_user_id{$user_id}->{profile_name};
  }
  
  
  sub getProfileInfo($) {
    
    # Given a profile id, returns all profile information
    # including converted weight and 'photos' with the
    # number of photos existing for this profile.
    # Returns 0 if no profile matches this profile id.
    
    my $self = shift;
    
    my $profile_id = shift;
    
    _lookup_profile_info( profile_id => $profile_id ) unless exists($profile_info_on_profile_id{$profile_id});
    
    if ($profile_info_on_profile_id{$profile_id}) {
      
      if ($profile_info_on_profile_id{$profile_id}->{main_photo_id}) {
        
        # This will update all three lookups as they're all referencing the same thing.
        $profile_info_on_profile_id{$profile_id}->{main_photo} = $self->getMainPhoto($profile_id)
          unless exists($profile_info_on_profile_id{$profile_id}->{main_photo});
      }
      
      return $profile_info_on_profile_id{$profile_id};
      
    } else {
      return 0;
    }
  }
  
  sub isDeleted($) {
    
    $self = shift;
    
    my $profile_id = shift;
    
    _lookup_profile_info( profile_id => $profile_id ) unless exists($profile_info_on_profile_id{$profile_id});
    
    return ($profile_info_on_profile_id{$profile_id}->{deleted_date} ? 1 : 0);
  }
  
  
  
  sub _lookup_profile_info() {
    
    my ($field, $value) = @_;
    
    # Only allow certain fields!
    return unless $field =~ /^(user_id|profile_id|profile_name)$/o;
    
    my $query = <<ENDSQL
SELECT SQL_CACHE *
FROM `user~profile`
WHERE $field = ?
LIMIT 1
ENDSQL
;
    my $sth = $self->DBH->prepare_cached($query);
    $sth->execute($value);
    my $profile_info = $sth->fetchrow_hashref;
    $sth->finish;
    
    # If profile exists, convert all weights (all stored as grams)
    # into their correct unit's figure.
    if ($profile_info->{weight}) {
      if ($profile_info->{weight_type} eq "lbs") {
        $profile_info->{weight} =
          $self->gramsToLbs($profile_info->{weight});
      } elsif ($profile_info->{weight_type} eq "st") {
        $profile_info->{weight} =
          $self->gramsToSt($profile_info->{weight});
      } elsif ($profile_info->{weight_type} eq "kg") {
        $profile_info->{weight} =
          $self->gramsToKg($profile_info->{weight});
      }
    }
    
    # They're all referencing the same info but in different ways.. :)
    $profile_info_on_user_id{$profile_info->{user_id}} = $profile_info;
    $profile_info_on_profile_id{$profile_info->{profile_id}} = $profile_info;
    $profile_info_on_profile_name{$profile_info->{profile_name}} = $profile_info;
  }
}



sub profileLogVisit($$) {
  
  my $self = shift;
  
  my ($profile_id, $visitor_profile_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT time FROM `user~profile~visit`
WHERE profile_id = ?
AND visitor_profile_id = ?
LIMIT 1
ENDSQL
;
  
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $visitor_profile_id);
  my $visit_info = $sth->fetchrow_hashref;
  $sth->finish;
  
  if ($visit_info->{time}) {
    
    $query = <<ENDSQL
UPDATE `user~profile~visit`
SET time = NOW()
WHERE profile_id = ?
AND visitor_profile_id = ?
LIMIT 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($profile_id, $visitor_profile_id);
    $sth->finish;
    
  } else {
    
    # If the visitor has never visited this profile before, insert a new
    # entry and update both the viewer user's unique visited count
    # and the visted profile's unique visit count.
    $query = <<ENDSQL
INSERT DELAYED INTO `user~profile~visit`
(profile_id, visitor_profile_id, time) VALUES
(?, ?, NOW())
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($profile_id, $visitor_profile_id);
    $sth->finish;
    
    $query = <<ENDSQL
UPDATE `user~stats` us
INNER JOIN `user~profile` up ON up.user_id = us.user_id
SET us.unique_visited_count = us.unique_visited_count + 1
WHERE up.profile_id = ?
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($visitor_profile_id);
    $sth->finish;
    
    $query = <<ENDSQL
UPDATE `user~profile`
SET unique_user_visit_count = unique_user_visit_count + 1
WHERE profile_id = ?
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($profile_id);
    $sth->finish;
  }
  
  # No matter what has gone on before, update the total visited and
  # visit counts for the visiting user..
  $query = <<ENDSQL
UPDATE `user~stats` us
INNER JOIN `user~profile` up ON up.user_id = us.user_id
SET us.total_visited_count = us.total_visited_count + 1
WHERE up.profile_id = ?
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute($visitor_profile_id);
  $sth->finish;
}


sub incrementExternalVisitCount($) {
  
  my $self = shift;
  
  my $visited_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
UPDATE `user~profile`
SET external_visit_count = external_visit_count + 1
WHERE profile_id = ?
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($visited_id);
  $sth->finish;
}


sub incrementVisitCount($) {
  
  my $self = shift;
  
  my $visited_id = shift;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
UPDATE `user~profile`
SET total_visit_count = total_visit_count + 1
WHERE profile_id = ?
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($visited_id);
  $sth->finish;
}


sub getRecentProfileVisitors($$) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $limit = shift;
  $limit ||= 10;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT upv.visitor_profile_id, up.profile_name, up.main_photo_id,
  CONCAT_WS(' ',
    IF(DATE(upv.time) = CURRENT_DATE(), '',
      IF(DATE(upv.time) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY), 'Yesterday, ',
        IF(DATE(upv.time) > DATE_SUB(CURRENT_DATE(), INTERVAL 1 WEEK), DATE_FORMAT(upv.time, '%W, %e/%c, '),
          DATE_FORMAT(upv.time, '%e/%c/%y')
        )
      )
    ), DATE_FORMAT(upv.time, '%H:%i')
  ) AS time
FROM `user~profile~visit` upv
INNER JOIN `user~profile` up ON up.profile_id = upv.visitor_profile_id
WHERE upv.profile_id = ?
ORDER BY upv.time DESC
LIMIT ?
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $limit);
  my @visits = ();
  while (my $visit_info = $sth->fetchrow_hashref) {
    push @visits, $visit_info;
  }
  $sth->finish;
  
  return @visits ? \@visits : undef;
}


sub getRecentProfileVisitorsDetailed($$) {
  
  my $self = shift;
  
  my $profile_id = shift;
  
  my $limit = shift;
  $limit ||= 10;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT up.profile_name,
ui.gender, ui.sexuality, ui.subentity_code, ui.country_code, ui.age,
  CONCAT_WS(' ',
    IF(DATE(upv.time) = CURRENT_DATE(), '',
      IF(DATE(upv.time) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY), 'Yesterday, ',
        IF(DATE(upv.time) > DATE_SUB(CURRENT_DATE(), INTERVAL 1 WEEK), DATE_FORMAT(upv.time, '%W, %e/%c, '),
          DATE_FORMAT(upv.time, '%e/%c/%y')
        )
      )
    ), DATE_FORMAT(upv.time, '%H:%i')
  ) AS time,
  up.main_photo_id,
  upp.photo_id, upp.thumbnail_filename, upp.checked_date, upp.adult
FROM `user~profile~visit` upv
INNER JOIN `user~profile` up ON up.profile_id = upv.visitor_profile_id
LEFT  JOIN `user~profile~photo` upp ON upp.photo_id = up.main_photo_id
INNER JOIN `user~info` ui ON ui.user_id = up.user_id
WHERE upv.profile_id = ?
ORDER BY upv.time DESC
LIMIT ?
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $limit);
  my @visits = ();
  my $visitor_stats = {};
  while (my $visit_info = $sth->fetchrow_hashref) {
    
    $visitor_stats->{age_min} = $visit_info->{age}
      if !$visitor_stats->{age_min} ||
         ($visit_info->{age} < $visitor_stats->{age_min});
    $visitor_stats->{age_max} = $visit_info->{age}
      if !$visitor_stats->{age_max} ||
         ($visit_info->{age} > $visitor_stats->{age_max});
    $visitor_stats->{genders}->{$visit_info->{gender}}++;
    $visitor_stats->{country_codes}->{$visit_info->{country_code}}++;
    #$visitor_stats->{subentity_codes}->{$visit_info->{subentity_code}}++;
    #$visitor_stats->{sexualities}->{$visit_info->{sexuality}}++;
    $visitor_stats->{total}++;
    
    if ($self->{params}->{age_min} && $self->{params}->{age_min} ne 'any'
        && $visit_info->{age} < $self->{params}->{age_min}) {
    } elsif ($self->{params}->{age_max} && $self->{params}->{age_max} ne 'any'
             && $visit_info->{age} > $self->{params}->{age_max}) {
    } elsif ($self->{params}->{gender} && $self->{params}->{gender} ne 'any'
             && $visit_info->{gender} ne $self->{params}->{gender}) {
    } elsif ($self->{params}->{country_code} && $self->{params}->{country_code} ne 'any'
             && $visit_info->{country_code} ne $self->{params}->{country_code}) {
    } else {
      push @visits, $visit_info;
    }
  }
  $sth->finish;
  
  if (@visits && ($visitor_stats->{total} > $limit)) {
    pop @visits;
  }
  
  return @visits ? { visits => \@visits, visitor_stats => $visitor_stats }
                 : { visitor_stats => $visitor_stats };
}


1;
