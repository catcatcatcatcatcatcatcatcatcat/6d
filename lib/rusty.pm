package rusty;

use strict;

use lib '../lib';


use warnings qw(all);

no  warnings qw(uninitialized);

#our specific constants;

use Constants;


use vars qw( *LOG *BENCHMARK $site_files_root $DATABASE_VERSION);

use CarpeDiem; # qw(carpout); # fatalsToBrowser); # set_progname);# set_message );

#use Math::TrulyRandom qw( truly_random_value );
#use Math::Random qw( rand );
# This successfuly gets around the problem of /dev/random providing
# no entropy on our current VM setup!  Wahoo!
if ($ENV{NO_ENTROPY}) {
  eval {
    require Math::Random::MT::Auto;
    import Math::Random::MT::Auto qw( rand srand ), '/dev/urandom';
  }
}

require File::Spec; #qw( rel2abs );

require Cwd; #qw( fast_abs_path );



BEGIN {
  
  use IO::Handle;
  
  ####################################
  # Custom error logging:
  ####################################
  # Change directory to server DocumentRoot so all config files
  # and error logs we write to are relative to the site path..
  # First make sure we blindly untaint the nasty taintedness :)
  
  #if ($ENV{DOCUMENT_ROOT} && $ENV{DOCUMENT_ROOT} =~ m!(.+)/?!o) {
  #  $document_root = $1;
  #  #chdir($document_root); # Let's not chdir as we're running 
  #                          # testing AND production now on the same server..
  #}
  
  if (exists($ENV{'GATEWAY_INTERFACE'})) {
    # Get the path (without '../') to two dirs below doc root
    # (where we keep our 'log' and user 'photos' directories).
    $site_files_root = Cwd::fast_abs_path(File::Spec->rel2abs("../../", $ENV{DOCUMENT_ROOT}));
    
    # Untaint (blindly) to keep -T happy and remove trailing '/' while we're here..
    $site_files_root = $1 if $site_files_root =~ m!^(.+)/?$!;
    
    my $log_dir = "$site_files_root/logs";
    
    open LOG, ">>$log_dir/error_log"
      || print "Content-type: text/html\n\n"
         && die "Unable to open script error log: $!";
    
    warn "logging all errors to $log_dir/error_log";
    
    CarpeDiem::carpout(\*LOG);
    
    #open BENCHMARK, ">>$log_dir/benchmark_log"
    #  || print "Content-type: text/html\n\n"
    #     && die "Unable to open script benchmark log: $!";
  }
  
  #
  ####################################
  
  #if ($ENV{MOD_PERL}) {
  #  warn "running mod perl! :)"
  #} else {
  #  warn "noooo! no mod perl. :("
  #}
  
  # Save core exit as rusty realexit
  # Override the global exit with rusty::exit :)
  #*rusty::realexit = \&CORE::GLOBAL::exit;
  #*CORE::GLOBAL::exit = \&rusty::exit;
}

# Override the global exit with rusty::exit (again) :)
#$rusty::SIG{QUIT}=\&rusty::exit;
#$SIG{QUIT}=\&rusty::exit;
# Trying another way with sigtrap..
#use sigtrap 'handler', \&rusty::exit, 'normal-signals';

# was trying to do this with DESTROY, but
# certain objects seemed to have been killed
# by the time it got to destroying - sadly!
# (Destroy only gets called when the object's
#  reference count gets to 0 - duuuh).
# (because now we have to explicitly call
#  '$rusty->exit;' to make things happen..)
# Also, overriding EXIT to call exit via this
# doesn't manage to retain the objects either :(
# CRAP!  Have to stick with $rusty->exit; - so ugly.
#sub realexit(@) {
#  CORE::exit(@_);
#}
#sub exit($@) {
sub exit(@) {
  my $self = shift;
  $self->write_benchmark;
  # Will this call THIS exit again or CORE::exit?
  # If we say CORE::exit, will mod_perl know to change this
  # into Apache::exit or leave it as is?  Oooh this seems to work..
  exit(@_);
  #realexit(@_); 
}




$rusty::MAX_FILE_SIZE = 1.5 * (1024 * 1024); # 1.5MB in bytes
#$rusty::PHOTO_UPLOAD_DIRECTORY = "$site_files_root/photos/";
$rusty::PHOTO_UPLOAD_DIRECTORY = Cwd::fast_abs_path(File::Spec->rel2abs("../../photos", $ENV{DOCUMENT_ROOT}));
$rusty::PHOTO_UPLOAD_DIRECTORY = $1 if $rusty::PHOTO_UPLOAD_DIRECTORY =~ m!^(.+)/?$!;
sub max_file_size() { return $rusty::MAX_FILE_SIZE; }
sub photo_upload_directory() { return $rusty::PHOTO_UPLOAD_DIRECTORY; }




sub new() {
  
  my $proto = shift;
  
  my $class = ref($proto) || $proto;
  
  my $self = {};
  
  bless $self, $class;
  
  # This called method used to be the originating class' DESTROY.
  # Perl's garbage collection waits too long to call DESTROY normally
  # (leading to new scripts being called before the data has been
  #  destroyed and therefore ending up using data from previous call).
  # We added it to our exit() which worked but if any script died abnormally,
  # it will not be called and the data will be left stale until DESTROY was
  # called by the garbage collection (a second or two later).. SO, in a very
  # bizarre twist, to ensure data we begin with is fresh, the DESTROY
  # is renamed to init() and will be called up here in new() instead.
  $self->init();
  
  # Set up the container for the core data for this object -
  # this tie (code below this sub) ensures values are set once
  # and do not get clobbered or deleted once set.
  my %_core = ();
  tie %_core, 'rusty::TiedHash::core';
  $self->{core} = \%_core;
  
  # Find out which vhost we're in - testing or prod!
  #$self->{core}->{env} = $ENV{ENV};
  # This will get SUBDOMAIN from ..ANYTHING.ANYTHING.SUBDOMAIN.DOMAIN.TLD..
  my $subdomain = (split(/\./, $ENV{SERVER_NAME}))[-3];
  if ($subdomain eq 'local') {
    $self->{core}->{env} = 'local';
  } elsif ($subdomain eq 'testing') {
    $self->{core}->{env} = 'testing';
  } elsif ($subdomain eq 'www') {
    $self->{core}->{env} = 'production';
  }
  
  # Let's do a bit of benchmarking (if we're in testing env)..
  if ($self->{core}->{env} =~ /^(?:testing|local)$/) {
    require Benchmark::Timer;
    $self->{benchmark} = Benchmark::Timer->new;
    $self->benchmark->start('total');
    $self->benchmark->start('birth');
  }
  
  $self->{params} = $self->get_utf8_params();
  
  # Don't need to connect to DB anymore - it will happen on the first call to DBH()!
  # # Create new DB handle
  # #$self->{DBH} = db_connect();
  # #$_DBH = $self->db_connect();
  
  # Create new Template Toolkit object (DOING THIS NOW AS IT IS PROCESSED
  # TO STOP WASTING TIME FOR OCCASIONS WHERE IT IS NOT REQUIRED)
  #$self->{template} = $self->init_template();
  
  # Set session_cookie info from cookie (if it exists)
  # Otherwise, grab the visitor cookie (if it exists)
  $self->_grab_session_cookie() || $self->_grab_visitor_cookie();
  
  # Let's check if someone is logged in and store it..
  # Otherwise, look for the stored profile_name cookie, if they have it set!
  if ((length($self->session_cookie) == 24) && # Ignore 'killmyass' & 'loggedout'.
      ($self->{core}->{'user_id'} = $self->_get_user_id())) {
    
    if ($self->{params}->{'login'}) {
      $self->{core}->{'open_assistant'} = 1;
    }
    $self->{core}->{'email'} = $self->get_email_address($self->{core}->{'user_id'});
    $self->{core}->{'email_validated'} = $self->is_email_validated($self->{core}->{'user_id'});
    
    # We also want to know what their visitor_id is so if we create search sessions,
    # we can link the session to both the logged out and logged in user - this allows
    # the user to continue viewing the search results (that doesn't nec. require login)
    # even if their session expires..
    $self->{core}->{'visitor_id'} = $self->_get_visitor_id_while_logged_in();
    
  } elsif ($self->session_cookie) {
    
    # If the user's cookie is still there, then they didn't log
    # out properly and their session timed out, kill the cookie.
    push @{$self->{cookies}}, $self->CGI->cookie( -name    => "session",
                                                  -value   => '',
                                                  -expires => '-1d' );
    
    if ($self->session_cookie eq 'loggedout') {
      $self->{core}->{'logged_out'} = 1;
    } elsif ($self->session_cookie eq 'killmyass') {
      $self->{core}->{'logged_out'} = 1;
      $self->{core}->{'close_assistant'} = 1;
    } else {
      $self->{core}->{'timed_out'} = 1;
    }
    
    # Now that we're finished with the session (deleting it on this request), let's
    # remove it from the internal records so we don't get confused. :)
    $self->_clear_session_cookie_var;
    
    if ($self->{core}->{'remembered_profile_name'} = $self->_grab_profile_name_cookie()) {
      $self->{core}->{'remember_me'} = 1;
    }
    
    ($self->{core}->{'visitor_id'},
     my $are_they_return_visitors) = $self->_get_visitor_id();
    
  } else {
    
    if ($self->{core}->{'remembered_profile_name'} = $self->_grab_profile_name_cookie()) {
      $self->{core}->{'remember_me'} = 1;
    }
    
    # This param is only set on login if test cookie couldn't be set/read and
    # user is sent back to the page they logged in from with this param set.
    $self->{core}->{'nocookies'} = 1 if $self->{params}->{'nocookies'} == 1;
    
    # This will return a visitor id if one has a session.  If no session,
    # it will create the session and return the visitor id.  If this is
    # a new visitor, it will first create the cookie with a visitor ref
    # and the next time it is called, it will create the visitor and
    # initialise stats in the db, returning the visitor id as above..
    # NB. If cookies are disabled, it will never return a visitor id!
    ($self->{core}->{'visitor_id'},
     my $are_they_return_visitors) = $self->_get_visitor_id();
  }
  
  my $self_url;
  #$self_url = $ENV{REQUEST_URI};
  # This doesn't catch posts or
  $self_url = $self->CGI->self_url( -oldstyle_urls );
  # Any POST values are added to the query string but with a ';'
  # new style delimiter rather than the old style '&',
  # so we switch it back here to the correct syntax..
  $self_url =~ s/;/&/g;
  # We are now using CGI with '-oldstyle_urls' so the '&'
  # is used by default..  This is good because nobody uses the
  # new style ';' anyway.  Even though it is probably better..
  # F*cking oldstyle_urls flag only makes a difference on the
  # first run in mod_perl - not sure how to get around this so
  # i'm leaving the regex in for now..
  # This also doesn't work that well if getting a url that has
  # been transformed by a server rewrite.. tends to get the real
  # url requested before transformation but append the query string
  # received after the transformation.. weird!  it almost messes up
  # the profiles thing but i've fixed that and i'm going to leave it
  # all as is! :)
  #warn "self: " . $self_url;
  # Make url relative when working with just one TLD - if we develop more
  # sharing same login, maybe change this to use full TLD in self_url again
  $self_url =~ s!^(?:https?|ftp)\://\Q$ENV{SERVER_NAME}\E(?:\:$ENV{SERVER_PORT})?!!o;
  $self->{core}->{'self_url'} = $self_url;
  require URI::Escape;
  $self->{core}->{'self_url_escaped'} = URI::Escape::uri_escape($self_url);
  
  $self->{core}->{server_name} = $ENV{SERVER_NAME};
  $self->{core}->{mod_perl_api_version} = $ENV{MOD_PERL_API_VERSION};
  $self->{core}->{perl_version} = $1 if $] =~ /(^\d+\.\d)/o; # 1dp.
  $self->{core}->{server_software} = "Apache 2"; #$ENV{SERVER_SOFTWARE};
  $self->{core}->{mysql_version} = $DATABASE_VERSION;
  
  # If user has clicked on first tier menu item (link provided for non
  # javascript-enabled users), then set this in the core to open the sub-menu.
  $self->{core}->{'emi'} = $self->{params}->{'emi'}; # emi = expand_menu_item
  $self->{core}->{'esmi'} = $self->{params}->{'esmi'}; # esmi = expand_sub_menu_item
  
  # Grab the user's theme preference from their cookie..
  $self->{core}->{'theme'} = $self->_grab_theme_cookie() || 0;
  
  # Setup the themes that we can offer (should this be done here??)
  $self->{core}->{'themes'} = [ 'white-orange-darkgrey',
                                'white-red-white',
                                'darkgrey-orange-darkgrey',
                                'orange-pink-orange',
                                'darkblue-yellow-darkblue',
                                'darkgrey-beige-darkgrey',
                                'grey-green-grey',
                                'lightgrey-green-lightgrey',
                                'beige-orange-darkgrey',
                                #'bustyparty',
                                #'empty', #empty theme just to allow simple theme framework to show through
                                ];
  
  if ($self->{core}->{env} =~ /^(?:testing|local)$/) {
    $self->benchmark->stop('birth');
  }
  
  # Use this for testing text-only mode (dev)
  #$self->{core}->{no_nav_links} = 1; 
  
  return $self;
  
}


##############################
package rusty::TiedHash::core;
require Tie::Hash;
use Carp;
our @ISA = qw( Tie::StdHash );
# Core values can be initialised but once set, they cannot be changed or deleted.
# This allows us to set them in object creation but not have them clobbered :)
# Anywhere can set new core values, but this is okay as they almost certainly
# won't be used in the ttmls or elsewhere unless they've been set in new().. :)
sub STORE() {
  if (exists($_[0]{$_[1]})) {
    carp "someone is trying to set a defined core value "
       . "'$_[1]' to '$_[2]' on '$_[0]'";
  } else {
    #goto &Tie::StdHash::STORE;
    $_[0]{$_[1]} = $_[2];
  }
}
sub DELETE() { carp "attempt to delete core value '$_[1]' not allowed"; }
package rusty;
##############################




sub benchmark() { return $_[0]->{benchmark}; }



{
  # Closure with the cookie session string variable and it's get/set method.
  # Set method is only used internally on object construction..
  my $_session_cookie;
  
  sub session_cookie() {
    return $_session_cookie;
  }
  sub _clear_session_cookie_var() {
    undef($_session_cookie);
  }
  sub _grab_session_cookie() {
    my $self = shift;
    $_session_cookie = $self->CGI->cookie( -name => "session" );
    return $_session_cookie; # if defined wantarray;
  }
  
  # We're only ever going to want this cookie at startup so no get is required.
  # It is not referred to in the code, just in the ttml for the login box! :)
  sub _grab_profile_name_cookie() {
    my $self = shift;
    return $self->CGI->cookie( -name => "forgetmenot" );
  }
  
  # This is for people who aren't yet registered but we want to track and love.
  # And possibly pester - if they give us their email address! ;)
  my $_visitor_cookie;
  sub visitor_cookie() {
    return $_visitor_cookie;
  }
  sub _clear_visitor_cookie_var() {
    undef($_visitor_cookie);
  }
  sub _grab_visitor_cookie() {
    my $self = shift;
    $_visitor_cookie = $self->CGI->cookie( -name => "visitor" );
    return $_visitor_cookie if defined wantarray;
  }
  
  # This is the personalised theme cookie..
  sub _grab_theme_cookie() {
    my $self = shift;
    return $self->CGI->cookie( -name => "theme" );
  }
}




{
  my $_DBH;
  
  sub DBH() {
    # This little check saves a LOT of time! ~12ms -> ~6ms
    # (about 6ms is used to perform the DBI->connect() even though
    # it is meant to be clever when used with Apache::DBI persistent
    # connections and re-use the existing connection) - it is the PING
    # that takes up the time.  Without it, if the connection to db dies,
    # it will have to perform a duff query before it realises that the
    # connection is dead and will then reconnect on next request.
    # So we would be saving 6ms from 99.9% of requests BUT the other 0.1%,
    # when the db has just been restarted will get a dead page & have to hit refresh!
    # Without Apache::DBI, it takes 30-45ms per request (35ms for connecting)
    # so the ping is saving a hell of a lot of time really :) Let's leave
    # the 6ms loss there.. it's not thaaaat long and it is only a ping..
    #$_DBH = db_connect() unless defined $_DBH; # Save the 6ms ping
    #$_DBH = db_connect(); # Do the ping and detect dead db immediately.
    # Now we are undefining the DB handle on every DESTROY so it will only
    # do the following on every new request - much better than all the time!
    $_DBH = db_connect() unless defined $_DBH;
    
    return $_DBH;
  }
  
  sub _DBH_destroy() { undef $_DBH; }
  
  {
    # Grab all config for the site database login
    require conf::db_conf;
    
    # Set the data source name from config file
    # format: dbi:db type:db name:host:port
    my $_DSN = "DBI:" . $conf::db_conf::DBDRIVER
             . ":database=" . $conf::db_conf::DATABASE
             . ";host=" . $conf::db_conf::DBHOST
             . ";port=" . $conf::db_conf::DBPORT;
    
    sub db_connect() {
      #use Apache::DBI ();
      require DBI;
      #warn "getting database connection";
      
      # Don't check the database every bloody connection,
      # try once every 60 seconds..
      #Apache::DBI->setPingTimeOut($_DSN, -1);
      
      
      # Connect and get a database handle with UTF-8 enabled for input/output
      if (my $_dbh = DBI->connect( $_DSN,
                           $conf::db_conf::USERNAME,
                           $conf::db_conf::PASSWORD,
                           # These are the defaults: warn errors but don't die!
                           { 'RaiseError' => 0, 'PrintError' => 1,
                             'mysql_enable_utf8' => 1 } )) {
        
        # This is a hack to get UTF-8 to work for us - it was working with
        # the mysql_enable_utf8 flag above but then suddenly stopped working
        # This seems to get around that!  Shame we have to though.. Not anymore!
        #$_dbh->do("SET NAMES utf8");
        
        # Set up some info about our database (SQL_DBMS_VER)
        $DATABASE_VERSION = $1 if $_dbh->get_info(18) =~ /([\d\.]+)/; 
        
        return $_dbh;
      } else {
        print CGI::redirect( -url => '/errors/database-dead.html' );
        die "Can't connect to database: ".$DBI::errstr;
      }
    }
  }
}



{
  my $_CGI;
  
  sub CGI() {
    $_CGI = new_cgi() unless defined $_CGI;
    return $_CGI;
  }
  
  sub _CGI_destroy() { undef $_CGI; }
  
  sub new_cgi {
    
    # Create new CGI object
    require CGI;
    
    # Have the script running under mod_perl and mod_cgi
    my $cgi = $ENV{MOD_PERL} ? CGI::new(shift @_) : CGI::new();
    
    # Set the default charset!
    $cgi->charset('UTF-8');
    
    return $cgi;
    
  }
}





#sub DESTROY() {
#  my $self = shift;
#  $self->init();
#}

# Make sure we start with fresh data since DESTROY 
# doesn't seem to get called until it's too late (it
# relies on garbage collection's timing.)
sub init {
  
  my $self = shift;
  
  undef($!); # Reset error num
  &_user_info_DESTROY;
  &_DBH_destroy;
  &_CGI_destroy;
}


sub get_utf8_params {
  
  my $cgi = &CGI;
  
  my %params;
  
  # Fetch the entire parameter list as a hash:
  #%params = $cgi->Vars();
  # When using this, the thing you must watch out for are multivalued CGI parameters.
  # Because a hash cannot distinguish between scalar and list context,
  # multivalued parameters will be returned as a packed string,
  # separated by the "\0" (null) character.
  # You must split this packed string in order to get at the individual values.
  # i.e. @foo = split("\0",$params->{'foo'});
  #
  # Get all params as array ref of the paranms:
  #%params = map { $_ => [$cgi->param($_)] } $_CGI->param;
  # Get all params as the first element we find in any multivalued params.. :)
  %params = map { $_ => scalar($cgi->param($_)) } $cgi->param;
  
  # SUGGESTED FROM BOOK: Perform check on a field we set to see how a browser is coping
  # with our utf-8 encoding.. (just need to add the field and decide what to do if not!)
  #if (defined($params{utf8_check})
  #    && $params{utf8_check} =~
  #        m/^(
  #            [\x09\x0A\x0D\x20-\x7E]            # ASCII
  #          | [\xC2-\xDF][\x80-\xBF]             # non-overlong 2-byte
  #          |  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
  #          | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
  #          |  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
  #          |  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
  #          | [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
  #          |  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
  #        )*$/x) {
  #  warn "browser not sending back correctly utf-8 encoded form data test field we set";
  #}
  
  # Now we also want to make sure that our utf-8 encoded form data is stored as perl's internal utf8.
  my $secret_number = 1020348;
  foreach (%params) {
    utf8::decode($params{$_}) unless utf8::is_utf8($params{$_});
    
    # We need to decode any IDs (eg. user_id, profile_id, photo_id, link_id etc.)
    if ($_ =~ /_id$/o && # If this is an 'bla_id' param name
        $params{$_} =~ /^!1\d+?5\d$/o) { # and the param has the encoded signature (could be faked)
      (my $decoded = $params{$_}) =~ s/^!1(\d+?)5(\d)$/$1$2/o; # remove signature..
      $decoded = sprintf('%lx', $decoded); # Decode encoded id string: Convert to hex,
      $decoded =~ s/^9//o; # Remove leading 9 added to help encode zero leading nums,
      $decoded = # Reverse, convert back to number and subtract secret number..
        hex(scalar(reverse($decoded)))-$secret_number;
      if ($decoded =~ s/^123//o) { # Remove the internal (very hard to detect) signature
        $params{$_} = $decoded; # If it really was one of our encoded strings, allow it to be decoded
      } else {
        warn "param: $_ was not properly encoded - decoded = $decoded!\n";
        warn " and..: " . hex(scalar(reverse(sprintf('%lx', $decoded))))-$secret_number . "\n";
      }
    }
  }
  
  return \%params;
}

# Closure for params data ('params') and ttml data ('data')
# to ensure encapsulation (people can't edit the info unless
# they use our methods :) - this slows things down but does
# make sure that data gets treated with respect and things
# can't go (as easily) wrong (we hope).
# I know this is a class attribute (which is shared by all objects
# of this class) but since we only have one object instance created
# per call to this code from apache (only one request object per request!)
# and each apache child has it's own compiled version of this code (I THINK!)
# and each child can only handle one request at a time) so as long as we
# delete the info in these class attributes on destroy (optional)
# and reset/repopulate it on each object initialisation, they will
# act as object attributes for the only object instance using this class.
# We could do this so that we store info for each object but it's pointless
# as there will only ever be one..  The other option is to slap these
# attributes onto the object hash and tie them to behaviours we need..
# Hmmm.. It does make it easier, doesn't it? :) Given that {data} really
# doesn't need any special treatment - it can be left as a normal hash.
#{
#  my %_params = ();
#  sub param() {
#  }
#  sub get_all_params_without_validation() {
#    # unsafe but needs to be allowed!
#  }
#  sub get_validated_params() {
#    # take criteria & return params & errors.. somehow!
#    # maybe make new object so we call new on it, call
#    # get_validate_params on it and then call
#    # get_errors on it.. all comes from same object then!
#    # this is another way of doing it if we store the error etc.
#    # in here.. yeah - this is simpler.
#  }
#  sub get_param_validation_errors() {
#    # you guessed it! must be a nicer way than this..
#    # must be to OO-ify the whole thing. so okay, now we're
#    # doing the opposite of what we said above! maybe this is
#    # all too complicated for not doing it the OO way.. but we are
#    # only going to have one instance of this and it's linked
#    # directly to the CGI (rusty) object, so it really shouldn't
#    # be a child of it.. let's leave it here!
#  }
#  
#  my %_data = ();
#  sub data() {
#  }
#  my %_core = ();
#  sub core() {
#    # Read only accessor for core values
#    my ($self,$newval) = @_;
#  }
#  # get params in here and return them:
#  # via the validate params method.. (anything you
#  # want returning, you must specify what and help
#  # us untaint it)
#}



{
  my $_template;
  
  sub process_template() {
    
    my $self = shift;
    my $opts = { @_ };
    my $data = $self->{data} || {};
    my $filename = $self->{ttml};
    
    my %header_opts;
    #if ($opts->{nocache}) {
      %header_opts = ( -expires       => '-10y', # 'Expires' in the past
                       -last_modified => sprintf("%s, %s %s %s %s GMT", (split(/\s+/, gmtime))[0,2,1,4,3]), # Always modified
                       -cache_control => 'no-store, no-cache, must-revalidate, '
                                       . 'post-check=0, pre-check=0', # HTTP/1.1
                       -pragma        => 'no-cache', # HTTP/1.0
           );
    #}
    if ($opts->{refresh}) {
       $header_opts{-refresh} = $opts->{refresh};
    }
    if ($self->{cookies}) {
      $header_opts{-cookie} = $self->{cookies};
    }
    print $self->CGI->header(%header_opts) unless $opts->{noheader};
    
    if (defined $self->{benchmark}) {
      #$self->benchmark->stop('total'); || 
      $self->benchmark->start('template');
    }
    $self->update_page_clicks() unless $opts->{nopageclick};
    
    $_template = _init_template() unless $_template;
    
    foreach (keys(%$data)) { _dfs_on_anything($data->{$_},$_) } # Set utf8 flag where appropriate (see below)
    
    # If we have a referring page set, also set a uri escaped version
    # so we can use it in urls as well as hidden form fields! :)
    if ($self->{core}->{'ref'}) {
      require URI::Escape;
      $self->{core}->{'ref_escaped'} = URI::Escape::uri_escape($self->{core}->{'ref'});
    }
    
    # Make sure we haven't declared a 'core' data entry..
    if ($data->{core}) {
      $data->{oldcore} = $data->{core};
      warn '$data->{core} should not be allowed! renamed to $data->{oldcore}';
    }
    
    # Take our core values and add them to the data under 'core'.
    # 'core' values are things set up by default and constant to every
    # script (put into 'core' so as not to let individual scripts clobber
    # them if they were in the script's data set).  They include;
    # user_id, open_assistant, close_assistant, remembered_profile_name, remember_me,
    # self_url, benchmark.. and many more soon, i'm sure (from inheriting classes)!
    
    #$data->{core} = $self->{core};
    # Doing it this way stops using tied hashes for core values
    # and makes the values manipulatable (my new word)
    # from within the Template! Much faster and betterer.
    %{$data->{core}} = ( %{$self->{core}} );
    
    # Doing it here makes the 'total' pop up on the browser template,
    # but misses out the final step of rendering the template..
    #if (defined $self->benchmark) {
    #  $data->{core}->{benchmark} = sprintf('%0.3fms',
    #                                       $self->benchmark->result('total') * 1000);
    #}
    
    $data->{breadcrumbs} = [];
    
    # Copy the benchmark object for the template to use.
    if (defined $self->{benchmark}) {
      $data->{benchmark} = $self->{benchmark};
    }
    
    my $output = undef;
    if ($opts->{return_output}) {
      $_template->process($filename, $data, \$output)
        || die $_template->error(), "\n";
    } else {
      $_template->process($filename, $data)
        || die $_template->error(), "\n";
    }
    
    # This will be added to a benchmark log - and
    # all results here are accurate(ish)!
    if (defined $self->benchmark) {
      unless ($data->{core}->{benchmark}) {
        $self->benchmark->stop('template');
        $self->benchmark->stop('total');
        $self->{core}->{benchmark} = $self->benchmark->reports;
      }
      #my $total = "total: "
      #          . sprintf('%0.3fms', ($self->benchmark->result('total') +
      #                                $self->benchmark->result('template')) * 1000);
      #my $benchmark = $self->benchmark->reports;
      #$benchmark =~ s/^.+ of total .+\n//;
      #$self->{core}->{benchmark} = "$benchmark$total\n";
    }
    
    $self->{template_processed} = 1;
    
    return $output if defined $output;
  }
  
  # This function encodes any 'bla_id' fields so that important auto-increment IDs
  # are not exposed to the user (making it harder to iterate over photos, profiles,
  # search results, etc. etc. and to not let people know how many searches/new profiles we
  # get (as they could work out from seeing the increment interval of auto-incremented IDs)
  sub _encode_id_param($) {
    # We need to encode any IDs (eg. user_id, profile_id, photo_id, link_id etc.)
    return unless $_[0] =~ /^\d+$/o;
    my $secret_number = 1020348; # Matches the above num used to decode params :P
    # Add the internal signature of a '123' prefix to the original number, add secret number
    # Then convert to hex, reverse, add leading '9' to help nums which, when reversed
    # have leading zeros (as these would normally be dropped/ignored) and convert back to number
    $_[0] = hex('9'.scalar(reverse(sprintf('%lx', ('123'.$_[0])+$secret_number))));
    # Add the visible (easily faked param signature of a '!1' prefix and '5' before last digit
    $_[0] =~ s/^(\d+?)(\d)$/!1${1}5$2/o;
  }

  # This function html encodes anything that scares me and makes me think someone is trying to
  # inject XSS attacks or otherwise.  It should clean up all possibilities of html/JS coming
  # in as GET or POST data, whether HTML/URL encoded, character code refed and spat out again.
  sub _clean_data_html($) {
    use HTML::Entities 'encode_entities';
    $_[0] = HTML::Entities::encode_entities($_[0]);
  }
  # This can be used all over the place to redirect - it alsos handles automagic translations of
  # 'bla_id' query string params into encoded IDs (see above)..
  # It tries to take the args as if it were CGI::redirect and pass them through..
  sub redirect($$) {
    my $self = shift;
    my %opts = @_;
    # The right side of this regex is treated as a expression (via the /e switch)
    # Doh - can't do this since _encode_id_param modifies the read-only $2.. :(
    #$opts{'-url'} =~ s/([\?&;][\w\.\-]+?_id=)(\d+)([&;]|$)/$1.&_encode_id_param($2).$3/ge;
    while ($opts{'-url'} =~ m/([\?&;][\w\.\-]+?_id=)(\d+)([&;]|$)/g) {
      my ($prefix, $id_value, $suffix) = ($1, $2, $3);
      my $encoded_id_value = $id_value;
      _encode_id_param($encoded_id_value);
      #warn "replacing '$prefix$id_value$suffix' with '$prefix$encoded_id_value$suffix' in url '"."$opts{'-url'}"."'\n";
      $opts{'-url'} =~ s/\Q$prefix$id_value$suffix\E/$prefix$encoded_id_value$suffix/;
    }
    
    if ($self->{cookies} && ref($self->{cookies}) eq 'ARRAY') {
      if ($opts{'-cookie'} && ref($opts{'-cookie'}) eq 'ARRAY') {
        push @{$opts{'-cookie'}}, @{$self->{cookies}};
      } else {
        $opts{'-cookie'} = $self->{cookies};
      }
    }
    return $self->CGI->redirect(%opts);
  }
  
  # Loop over all of our data and ensure any utf8 scalar elements
  # are found within the structure and have the perl internal utf8
  # flag set (so that the ttml outputs multi-byte characters as one
  # character and not seperate bytes) - we should be doing this as
  # we get data from the database but for now I can't patch the DBD::mysql
  # module to set the utf8 flag where neccessary.  There is talk of it
  # being fixed in future releases.  When that happens, this can stop!
  # We are already setting the flag if there is utf8 data coming from CGI params
  # and we just need to set it as utf8 data comes out of the database..
  # This here is a quick fix to make sure everything displays correctly for
  # the user, but doing it this late does open up one potential boo-boo;
  # Any comparisons between strings within our code will not match if one
  # has the utf8 flag set and the other does not, even though they are the
  # same byte string! (ie. When data from the database without the utf8 flag set
  # on utf8 data is compared directly to CGI param data that we have set the utf8
  # flag on if it utf8 when we grab the params..)
  # But we don't do comparisons like that in the code, do we?  Any searching should
  # be left up to mysql 'LIKE' as it can perform expansions on the UTF8-Unicode encoding
  # and that allows for some very clever seeming languagey search functionality! :)
  # NEW: Also pass through the second arg of any hash KEYs found along the way so that the
  # values underneath each hash key have that key as a param to check whether the data
  # pertains to a '*_id' param and needs encoding before hitting the public..
  # EXTRA NEW: don't encode hash keys - they'll be written from the code - just do the vals.
  sub _dfs_on_anything($@); # Prototype to keep -w happy with the recursive calls!
  sub _dfs_on_anything($@) {
    
    sub _decode_if_utf8($) { utf8::decode($_[0]) unless utf8::is_utf8($_[0]) }
    
    my $reftype = ref($_[0]);
    if (!$reftype) {
      return unless defined($_[0]);
      _decode_if_utf8($_[0]);
      _encode_id_param($_[0])
        if $_[1] && $_[1] =~ /_id$/o;
      _clean_data_html($_[0]);
    } elsif ($reftype eq 'SCALAR') {
      return unless defined(${$_[0]});
      _decode_if_utf8(${$_[0]});
      _encode_id_param(${$_[0]})
        if $_[1] && $_[1] =~ /_id$/o;
      _clean_data_html(${$_[0]});
    } elsif ($reftype eq 'ARRAY') {
      foreach my $el (@{$_[0]}) {
        # check each element as if it could be anything!
        _dfs_on_anything($el, $_[1]);
      }
    } elsif ($reftype eq 'HASH') {
      foreach my $key (keys %{$_[0]}) {
        # check each element as if it could be anything!
        _dfs_on_anything(${$_[0]}{$key}, $key); # Send optional second arg of the param id
      }
    } elsif ($reftype eq 'REF') {
      # check this element as if it could be a ref to anything!
      _dfs_on_anything($$_[0], $_[1]);
    } else {
      # We cannot and will not decode utf8 of CODE, GLOB or bespoke objects!
    }
  }
  
  
  sub _init_template() {
    # This will only happen once per child under mod_perl
    # God bless mod_perl! :)
    require Template;
    
    my $ttml_dir = Cwd::fast_abs_path(File::Spec->rel2abs("../ttml/", $ENV{DOCUMENT_ROOT}));
    $ttml_dir = $1 if $ttml_dir =~ m!^(.+)/?$!;
    #warn "ttml dir: $ttml_dir";
    my $ttml_cache_dir = "/tmp/ttmlcache";
    #warn "ttml_cache dir: $ttml_cache_dir";
    
    my %CONFIG = ( INCLUDE_PATH => $ttml_dir,
                   #PRE_PROCESS => 'header.ttml',
                   #POST_PROCESS => 'footer.ttml'
                   # collapse all whitespace before a template directive into a single space
                   PRE_CHOMP => 2,
                   #PRE_CHOMP => 1, #delete all whitespace before a template directive
                   #DEBUG => 'parser',
                   EVAL_PERL => 1,
                   COMPILE_DIR => $ttml_cache_dir,
                   COMPILE_EXT => '.ttc',
                  );
    
    my $tt = Template->new(\%CONFIG)
      || die Template->error, "\n";
    # The above check for errors on new template object didn't work
    # when we had a template file perm error so below we do a primitive
    # manual check and throw a wobbly if we need to!
    die "Something's wrong with our template object!\nERROR1: $Template::ERROR\nERROR2: $tt"
      if ref($tt) ne 'Template';
    return $tt;
  }
}



{
  my %called_before;
  
  sub write_benchmark() {
    my $self = shift;
    my $caller = (caller(1))[1];
    
    # Do not log anything on the first call by this script because the first
    # call has to compile everything and isn't a fair benchmark for mod_perl scripts!
    if ($ENV{MOD_PERL}) {
      if (!$called_before{$caller}) {
        $called_before{$caller} = 1;
        return undef;
      }
    }
    
    require File::Spec;
    $caller = File::Spec->abs2rel($caller, $ENV{DOCUMENT_ROOT});
    if (defined $self->benchmark) {
      unless ($self->{template_processed}) {
        $self->benchmark->stop('total');
      }
      #warn "destroying!\n"; # :" . (caller)[1] . "\n";
      #if ($self->{benchmark}->result('total') > 0.2) {
      #  warn "SLOW REQUEST (" . $self->{benchmark}->result('total')
      #     . " secs): " . $ENV{'REQUEST_URI'}
      #     . " [ $benchmarks ]";
      #}
      if ($self->{core}->{benchmark}) {
        #print BENCHMARK "$caller:\n" . $self->{core}->{benchmark} . "=====\n";
      } else {
        #print BENCHMARK "$caller:\n" . $self->benchmark->reports . "=====\n";
      }
      #BENCHMARK->autoflush(1);
      if ($self->{template_processed}) {
    $self->_write_db_benchmark( $caller, $self->benchmark->result('total') +
                       $self->benchmark->result('template') );
      } else {
    $self->_write_db_benchmark( $caller, $self->benchmark->result('total') );
    
      }
    } elsif ($self->{template_processed}) {
      if ($self->{core}->{benchmark}) {
        #print BENCHMARK "$caller:\n" . $self->{core}->{benchmark} . "=====\n";
        #BENCHMARK->autoflush(1);
        $self->_write_db_benchmark( $caller, $self->benchmark->result('total') +
                                             $self->benchmark->result('template') );
      }
    } elsif ($self->{core}->{benchmark}) {
      #print BENCHMARK "$caller:\n" . $self->{core}->{benchmark} . "=====\n";
      #BENCHMARK->autoflush(1);
      $self->_write_db_benchmark( $caller, $self->benchmark->result('total') +
                                           $self->benchmark->result('template') );
    }
    
    sub _write_db_benchmark() {
      my $self = shift;
      my $caller = shift;
      my $benchmark_time = shift;
      
      my $dbh = $self->DBH;
      my $query = <<ENDSQL
INSERT DELAYED INTO `site~stats~benchmarks`
SET num_benchmarks = 1,
    total_time = ?,
    date = CURRENT_DATE(),
    script = ?,
    mode = ?
ON DUPLICATE KEY UPDATE num_benchmarks = num_benchmarks + 1,
                        total_time = total_time + ?
ENDSQL
;
      my $sth = $dbh->prepare_cached($query);
      $sth->execute( ($benchmark_time * 1000),
                     ($caller || ' '),
                     ($self->{params}->{mode} || ' '),
                     ($benchmark_time * 1000) );
      $sth->finish;
    }
  }
}



sub _get_user_id($) {
  
  my $self = shift;
  my $dbh = $self->DBH;
  
  # If no cookie data was found, then return bad failure.
  $! = "no session found" && return 0 unless $self->session_cookie;
  
  # Else check in db for session match
  # If session idle timeout is reached, then notify
  # here - at least that way we don't have to get the
  # garbageman to clean them up as regularly! Good, eh?
  
  my $query = <<ENDSQL
SELECT user_id, ip_address
FROM `user~session`
WHERE session_id = ?
  AND updated > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
  AND created IS NOT NULL
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($self->session_cookie);
  my ($user_id, $ip_address) = $sth->fetchrow_array();
  $sth->finish;
  
  #warn "looking up user id on session: " . $self->session_cookie
  #   . " and found ($user_id ? "user id: $user_id" : "no user id";
  
  # If no trace of the session is found, it has expired
  # Perhaps removed by database session timeout cleaner
  # or perhaps not - it will be removed in under 10 mins
  # when garbageman comes to do his stuff anyway. So let
  # it be for now.  We don't really care, do we? Non..
  if (!$user_id) {
    
    $! = "session expired" && return 0;
    
  } else {
    
    $query = <<ENDSQL
UPDATE `user~session`
SET updated = NOW()
ENDSQL
;
    
    my @params = ();
    
    # We don't care about this for now.. We will when things get bigger.
    # We still need to get the IP from proxy if it has changed though
    # (see our ip_address function in this module)
    #if ($ip_address ne $ENV{'REMOTE_ADDR'}) {
    #  
    #  warn "IP address changed for user $user_id from $ip_address to $ENV{REMOTE_ADDR}";
    #  $query .= ", ip_address = ? ";
    #  push @params, $ENV{REMOTE_ADDR};
    #}
    
    $query .= <<ENDSQL
WHERE session_id = ?
  AND updated > DATE_SUB(NOW(), INTERVAL 31 MINUTE)
  AND created IS NOT NULL
LIMIT 1
ENDSQL
;
    push @params, $self->session_cookie;
    $sth = $dbh->prepare_cached($query);
    $sth->execute(@params);
    $sth->finish;
    
    return $user_id;
  }
}




sub _get_visitor_id_while_logged_in($) {
  
  # Just check to see what visitor id they used to have before logging in
  # (this is used for things like search sessions where we want them to persist
  #  whether they're logged in or out.  This particularly helps them continue
  #  viewing their search results if their logged in session expires).
  
  my $self = shift;
  
  my $visitor_ref = $self->visitor_cookie;
  
  return 0 if length($visitor_ref) != 24;
  
  my $query = <<ENDSQL
SELECT visitor_id
FROM `visitor`
WHERE visitor_ref = ?
LIMIT 1
ENDSQL
;
  my $sth = $self->DBH->prepare_cached($query);
  $sth->execute($visitor_ref);
  my ($visitor_id) = $sth->fetchrow_array();
  $sth->finish;
  
  return $visitor_id
}




sub _get_visitor_id($) {
  
  my $self = shift;
  
  my $dbh = $self->DBH;
  my ($query, $sth);
  my $visitor_ref = $self->visitor_cookie;
  
  # If no cookie data was found, then try to set a test visitor cookie and
  # return failure for now. If test cookie is found, set long-term cookie.
  if (length($visitor_ref) != 24) {
    
    if (!$visitor_ref) {
      
      # set test cookie for new visitor.  on next request, we'll find this and set
      # up a visitor session for them and update the cookie.  if not, and cookies
      # are disabled, at least all we're doing is trying to add a cookie every request
      # and nothing heavier on the system or cluttering in the database..
      push @{$self->{cookies}}, $self->CGI->cookie( -name    => "visitor",
                                                    -value   => "test");
      return undef;
      
    } elsif ($visitor_ref eq "test") {
      
      # Cookies are working so let's create them as a new visitor in the db..
      $visitor_ref = $ENV{'UNIQUE_ID'};
      
      $query = <<ENDSQL
INSERT IGNORE INTO `visitor`
( visitor_ref )
VALUES
( ? )
ENDSQL
;
      $sth = $dbh->prepare_cached($query);
      # Try again next time if a visitor reference is already in
      # the database (this is very unlikely as apache can generate 64^24
      # permutations of this unique ID - that's 2.23007452 x 10^43, or
      # 22,300,745,198,530,623,141,535,718,272,648,000,000,000,000!)
      return undef unless $sth->execute($visitor_ref);
      $sth->finish;
      
      # Get the visitor id of the visitor we just created.
      my $visitor_id = $dbh->{mysql_insertid};
      
      # Create stats for visitor (when they first visited).
      $query = <<ENDSQL
INSERT INTO `visitor~stats`
( visitor_id, user_agent, first_visit )
VALUES
( ?, ?, NOW() )
ENDSQL
;
      $sth = $dbh->prepare_cached($query);
      $sth->execute($visitor_id, $ENV{HTTP_USER_AGENT});
      $sth->finish;
      
      # Create this session for them..
      $query = <<ENDSQL
INSERT INTO `visitor~session`
( visitor_ref, visitor_id, ip_address, created, clicks )
VALUES
( ?, ?, ?, NOW(), 1 )
ENDSQL
;
      $sth = $dbh->prepare_cached($query);
      $sth->execute($visitor_ref, $visitor_id, $ENV{'REMOTE_ADDR'});
      $sth->finish;
      
      # set cookie for new visitor with new visitor ref and session added to db.
      push @{$self->{cookies}}, $self->CGI->cookie( -name    => "visitor",
                                                    -value   => $visitor_ref,
                                                    -expires => '+10y' );
      
      # Perhaps return some special code too to the caller..
      # So we can let them know it's a new visitor to say "WELCOME!".
      # Oh no, that would really annoy me if i wasn't new but on new comp..  Grr! :)
      return ($visitor_id, 0);
      
    } else {
      
      # Cookie was set but was not a visitor ref (24 chars) or the 'test' cookie.
      warn "visitor cookie not set to 24 char visitor ref or test string: "
         . $visitor_ref;
      # Overwrite the visitor cookie with another test string..
      push @{$self->{cookies}}, $self->CGI->cookie( -name    => "visitor",
                                                    -value   => "test");
      return undef;
    }
    
  } else {
    
    # If there is a visitor cookie set with a visitor reference contained inside,
    # check to see if that visitor reference has a current session.
    $query = <<ENDSQL
SELECT visitor_id, ip_address
FROM `visitor~session`
WHERE visitor_ref = ?
  AND updated > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
LIMIT 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($visitor_ref);
    my ($visitor_id, $ip_address) = $sth->fetchrow_array();
    $sth->finish;
    
    if ($visitor_id) {
      
      # If a valid session exists, just update it to say we are still here.
      $query = <<ENDSQL
UPDATE `visitor~session`
SET updated = NOW()
ENDSQL
;
      my @params = ();
      # We don't care about this for now.. We will when things get bigger.
      # We still need to get the IP from proxy if it has changed though
      # (see our ip_address function in this module)
      #if ($ip_address ne $ENV{'REMOTE_ADDR'}) {
      #  
      #  warn "IP address changed for visitor $visitor_ref from $ip_address to $ENV{REMOTE_ADDR}";
      #  $query .= ", ip_address = ? ";
      #  push @params, $ENV{REMOTE_ADDR};
      #}
      
      $query .= <<ENDSQL
WHERE visitor_id = ?
  AND updated > DATE_SUB(NOW(), INTERVAL 31 MINUTE)
LIMIT 1
ENDSQL
;
      push @params, $visitor_id;
      $sth = $dbh->prepare_cached($query);
      $sth->execute(@params);
      $sth->finish;
      
      return $visitor_id;
      
    } else {
      
      # Double check to see if they exist in case they made up the cookie! :O
      $query = <<ENDSQL
SELECT visitor_id
FROM `visitor`
WHERE visitor_ref = ?
LIMIT 1
ENDSQL
;
      $sth = $dbh->prepare_cached($query);
      $sth->execute($visitor_ref);
      my ($visitor_id) = $sth->fetchrow_array();
      $sth->finish;
      
      if (!$visitor_id) {
        
        # Ooooh fake visitor cookie!  What a BAD ASS!! :\
        # Forget being nice to them and sorting this out properly,
        # just delete their cookie and next request, it'll sort itself out.
        warn "A BADASS ($ENV{REMOTE_ADDR}) had a fake visitor ref cookie set:"
           . $visitor_ref;
        push @{$self->{cookies}}, $self->CGI->cookie( -name    => "visitor",
                                                      -value   => '',
                                                      -expires => '-1d' );
        return undef;
      }
      
      # Otherwise, create new session after cleaning up their old ones.
      $self->cleanUpOldVisitorSession($visitor_id);
      
      $query = <<ENDSQL
INSERT INTO `visitor~session`
( visitor_ref, visitor_id, ip_address, created, clicks )
VALUES
( ?, ?, ?, NOW(), 1 )
ENDSQL
;
      $sth = $dbh->prepare_cached($query);
      $sth->execute($visitor_ref, $visitor_id, $ENV{'REMOTE_ADDR'});
      $sth->finish;
      
      # Perhaps return some special code too to the caller..
      # So we can let them know it's an old visitor come back to say "WELCOME BACK!".
      # Perhaps it's worth either upping the time-out or also setting a session
      # cookie that dies when the browser closes?  Hmmm..  Timeouts, timeouts..
      return ($visitor_id, 1);
    }
  }
}




sub redirectToLoginPage($) {
  
  my $self = shift;
  my $ref = shift;
  
  if ($ref) {
    require URI::Escape;
    $ref = URI::Escape::uri_escape($ref);
  }
  
  print $self->redirect( -url => '/login.pl?'
                               . ($ref ? "ref=$ref&" : '')
                               . ($self->{core}->{timed_out} ? 'timed_out=1' : '') );
  
  return Constants::STATUS_OK;
}





sub update_page_clicks($) {
  
  my $self = shift;
  
  if ($self->session_cookie) {
    
    my $query = <<ENDSQL
UPDATE `user~session`
SET clicks = clicks + 1,
    updated = NOW()
WHERE session_id = ?
  AND updated > DATE_SUB(NOW(), INTERVAL 31 MINUTE)
  AND created IS NOT NULL
LIMIT 1
ENDSQL
;
    my $sth = $self->DBH->prepare_cached($query);
    $sth->execute($self->session_cookie);
    $sth->finish;
    
  } elsif ($self->visitor_cookie) {
    
    my $query = <<ENDSQL
UPDATE `visitor~session`
SET clicks = clicks + 1
WHERE visitor_id = ?
  AND updated > DATE_SUB(NOW(), INTERVAL 31 MINUTE)
LIMIT 1
ENDSQL
;
    my $sth = $self->DBH->prepare_cached($query);
    $sth->execute($self->{core}->{'visitor_id'});
    $sth->finish;
    
  } else {
    
    return 0;
  }
  return 1;
}



{
  # This set of subs allows many lookups between database fields
  # but only requires one database call for as many as you like!
  # On the first call, a hash is populated with all info
  # and can be retrieved on future lookups. How efficient!
  # They will be destroyed after each request to stop mod_perl
  # keeping their values (leaking memory & using old stale data).
  # All encapsulated too so you "can't touch this". Hee hee.
  
  my ($user_info, $self);
  sub _user_info_DESTROY() { undef $user_info; }
  
  sub is_email_validated($) {
    $self = shift;
    my $user_id = shift;
    _lookup_user_info($user_id) unless exists($user_info->{user_id});
    return ($user_info->{email_validated} ? 1 : 0);
  }
  
  sub get_email_address($) {
    $self = shift;
    my $user_id = shift;
    _lookup_user_info($user_id) unless exists($user_info->{user_id});
    return $user_info->{email};
  }
  
  sub _lookup_user_info($) {
    
    my $user_id = shift;
    
    my $query = <<ENDSQL
SELECT SQL_CACHE user_id, email, email_validated
FROM `user`
WHERE user_id = ?
LIMIT 1
ENDSQL
;
    my $sth = $self->DBH->prepare_cached($query);
    $sth->execute($user_id);
    $user_info = $sth->fetchrow_hashref();
    $sth->finish;
  }
}


# At one point I thought that this wasn't important but i think it has a
# place checking in areas like signup or other things that we don't want
# to be easily faked by transforming to a GET and changing params..
sub ensure_post() {
  
  my $self = shift;
  
  if ($ENV{'REQUEST_METHOD'} eq 'GET') {
    
    # Typing login info into the address bar?
    # Very clever.. Now use the form like everyone else.
    warn "user $self->{core}->{'user_id'} "
       . "performed GET where POST was wanted "
       . "on page $self->{core}->{'self_url'}";
    return 0;
    
  } elsif ($ENV{'REQUEST_METHOD'} ne 'POST') {
    
    # How did you do that? That's magic! Seriously, HOW??
    warn "user $self->{core}->{'user_id'} "
       . "performed unkown method: '$ENV{'REQUEST_METHOD'}' where POST was wanted "
       . "on page $self->{core}->{'self_url'}";
    return undef;
  }
  return 1;
}




sub random_word() {
  
  # Pick a random line out of 2 word lists
  # containing 3-5 letter adjectives and nouns
  # This method means that we don't have to store
  # the whole file in memory.
  # (See Perl Cookbook: Recipe 8.6.
  #      Picking a Random Line from a File)
  
  # UPDATE - Added mod_perl clauses for this code:
  # Fark that - store it in memory!  Memory is cheap
  # but time is precious..  Let's be fast damn it!
  # Especially given the yummy persistence we have.
  
  use vars qw( @ADJECTIVES @NOUNS );
  
  my $self = shift;
  
  unless (@rusty::ADJECTIVES) {
    open ADJECTIVES, "$ENV{DOCUMENT_ROOT}/../lib/words/adjectives.txt" or warn $! and return;
    @rusty::ADJECTIVES = <ADJECTIVES> if $ENV{MOD_PERL};
    close ADJECTIVES;
  }
  
  my $adjective;
  if ($ENV{MOD_PERL}) {
    $adjective = $rusty::ADJECTIVES[int(rand(@rusty::ADJECTIVES+0))];
    #warn "found adjective: $adjective from list of " . (@rusty::ADJECTIVES+0) . " adjectives.";
    #warn "rand is:" . int(rand(@rusty::ADJECTIVES+0));
  } else {
    # NB. $. is the same as $INPUT_LINE_NUMBER
    rand($.) < 1 && ($adjective = $_) while <ADJECTIVES>;
  }
  chomp($adjective);
  
  unless (@rusty::NOUNS) {
    open NOUNS, "$ENV{DOCUMENT_ROOT}/../lib/words/nouns.txt" or warn $! and return;
    @rusty::NOUNS = <NOUNS> if $ENV{MOD_PERL};
    close NOUNS;
  }
  
  my $noun;
  if ($ENV{MOD_PERL}) {
    $noun = $rusty::NOUNS[int(rand(@rusty::NOUNS+0))];
    #warn "found noun: $noun from list of " . (@rusty::NOUNS+0) . " nouns.";
    #warn "rand is:" . int(rand(@rusty::NOUNS+0));
  } else {
    rand($.) < 1 && ($noun = $_) while <NOUNS>;
  }
  chomp($noun);
  
  #if (int(rand(1234)) + int(rand(2345)) == 0) {
  #  warn "randomness is not working! :(";
  #}
  
  return lc($adjective.$noun);

}




# returns a hashref with lookup->value from the given lookup table
sub get_lookup_hash($@) {
  
  my $self = shift;
  my $params = { @_ };
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT SQL_CACHE $params->{id}, $params->{data}
FROM `$params->{table}`
ENDSQL
;
  
  $query .= ($params->{where} ? "WHERE $params->{where}\n" : "");
  
  my $sth = $dbh->prepare_cached($query);
  $sth->execute();
  
  my $hash;
  
  while (my ($id, $data) = $sth->fetchrow_array) {
    $hash->{$id} = $data;
  }
  $sth->finish;
  
  return $hash;
}




# returns an array with lookup->value from the given lookup table, ordered!
sub get_ordered_lookup_list($@) {
  
  my $self = shift;
  my $params = { @_ };
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT SQL_CACHE $params->{id}, $params->{data}
FROM `$params->{table}`
ENDSQL
;
  $params->{order} ||= $params->{id};
  $query .= ($params->{where} ? "WHERE $params->{where}\n" : "")
          . "ORDER BY $params->{order}\n";
  
  my $sth = $dbh->prepare_cached($query);
  $sth->execute();
  
  my @array;
  
  while (my ($id, $data) = $sth->fetchrow_array) {
    push @array, { value => $id,
                   name  => $data };
  }
  
  $sth->finish;
  
  return @array ? @array : undef;
}




sub validate_params($) {
  
  my $self = shift;
  
  foreach my $param_name (keys %{$self->{param_info}}) {
    
    #Clear trailing space.
    (my $param = $self->{params}->{$param_name}) =~ s/\s*$//o;
    my $param_info = $self->{param_info}->{$param_name};
    
    # If we're allowed to have an empty field and it is empty, then skip.
    next if $param_info->{allow_empty} && length($param) == 0;
    
    if ($param_info->{minlength} > 0 && length($param) < $param_info->{minlength}) {
      
      $self->{param_errors}->{$param_name}->{error} = (length($param) == 0) ?
        "must be filled in" :
        "must be at least $param_info->{minlength} characters";
        
    } elsif ($param_info->{maxlength} > 0 && length($param) > $param_info->{maxlength}) {
      
      $self->{param_errors}->{$param_name}->{error} =
        "must be less than $param_info->{minlength} characters";
        
    } elsif ($param_info->{minnum} =~ /^[+-]?\d+$/o || $param_info->{maxnum} =~ /^[+-]?\d+$/o) {
      
      # see if param is numeric
      if ($param !~ /^[+-]?\d+$/) {
        
        $self->{param_errors}->{$param_name}->{error} =
          "must be a number (eg. -1, 0, 1, 100)";
        
      } else {
        if ($param < $param_info->{minnum}) {
          
          $self->{param_errors}->{$param_name}->{error} =
            "must be greater than or equal to $param_info->{minnum}";
            
        } elsif ($param > $param_info->{maxnum}) {
          
          $self->{param_errors}->{$param_name}->{error} =
            "must be less than or equal to $param_info->{maxnum}";
            
        }
      }
    } elsif ($param_info->{regexp} || $param_info->{notregexp}) {
      
      my $regexp = ($param_info->{regexp} || $param_info->{notregexp});
      $regexp =~ s!/!\\/!og; # make '/'s safe!
      
      # if regexp given, match on whole line
      if ( ($param_info->{regexp} && $param !~ /$regexp/) ||
           ($param_info->{notregexp} && $param =~ /$regexp/) ){
        
        if ($param =~ /^\s*$/o) {
          
          $self->{param_errors}->{$param_name}->{error} =
            "must be filled in";
        } else {
          
          $self->{param_errors}->{$param_name}->{error} =
            "contains disallowed characters";
        }
      }
    }
    
    # If we found an error and the param was an option list,
    # give the user a sensible error message for that param.
    if ($self->{param_errors}->{$param_name} &&
        $param_info->{type} eq 'select') {
      
      $self->{param_errors}->{$param_name}->{error} =
        "must have a value selected";
    }
    
    # If any errors were found above, fill up the title of the param
    # so we have a nice pretty name for it in the user's error message.
    if (exists($self->{param_errors}->{$param_name})) {
      
      $self->{param_errors}->{$param_name}->{title} = $param_info->{title};
    }
  }
  
  return scalar keys %{$self->{param_errors}};

}




sub cleanUpOldUserSession($$) {
  
  my $self = shift;
  my $user_id = shift;
  my $dbh = $self->DBH;
  
  # Delete all sessions which belong to cookie tests that failed
  # for this user.
  
  my $query = <<ENDSQL
DELETE FROM `user~session`
WHERE user_id = ?
  AND created IS NULL
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($user_id);
  $sth->finish;
  
  # Grab all session information for sessions from a user specified.
  # Then add the session info to user's stats and remove the session.
  #
  # Also check created is not null - so that this isn't a
  # failed test session to see if cookies were working!
  
  $query = <<ENDSQL
SELECT session_id, user_id, clicks,
       FLOOR((UNIX_TIMESTAMP(updated) - UNIX_TIMESTAMP(created)) / 60)
         AS mins_online, updated
FROM `user~session`
WHERE user_id = ?
ENDSQL
;
  $sth = $dbh->prepare_cached($query);
  $sth->execute($user_id);
  
  # Set up interpolated statement for use with bind values
  # for the UPDATE and DELETE statements for each session id.
  
  my $update_query = <<ENDSQL
UPDATE `user~stats`
SET last_session_end = IF(ISNULL(last_session_end), ?,
                          IF(? > last_session_end, ?, last_session_end)),
    mins_online = mins_online + ?, 
    num_clicks = num_clicks + ?
WHERE user_id = ?
LIMIT 1
ENDSQL
;
  my $update_sth = $dbh->prepare_cached($update_query);
  
  my $delete_query = <<ENDSQL
DELETE FROM `user~session`
WHERE session_id = ?
LIMIT 1
ENDSQL
;
  my $delete_sth = $dbh->prepare_cached($delete_query);
  
  my $rot_query = <<ENDSQL
UPDATE `user~session`
SET session_id = CONCAT("ERROR: ", SUBSTRING(session_id, 8)),
    user_id = NULL,
    updated = updated # Make sure it is not updated on update!
WHERE session_id = ?
LIMIT 1
ENDSQL
;
  my $rot_sth = $dbh->prepare_cached($rot_query);
  
  # Loop through each expired session found and perform
  # the UPDATE and DELETE statement templates above.
  
  while (my $expired_session = $sth->fetchrow_hashref) {
    
    my $mins_online = $expired_session->{'mins_online'};
    
    if ($mins_online < 0) {
      
      warn "We REALLY shouldn't be getting "
         . "$mins_online mins online for sessions, so "
         . "session ".$expired_session->{'session_id'}
         . " has been left to rot in it's own ridiculousness.";
      # Leave session there to be found for debugging! =D
      $rot_sth->execute($expired_session->{'session_id'});
      next;
    }
    
    my $rows = $update_sth->execute(
                                    $expired_session->{'updated'},
                                    $expired_session->{'updated'},
                                    $expired_session->{'updated'},
                                    $mins_online,
                                    $expired_session->{'clicks'},
                                    $expired_session->{'user_id'}
                                    )
      || die "Unable to execute query: ".$dbh->errstr;
    
    if ($rows eq '0E0') {
      warn "No rows affected by update query on user id "
         . $expired_session->{'user_id'}."'s stats - "
         . "I reckon they need some stats creating..";
      next;
    }
    
    $rows = $delete_sth->execute($expired_session->{'session_id'})
      || die "Unable to execute query: ".$dbh->errstr;
    
    if ($rows eq '0E0') {
      warn "No rows affected by delete query on expired session id '"
         . $expired_session->{'session_id'}."'. This is impossible!";
      next;
    }
  }
  $sth->finish;
  $rot_sth->finish;
  $update_sth->finish;
  $delete_sth->finish;
  return 1;
}




sub cleanUpOldVisitorSession($$) {
  
  my $self = shift;
  my $visitor_id = shift;
  my $dbh = $self->DBH;
  
  # Grab all session information for sessions from a visitor specified.
  # Then add the session info to user's stats and remove the session.
  
  my $query = <<ENDSQL
SELECT visitor_id, clicks,
       FLOOR((UNIX_TIMESTAMP(updated) - UNIX_TIMESTAMP(created)) / 60)
         AS mins_online, updated
FROM `visitor~session`
WHERE visitor_id = ?
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($visitor_id);
  
  # Set up interpolated statement for use with bind values
  # for the UPDATE and DELETE statements for each session id.
  
  my $update_query = <<ENDSQL
UPDATE `visitor~stats`
SET last_session_end = IF(ISNULL(last_session_end), ?,
                          IF(? > last_session_end, ?, last_session_end)),
    num_visits = num_visits + 1,
    mins_online = mins_online + ?, 
    num_clicks = num_clicks + ?
WHERE visitor_id = ?
LIMIT 1
ENDSQL
;
  my $update_sth = $dbh->prepare_cached($update_query);
  
  my $delete_query = <<ENDSQL
DELETE FROM `visitor~session`
WHERE visitor_id = ?
LIMIT 1
ENDSQL
;
  my $delete_sth = $dbh->prepare_cached($delete_query);
  
  my $rot_query = <<ENDSQL
UPDATE `visitor~session`
SET visitor_ref = CONCAT("ERROR: ", SUBSTRING(visitor_ref, 8)),
    visitor_id = NULL,
    updated = updated # Make sure it is not updated on update!
WHERE visitor_id = ?
LIMIT 1
ENDSQL
;
  my $rot_sth = $dbh->prepare_cached($rot_query);

  # Loop through each expired session found and perform
  # the UPDATE and DELETE statement templates above.
  
  while (my $expired_session = $sth->fetchrow_hashref) {
    
    my $mins_online = $expired_session->{'mins_online'};
    
    if ($mins_online < 0) {
      
      warn "We REALLY shouldn't be getting "
         . "$mins_online mins online for sessions, so "
         . "visitor id ".$expired_session->{'visitor_id'}
         . " has been left to rot in it's own ridiculousness.";
      # Leave session there to be found for debugging! =D
      $rot_sth->execute($expired_session->{'session_id'});
      next;
    }
    
    my $rows = $update_sth->execute(
                                    $expired_session->{'updated'},
                                    $expired_session->{'updated'},
                                    $expired_session->{'updated'},
                                    $mins_online,
                                    $expired_session->{'clicks'},
                                    $expired_session->{'visitor_id'}
                                    )
      || die "Unable to execute query: ".$dbh->errstr;
    
    if ($rows eq '0E0') {
      warn "No rows affected by update query on visitor id "
         . $expired_session->{'visitor_id'}."'s stats - "
         . "I reckon they need some stats creating..";
      next;
    }
    
    $rows = $delete_sth->execute($expired_session->{'visitor_id'})
      || die "Unable to execute query: ".$dbh->errstr;
    
    if ($rows eq '0E0') {
      warn "No rows affected by delete query on expired visitor id '"
         . $expired_session->{'visitor_id'}."'. This is impossible!";
      next;
    }
  }
  $sth->finish;
  $rot_sth->finish;
  $update_sth->finish;
  $delete_sth->finish;
  return 1;
}




sub convertVisitorSessionToUserSession($$) {
  
  my $self = shift;
  my ($visitor_id, $session_id) = @_;
  my $dbh = $self->DBH;
  
  # Grab all session information for sessions from a visitor specified
  # and add it to the new session created for the user that was that visitor..
  
  my $query = <<ENDSQL
SELECT created, clicks
FROM `visitor~session`
WHERE visitor_id = ?
  AND updated > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
LIMIT 1
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($visitor_id);
  my $visitor_session = $sth->fetchrow_hashref;
  $sth->finish;
  
  if ($visitor_session) {
    
    $query = <<ENDSQL
UPDATE `user~session`
SET created = ?,
    clicks = clicks + ?,
    updated = NOW()
WHERE session_id = ?
  AND created > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
LIMIT 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($visitor_session->{created},
                  $visitor_session->{clicks},
                  $session_id);
    $sth->finish;
    
    $query = <<ENDSQL
DELETE FROM `visitor~session`
WHERE visitor_id = ?
LIMIT 1
ENDSQL
;
    $sth = $dbh->prepare_cached($query);
    $sth->execute($visitor_id);
    $sth->finish;
    
    return 1;
  }
  
  return 0;
}




sub populate_site_stats() {
  
  my $self = shift;
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT SUM(signups) AS signups, SUM(logins) AS logins
FROM `site~stats`
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute();
  $self->{data}->{site_stats} = $sth->fetchrow_hashref();
  $sth->finish;
  
  # Grab all session information for sessions from a user specified.
  # Then add the session info to user's stats and remove the session.
  #
  # Also check created is not null - so that this isn't a
  # failed test session to see if cookies were working!
  
  $query = <<ENDSQL
SELECT COUNT(*) AS online
FROM `user~session`
WHERE updated >= DATE_SUB(NOW(), INTERVAL 30 MINUTE)
  AND created IS NOT NULL
ENDSQL
;
  
  $sth = $dbh->prepare_cached($query);
  $sth->execute();
  ($self->{data}->{site_stats}->{online}) = $sth->fetchrow_array();
  $sth->finish;
}




sub populate_user_stats() {
  
  my $self = shift;
  my $user_id = shift;
  my $dbh = $self->DBH;
  
  my $query = <<ENDSQL
SELECT DATE_FORMAT(stats.joined, "%l%p on %a %D %b %y") AS joined,
       DATE_FORMAT(stats.last_session_end, "%l%p on %a %D %b %y") AS last_session_end,
       stats.num_logins,
       sess.clicks + stats.num_clicks AS num_clicks,
       IFNULL(FLOOR((UNIX_TIMESTAMP(sess.updated) - UNIX_TIMESTAMP(sess.created)) / 60), 0)
         + stats.mins_online AS mins_online,
       stats.total_visited_count,
       stats.unique_visited_count
FROM `user~stats` stats
LEFT JOIN `user~session` sess ON sess.user_id = stats.user_id
                             AND sess.updated IS NOT NULL
                             AND sess.created IS NOT NULL
WHERE stats.user_id = ?
ENDSQL
;
  my $sth = $dbh->prepare_cached($query);
  $sth->execute($user_id);
  my $user_stats = $sth->fetchrow_hashref();
  $sth->finish;
  
  # Convert mins online into years, months (OR weeks), days, hours and mins..
  my $time_online;
  $time_online->{mins} = $user_stats->{mins_online};
  ($time_online->{years} = int($time_online->{mins} / (60 * 24 * 365)))
    && ($time_online->{mins} %= (60 * 24 * 365));
  if ($time_online->{months} = int($time_online->{mins} / (60 * 24 * 30))) {
    $time_online->{mins} %= (60 * 24 * 30);
  } elsif ($time_online->{weeks} = int($time_online->{mins} / (60 * 24 * 7))) {
    $time_online->{mins} %= (60 * 24 * 7);
  }
  ($time_online->{days} = int($time_online->{mins} / (60 * 24)))
    && ($time_online->{mins} %= (60 * 24));
  ($time_online->{hours} = int($time_online->{mins} / 60))
    && ($time_online->{mins} %= 60);
  $user_stats->{time_online} = $time_online;
  
  #$user_stats->{clicks_per_hour} =
  #  $user_stats->{num_clicks} / $user_stats->{mins_online};
  
  $self->{data}->{user_stats} = $user_stats;
}



#sub ip_address() {
  
  # Get the real IP if hidden by proxy.
  
  # This module is reeaally not required!
  # Who cares about the IP address?? (For now).
  
  # HTTP_X_FORWARDED_FOR Could be a list of proxies passed through..
  # Take first of comma seperated list.
  
  # Client IP header *could* be sent backwards..
  # For traceback we should really store the IP *and* the fwded for info..
  # The fwded for can also be faked easily but.. Remote_addr is harder to fake.
  
  #my @server_vars = qw( HTTP_X_FORWARDED_FOR
  #                      HTTP_X_FORWARDED
  #                      HTTP_FORWARDED_FOR
  #                      HTTP_FORWARDED
  #                      HTTP_X_COMING_FROM
  #                      HTTP_COMING_FROM
  #                      HTTP_CLIENT_IP
  #                      HTTP_VIA
  #                      REMOTE_ADDR );
  #
  #foreach (@server_vars) {
  #  
  #}
  
  #if($loopback_bug) { // using dumb hosting provider like f2s
  #    $ip       = get_real_IP();
  # } else if(isset($HTTP_VIA) && $HTTP_VIA) { // Using proxy!
  #    $ip       = get_real_IP();
  #    $proxy    = trim(addslashes(urldecode(strstr($HTTP_VIA,' '))));
  #    $proxy_ip = (get_IP()) ? get_IP() : $ip;
  # } else { // Not using proxy...
  #    $ip       = (get_IP()) ? get_IP() : get_real_IP();
  # } 
  #
  #if($HTTP_X_FORWARDED_FOR) { // case 1.A: proxy && HTTP_X_FORWARDED_FOR is defined
  #     $array = extractIP($HTTP_X_FORWARDED_FOR);
  #     if ($array && count($array) >= 1) {
  #         return $array[0]; // first IP in the list
  #     }
  #}
  #if($HTTP_X_FORWARDED) { // case 1.B: proxy && HTTP_X_FORWARDED is defined
  #     $array = extractIP($HTTP_X_FORWARDED);
  #     if ($array && count($array) >= 1) {
  #         return $array[0]; // first IP in the list
  #     }
  #}
  #if($HTTP_FORWARDED_FOR) { // case 1.C: proxy && HTTP_FORWARDED_FOR is defined
  #     $array = extractIP($HTTP_FORWARDED_FOR);
  #     if ($array && count($array) >= 1) {
  #         return $array[0]; // first IP in the list
  #     }
  #}
  #if($HTTP_FORWARDED) { // case 1.D: proxy && HTTP_FORWARDED is defined
  #     $array = extractIP($HTTP_FORWARDED);
  #     if ($array && count($array) >= 1) {
  #         return $array[0]; // first IP in the list
  #     }
  #}
  #if($HTTP_CLIENT_IP) { // case 1.E: proxy && HTTP_CLIENT_IP is defined
  #     $array = extractIP($HTTP_CLIENT_IP);
  #     if ($array && count($array) >= 1) {
  #         return $array[0]; // first IP in the list
  #     }
  #}
  #/*
  #if($HTTP_VIA) {
  #// case 2:
  #// proxy && HTTP_(X_) FORWARDED (_FOR) not defined && HTTP_VIA defined
  #/ other exotic variables may be defined
  #return ( $HTTP_VIA .
  #         '_' . $HTTP_X_COMING_FROM .
  #         '_' . $HTTP_COMING_FROM             ) ;
  #}
  #if( $HTTP_X_COMING_FROM || $HTTP_COMING_FROM ) {
  #// case 3: proxy && only exotic variables defined
  #// the exotic variables are not enough, we add the REMOTE_ADDR of the proxy
  #return ( $REMOTE_ADDR .
  #        '_' . $HTTP_X_COMING_FROM .
  #        '_' . $HTTP_COMING_FROM             ) ;
  #}
  #*/
  #   // case 4: no proxy (or tricky case: proxy+refresh)
  #if($REMOTE_HOST) {
  #    $array = extractIP($REMOTE_HOST);
  #    if ($array && count($array) >= 1) {
  #        return $array[0]; // first IP in the list
  #    }
  #}
  #return $REMOTE_ADDR;
#}



1;



