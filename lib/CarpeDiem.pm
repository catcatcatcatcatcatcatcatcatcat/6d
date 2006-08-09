package CarpeDiem;
require 5.000;
use Exporter;
#use Carp;
BEGIN {
  require Carp;
  *CORE::GLOBAL::die = \&CarpeDiem::die;
}

require File::Spec;

our @ISA = qw( Exporter );
our @EXPORT = qw( croak carp die warn );
our @EXPORT_OK = qw( carpout fatalsToBrowser set_progname );

$main::SIG{__WARN__}=\&CarpeDiem::warn;
#$main::SIG{__DIE__} = \&CarpeDiem::die;


#use vars qw( $CUSTOM_MSG );

#my $CUSTOM_MSG;

#$CarpeDiem::VERSION    = '1.27';
#$CarpeDiem::CUSTOM_MSG = undef;

##$CUSTOM_MSG = undef;

# fancy import routine detects and handles 'errorWrap' specially.
sub import {
    my $pkg = shift;
    my(%routines);
    my(@name);

    if (@name=grep(/^name=/,@_))
      {
        my($n) = (split(/=/,$name[0]))[1];
        set_progname($n);
        @_=grep(!/^name=/,@_);
      }

    grep($routines{$_}++,@_,@EXPORT);
    $WRAP++ if $routines{'fatalsToBrowser'};
    my($oldlevel) = $Exporter::ExportLevel;
    $Exporter::ExportLevel = 1;
    Exporter::import($pkg,keys %routines);
    $Exporter::ExportLevel = $oldlevel;
    $main::SIG{__DIE__} =\&CarpeDiem::die if $routines{'fatalsToBrowser'};

    #$pkg->export('CORE::GLOBAL','die');
    #Exporter::import($pkg,@_);
}

# These are the originals
sub realwarn { CORE::warn(@_); }
sub realdie { CORE::die(@_); }

sub id {
    my $level = shift;
    my($pack,$file,$line,$sub) = caller($level);
    my($dev,$dirs,$id) = File::Spec->splitpath($file);
    return ($file,$line,$id);
}

sub stamp {
    my $type = shift || "MISC";
    #my $line = shift || 0;
    #$line = sprintf("%04i", $line);
    my $time = scalar(localtime);
    #my $frame = 0;
    #if (defined($CarpeDiem::PROGNAME)) {
    #  $id = $CarpeDiem::PROGNAME;
    #} else {
    #    do {
    #  $id = $file;
    #  ($pack,$file) = caller($frame++);
    #    } until !$file;
    #}
    
    #get script name..
    #my $id = (File::Spec->splitpath($0))[2];
    
    my ($caller,$line) = id(2);
    # Get one level lower than the doc root..
    my $codebase;
    ($codebase = $ENV{DOCUMENT_ROOT}) =~ s/[^\\\/]+[\\\/]?$//o unless $codebase;
    $caller =~ s/^$codebase//o;
    $line = sprintf("%04i", $line);
    return "[$time] $type \@ $line \@ $caller:\t";
}


sub stomp {
  #(my $query_string = $ENV{QUERY_STRING}) =~ s/;/&/g;
  #return ' while ' . $ENV{REQUEST_METHOD} . ' request for ' .
  #       $ENV{SCRIPT_URL} . '?' . $query_string;
  
  #require CGI;
  #(my $uri = CGI->self_url( -oldstyle_urls )) =~ s/;/&/g;
  #return ' while ' . $ENV{REQUEST_METHOD} . " request for $uri"
  return ' while ' . $ENV{REQUEST_METHOD} .
         ' request of ' . $ENV{REQUEST_URI};
  
}


sub warn {
    my $message = shift;
    # Fixes mod_perl problem
    if ($message =~ /Subroutine [\w:]+ redefined/oi) {
      #print STDERR "---\ntrying to catch the sub redefined thing!\n---";
      $message = "";
      return -1;
    }
    #$message =~ s/at \Q$0\E.+$//o;
    my $stamp = stamp("WARN");
    $message =~ s/^/$stamp/mg;
    my $stomp = stomp();
    $message =~ s/\n?$/$stomp/mg;
    if ($message !~ /\n$/o) {
      $message .= "\n"; # make sure we finish with a newline!
    }
    realwarn $message; # unless $message=~/~ko-3\.0\.0-perllint~/o;
}

# The mod_perl package Apache::Registry loads CGI programs by calling
# eval, as does PerlEx.  These evals don't count when looking at the
# stack backtrace.
sub _longmess {
    my $message = Carp::longmess();
    my $mod_perl = exists $ENV{MOD_PERL};
    my $plex = exists($ENV{'GATEWAY_INTERFACE'})
               && $ENV{'GATEWAY_INTERFACE'} =~ /^CGI-PerlEx/o;
    $message =~ s,eval[^\n]+((ModPerl|Apache)/Registry\w*\.pm|\s*PerlEx::Precompiler).*,,os
      if $mod_perl or $plex;
    return $message;
}

sub ineval {
  #(exists $ENV{MOD_PERL} ? 0 : $^S) || _longmess() =~ /eval [\{\']/om
  _longmess() =~ /eval [\{\']/om
}

sub die {
  my ($arg) = @_;
  realdie @_ if ineval();
  if (!ref($arg)) {
    $arg = join("", @_);
    my($file,$line,$id) = id(1);
    $arg =~ s/at \Q$0\E.+$//o;
    #$arg .= " at $file line $line." unless $arg=~/\n$/o;
    &fatalsToBrowser($arg) if $WRAP;
    #if (($arg =~ /\n$/o) || !exists($ENV{MOD_PERL})) {
    my $stamp = stamp("DIE ");
    $arg =~ s/^/$stamp/gm;
    my $stomp = stomp();
    $arg =~ s/\n?$/$stomp/mg;
    #}
    if ($arg !~ /\n$/) {
      $arg .= "\n";
    }
  }
  # Email someone who cares about this terrible death!
  #use Email qw( send_email validate_email );
  my $textmessage = $arg;
  require Email;
  #Email::send_email( To => [ 'Admin <r.preston@myrealbox.com>', ],
  #                   Subject => 'Death in the family',
  #                   TextMessage => $textmessage,
  #                   #HtmlMessage => $htmlmessage
  #                 );
  #realdie $arg;
  print STDERR $arg;
  exit;
}

sub set_progname {
    $CarpeDiem::PROGNAME = shift;
    return $CarpeDiem::PROGNAME;
}

#sub set_message {
#    $CarpeDiem::CUSTOM_MSG = shift;
#    return $CarpeDiem::CUSTOM_MSG;
    #$CUSTOM_MSG = shift;
    #return $CUSTOM_MSG;
#}

sub croak   { CarpeDiem::die Carp::shortmess @_; }
sub carp    { CarpeDiem::warn Carp::shortmess @_; }

# We have to be ready to accept a filehandle as a reference
# or a string.
sub carpout {
    my($in) = @_;
    my($no) = fileno(to_filehandle($in));
    realdie("Invalid filehandle $in\n") unless defined $no;

    open(SAVEERR, ">&STDERR");
    open(STDERR, ">&$no") or
  ( print SAVEERR "Unable to redirect STDERR: $!\n" and exit(1) );
}



# it seems that internal die and warns now work fine
# also, errors within the code that aren't picked
# up on in compile time are taken to the mod_perl
# bit but do not seem to write anything to the screen
# (in these cases, there are things already on the screen)

# reloading this module on other's change means that everything fucks up
# this was not meant to be reloaded - it loses the custom error and
# loads of other stuff..

# headers
sub fatalsToBrowser {
  my($msg) = @_;
  $msg=~s/&/&amp;/og;
  $msg=~s/>/&gt;/og;
  $msg=~s/</&lt;/og;
  $msg=~s/\"/&quot;/og;
  my($wm) = $ENV{SERVER_ADMIN} ?
    qq[the webmaster (<a href="mailto:$ENV{SERVER_ADMIN}">$ENV{SERVER_ADMIN}</a>)] :
      "this site's webmaster";
  my ($outer_message) = <<END;
For help, please send mail to $wm, giving this error message
and the time and date of the error.
END
  ;
  my $mod_perl = exists $ENV{MOD_PERL};
  my $plex = exists($ENV{'GATEWAY_INTERFACE'})
  && $ENV{'GATEWAY_INTERFACE'} =~ /^CGI-PerlEx/o;

  # Hide dangerous info from being written out;
  # Remove where the error occured ["at /a/b/X.pl line Y"]

  $msg =~ s/at \Q$0\E.+$//o;

  # Do not display parts of the code -
  # these will be in the error log anyway.

  if ($msg =~ /^syntax error/o) {

    # REMOVE THE LAST LINE OF THIS STRING ($msg) BEFORE RELEASE!!

    $msg = "Syntax error! i.e. someone typed a boo boo.. <br />"
         . "Try again in a minute when it should be fixed. "
         . "<br />\n$msg\n";

  }

  $message = <<ERROR;
<html>
<head><title>Uuuuuh oooooh.. :(</title></head>
  <body>
    <h2 style="color:navy">Ooh crikey - an error! =O</h2>
    <p><b>$msg</b></p>
    <p style="color:red"><i>
    This error has been logged and somebody has been notified.
    </i></p>
  </body>
</html>
ERROR
  ;
  # email death error to me here?

  print STDOUT $message;
  #print STDOUT "Content-type: text/html\n\n", $message;


#  if ($CUSTOM_MSG) {
#    print STDERR "Doing custom message";
#    #if (ref($CUSTOM_MSG) eq 'CODE') {
#      print STDOUT "Content-type: text/html\n\n"
#        unless $mod_perl || $plex;
#      &$CUSTOM_MSG($msg); # nicer to perl 5.003 users
#      return;
#    } else {
#      $outer_message = $CUSTOM_MSG;
#    }
#  }
#
#  my $mess = <<END;
#<html>
#<head><title>Uuuuuh oooooh.. :(</title></head>
#  <body>
#    <h2 style="color:navy">Ooh crikey - an eeerror! =O</h2>
#    <p><b>$msg</b></p>
#    <p style="color:red"><i>
#    This error has been logged and somebody has been notified.
#    </i></p>
#  </body>
#</html>
#END
#  ;
#
#  if ($mod_perl) {
#    print STDERR "mod perl!!!\n";
#    require mod_perl;
#    if ($mod_perl::VERSION >= 1.99) {
#      print STDERR "version2!!!\n";
#      $mod_perl = 2;
#      require Apache::RequestRec;
#      require Apache::RequestIO;
#      require Apache::RequestUtil;
#      require APR::Pool;
#      require ModPerl::Util;
#      require Apache::Response;
#    }
#    my $r = Apache->request;
#    # If bytes have already been sent, then
#    # we print the message out directly.
#    # Otherwise we make a custom error
#    # handler to produce the doc for us.
#    if ($r->bytes_sent) {
#      print STDERR $r->bytes_sent." bytes sent!!!\n";
#      $r->print($mess);
#      $mod_perl == 2 ? ModPerl::Util::exit(0) : $r->exit;
#    } else {
#      print STDERR $r->bytes_sent." bytes sent!!!\n";
#      # MSIE won't display a custom 500 response unless it is >512 bytes!
#      if ($ENV{HTTP_USER_AGENT} =~ /MSIE/o) {
#        $mess = "<!-- " . (' ' x 513) . " -->\n$mess";
#      }
#      #$r->print($mess); #added by rusty
#      $r->custom_response(500,$mess);
#    }
#  } else {
#    print STDERR "not mod perl now..\n";
#    my $bytes_written = eval{tell STDOUT};
#    if (defined $bytes_written && $bytes_written > 0) {
#        print STDERR "$bytes_written written\n";
#        print STDOUT $mess;
#    }
#    else {
#        print STDERR "$bytes_written written\n";
#        print STDOUT "Content-type: text/html\n\n";
#        print STDOUT $mess;
#    }
#  }

}



# Cut and paste from CGI.pm so that we don't have the overhead of
# always loading the entire CGI module.
sub to_filehandle {
    my $thingy = shift;
    return undef unless $thingy;
    return $thingy if UNIVERSAL::isa($thingy,'GLOB');
    return $thingy if UNIVERSAL::isa($thingy,'FileHandle');
    if (!ref($thingy)) {
  my $caller = 1;
  while (my $package = caller($caller++)) {
      my($tmp) = $thingy=~/[\':]/ ? $thingy : "$package\:\:$thingy";
      return $tmp if defined(fileno($tmp));
  }
    }
    return undef;
}

1;
