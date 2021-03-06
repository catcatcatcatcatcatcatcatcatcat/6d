#!/usr/bin/perl

use strict;

use warnings;

######################
# Mac dev env change (uncomment on Mac dev env):
#  - have to set the full path here - not gooooood :(
#$ENV{DOCUMENT_ROOT} = '/Users/russellp/dev/6d/htdocs/';
#use lib "/Users/russellp/dev/6d/lib/";
######################

$ENV{MOD_PERL} or die "not running under mod_perl!";

use CGI (qw(-oldstyle_urls -private_tempfiles -debug));
CGI->compile(qw(url self_url param Vars cookie header upload));


######################
# Mac dev env change:
#  - Comment out the two lines below on Mac dev env.
#    For some reason this is stopping the server from starting on the Mac
#    Somehow, it stops the ImageMagick module from starting!
use Apache::DBI (); # Apache::DBI preloads DBI as well
DBI->install_driver("mysql");
######################

use CarpeDiem;
use Constants;
use Email;
use ImagePwd;

use conf::db_conf;
use conf::mail_conf;
##### This all doesn't work! :)  Or does it now?
use rusty;
use rusty::Admin;
use rusty::Profiles;
use rusty::Profiles;
use rusty::Profiles::FriendsAndBlocks;
use rusty::Profiles::Message;
use rusty::Profiles::Photo;
use rusty::Profiles::Search;
##################

#
## This doesn't seem to make a difference!
##require conf::db_conf;
##my $_DSN = "DBI:" . $conf::db_conf::DBDRIVER
##. ":database=" . $conf::db_conf::DATABASE
##. ";host=" . $conf::db_conf::DBHOST
##. ";port=" . $conf::db_conf::DBPORT;
##Apache::DBI->setPingTimeOut($_DSN, 300);
#Apache::DBI->connect_on_init
#  ("DBI:mysql:database=test;host=localhost",
#   "user", "password", {
#                        PrintError => 1, # warn( ) on errors
#                        RaiseError => 0, # don't die on error
#                        AutoCommit => 1, # commit executes immediately
#                       }
#  );


use Template ();

use File::Spec ();

use Benchmark::Timer ();
 
use URI ();
use URI::Escape ();
use URI::QueryParam ();

use Image::Magick ();

use Mail::Sendmail ();
use MIME::QuotedPrint ();
use HTML::FromText ();

use Data::Validate::URI ();
use Data::Validate::Email ();

use Time::DaysInMonth ();

if ($ENV{NO_ENTROPY}) {
  eval {
    require Math::Random::MT::Auto;
    import Math::Random::MT::Auto qw( rand srand ), '/dev/urandom';
  }
}

# This modules allows compilation of scripts, running under packages derived from ModPerl::RegistryCooker, 
# at server startup. The script's handler routine is compiled by the parent server, 
# of which children get a copy and thus saves some memory by initially sharing the compiled copy with the parent 
# and saving the overhead of script's compilation on the first request in every httpd instance.
# However, all .pl scripts will be reloaded when changed on disk and as such the shared copy will be useless!
{
    # test the scripts pre-loading by using trans sub
    use ModPerl::RegistryLoader ();
    use File::Spec ();
    use DirHandle ();
    
    
    # DOCUMENT_ROOT must be set in apache config manually using
    # PerlSetEnv DOCUMENT_ROOT path.. (DocumentRoot isn't set yet)..
    my $dir = $1 if $ENV{DOCUMENT_ROOT} =~ /^(.+)$/o;
    
    
    sub trans {
      my $uri = shift;
      #$uri =~ s|^/|/htdocs/|;
      return File::Spec->catfile($dir, $uri);
    }
    
    my $rl = ModPerl::RegistryLoader->new(
            package => "ModPerl::Registry",
            trans   => \&trans,
            #debug   => 1,
            );
    my $dh = DirHandle->new($dir) or die $!;
    
    for my $file ($dh->read) {
      next unless $file =~ /^(.+\.pl)$/;
      $rl->handler("$1");
    }
}



use Apache2::RequestRec ();
use Apache2::Connection ();
use Apache2::Const qw(OK);

sub My::ProxyRemoteAddr ($) {
  my $r = shift;
  my $c = $r->connection;
  
  # we'll only look at the X-Forwarded-For header if the requests
  # comes from our proxy at localhost and if it sent a forwarded IP
  if ($c->remote_ip eq "127.0.0.1") {
    if ($r->headers_in->{'X-Forwarded-For'}) {
      if (my ($ip) = $r->headers_in->{'X-Forwarded-For'} =~ /([^,\s]+)$/o) {
        $c->remote_ip($ip);
      }
    }
  }

  return OK;
}


1;
