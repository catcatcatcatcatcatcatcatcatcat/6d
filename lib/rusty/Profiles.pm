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
    $self->{core}->{'profile_name'} = $self->getProfileNameFromProfileId($self->{core}->{'profile_id'});
    $self->{core}->{'profile_info'} = $self->getProfileInfo($self->{core}->{'profile_id'});
  }
  
  return $self;
}




sub _init() {
  
  my $self = shift;
  
  # Make sure all of our profile info lookups cached
  # are lost for between calls if mod_perl is in action..
  &_profile_info_DESTROY;
  
  # Bless into SUPER class so rusty::DESTROY is called on it! :)
  #bless $self, $ISA[0]; # This line is back from when it was the DESTROY method..
  
  # Call parent class' _init method..
  $self->SUPER::_init();
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
    
    ($field =~ s/^(user_id|profile_id)$/up.$1/o)
      || ($field =~ s/^(profile_name)$/u.$1/o)
      || return; # Only allow certain fields!
    
    my $query = <<ENDSQL
SELECT u.profile_name, up.*
FROM `user~profile` up
INNER JOIN `user` u ON u.user_id = up.user_id
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
  
  my ($profile_id, $visitor_id) = @_;
  
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT time FROM `user~profile~visit`
WHERE profile_id = ?
AND visitor_id = ?
LIMIT 1
ENDSQL
;
  
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($profile_id, $visitor_id);
  my $visit_info = $sth->fetchrow_hashref;
  $sth->finish;
  
  if ($visit_info->{time}) {
    
    $query = <<ENDSQL
UPDATE `user~profile~visit`
SET time = NOW()
WHERE profile_id = ?
AND visitor_id = ?
LIMIT 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($profile_id, $visitor_id);
    $sth->finish;
    
  } else {
    
    # If the visitor has never visited this profile before, insert a new
    # entry and update both the viewer user's unique visited count
    # and the visted profile's unique visit count.
    $query = <<ENDSQL
INSERT INTO `user~profile~visit`
(profile_id, visitor_id, time) VALUES
(?, ?, NOW())
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($profile_id, $visitor_id);
    $sth->finish;
    
    $query = <<ENDSQL
UPDATE `user~stats` us
INNER JOIN `user~profile` up ON up.user_id = us.user_id
SET us.unique_visited_count = us.unique_visited_count + 1
WHERE up.profile_id = ?
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($visitor_id);
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
  $sth = $dbh->prepare_cached($query);
  $sth->execute($visitor_id);
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


1;
