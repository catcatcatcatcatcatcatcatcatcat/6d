#!/usr/bin/perl -T

use strict;

use lib '../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use CarpeDiem;

use ImagePwd;

use rusty;

# Connect to db

my $dbh = rusty->DBH;

# Declare subroutines

sub show_error_image();

# Set autoflush and binary output for images

#$| = 1;

binmode STDOUT;




# Grab the passphrase_id from the query string

my $passphrase_id = $ENV{'QUERY_STRING'};
if ($passphrase_id eq "") {
  warn "no passphrase id specified";
  print "Content-type: image/jpeg\n\n";
  show_error_image();
}

my $query = <<ENDSQL
SELECT passphrase
FROM `signup~passphrase`
WHERE passphrase_id = ?
ENDSQL
;
my $sth = $dbh->prepare_cached($query);
$sth->execute($passphrase_id);
my $passphrase = $sth->fetchrow_array();
$sth->finish;

if (!$passphrase) {
  warn "passphrase expired for passphrase id '$passphrase_id'";
  print "Content-type: image/jpeg\n\n";
  show_error_image();
} elsif ($passphrase eq "") {
  warn "empty passphrase!";
  print "Content-type: image/jpeg\n\n";
  show_error_image();
} #else {
  # TEST ONLY DUE TO IMAGEMAGICK NOT WORKING AT WORK!!
#  print "Content-type: image/jpeg\n\n";
#  show_error_image();
#}

my $obj = ImagePwd->new(len=>length($passphrase),
                        height=>100,
                        width=>600,
                        f_min=>40,
                        f_max=>50,
                        fixed=>0,
                        rot=>15,
                        quality=>128,
                        password=>$passphrase,
                        cell=>1,
                        );

my $font_dir = $ENV{SYSTEMROOT} . "/FONTS/";

$obj->fonts([$font_dir.'Verdana.TTF',$font_dir.'Arial.TTF',
             $font_dir.'comic.TTF',$font_dir.'georgiab.TTF',
             $font_dir.'micross.TTF',$font_dir.'tahoma.TTF',
             ]);

my $img = $obj->ImagePassword();

$img->Set(quality => 70, magick => "JPG");

print "Content-type: image/jpeg\n\n";

my $image = $img->ImageToBlob();

if ($image) {
  print $image;
} else {
  warn "could not write out image";
  show_error_image();
}




sub show_error_image() {

  my $error_image = "$ENV{DOCUMENT_ROOT}/../images/passphrase-error.jpg";

  if (open IMAGE, $error_image) {

    print <IMAGE>;
    close IMAGE;

  } else {

    die "can't open the error image: $error_image";

  }

  rusty->exit(0);
}
