package rusty::Admin;

use strict;

use lib "..";



use warnings qw( all );

no  warnings qw( uninitialized );

use CarpeDiem;

use rusty;

use rusty::Profiles;
use rusty::Profiles::Photo;
use rusty::Profiles::Message;
use rusty::Profiles::FriendsAndBlocks;
our @ISA = qw( rusty
               rusty::Profiles
               rusty::Profiles::Photo
               rusty::Profiles::Message
               rusty::Profiles::FriendsAndBlocks );




sub new() {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->rusty::Profiles::new();
  
  if ($self->{core}->{'user_id'}) {
    $self->{core}->{'admin_level'} = $self->getAdminLevelFromUserId($self->{core}->{'user_id'});
    if ($self->{core}->{'admin_privileges'}) {
          die "UserID '$self->{core}->{user_id}' trying to access admin pages but has no admin privileges set";
    }
  } else {
    print $self->redirect( -url => '/login.pl' );
    exit;
  }
  
  return $self;
}




sub init() {
  
  my $self = shift;
    
  # Call parent class' init method..
  $self->SUPER::init();
}



sub getAdminLevelFromUserId($) {
  
  # Given a profile id, returns admin level.  Admin
  # is only for special people who look after the site. :)
  
  my $self = shift;
  
  my $user_id = shift;
  
  my $query = <<ENDSQL
SELECT *
FROM `user~admin_privileges`
WHERE user_id = ?
LIMIT 1
ENDSQL
;
  my $sth = $self->DBH->prepare_cached($query);
  $sth->execute($user_id);
  my $admin_priveleges = $sth->fetchrow_hashref;
  $sth->finish;
  
  return $admin_priveleges;
}




sub getAllPhotosPendingApproval($) {
  
  # Returns all photos that need checking by an admin..
  
  my $self = shift;
  
  return unless $self->{core}->{'admin_level'}->{photo_approval};
  
  return $self->SUPER::getAllPhotosPendingApproval();
}




1;
