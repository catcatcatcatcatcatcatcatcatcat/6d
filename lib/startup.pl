#!/usr/bin/perl

use strict;

use CGI (qw(-oldstyle_urls -private_tempfiles -debug));
CGI->compile(qw(url self_url param Vars cookie header upload));

use Apache::DBI (); # Apache::DBI preloads DBI as well
DBI->install_driver("mysql");

if (-d 'C:/website/6d/lib') {
  use lib qw(C:/website/6d/lib); #home
} elsif (-d 'E:/web/website/6d/lib') {
  use lib qw(E:/web/website/6d/lib); #work
}
# This doesn't seem to make a difference!
#require conf::db_conf;
#my $_DSN = "DBI:" . $conf::db_conf::DBDRIVER
#. ":database=" . $conf::db_conf::DATABASE
#. ";host=" . $conf::db_conf::DBHOST
#. ";port=" . $conf::db_conf::DBPORT;
#Apache::DBI->setPingTimeOut($_DSN, 300);

# Just in dev, to speed up apache time to restart, we're
# taking these out!  Put them back in production.
#use CarpeDiem;
#use Email;
#use ImagePwd;
#use conf::db_conf;
#use conf::mail_conf;
##use rusty; # This doesn't work! :)
##use rusty::Profiles; # Just won't work. :(

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


# This modules allows compilation of scripts, running under packages derived from ModPerl::RegistryCooker, 
# at server startup. The script's handler routine is compiled by the parent server, 
# of which children get a copy and thus saves some memory by initially sharing the compiled copy with the parent 
# and saving the overhead of script's compilation on the first request in every httpd instance.
#  {
#      # test the scripts pre-loading by using trans sub
#      use ModPerl::RegistryLoader ();
#      use File::Spec ();
#      use DirHandle ();
#      use strict;
#  
#      my $dir = File::Spec->catdir(Apache2::ServerUtil::server_root,
#                                  "cgi-bin");
#  
#      sub trans {
#          my $uri = shift; 
#          $uri =~ s|^/registry/|cgi-bin/|;
#          return File::Spec->catfile(Apache2::ServerUtil::server_root,
#                                     $uri);
#      }
#  
#      my $rl = ModPerl::RegistryLoader->new(
#          package => "ModPerl::Registry",
#          trans   => \&trans,
#      );
#      my $dh = DirHandle->new($dir) or die $!;
#  
#      for my $file ($dh->read) {
#          next unless $file =~ /\.pl$/;
#          $rl->handler("/registry/$file");
#      }
#  }
#
# Not bothering with this because all .pl scripts will be reloaded when changed on disk
# and as such the shared copy will be useless!  Unless we restart the server each time
# we change scripts..  Oh it's only cheap memory! Leave it until a problem presents itself!


1;
