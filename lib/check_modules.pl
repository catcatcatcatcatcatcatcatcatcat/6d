#!/usr/bin/perl

use strict;

my @packages = qw(

CGI
Apache::DBI
DBI
DBD::mysql
Template

File::Spec

Benchmark::Timer

URI
URI::Escape
URI::QueryParam

Image::Magick

Mail::Sendmail
MIME::QuotedPrint
HTML::FromText

Data::Validate::URI
Data::Validate::Email

Time::DaysInMonth

Math::Random::MT::Auto

);

foreach (@packages) {
  our $VERSION;
  if (eval "require $_"){
    warn "$_: found version " . (eval '$' . $_ . '::VERSION') . "\n";
  } else {
    warn "$_: NOT FOUND\n";
    0;
    my $prompt = <>;
  }
}

1;
