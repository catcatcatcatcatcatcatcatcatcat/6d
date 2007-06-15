#!/usr/bin/perl -T

use strict;

use lib '../../lib';

use warnings qw(all);

no warnings qw(uninitialized);

use rusty;

rusty::init();

my $DBH = rusty::db_connect();

my $params = rusty::get_utf8_params();



# First of all, escape all underscores so they are seen as such!
(my $profile_name_sql = $params->{profile_name}) =~ s/_/\\_/og;

# Advanced Searches: where a ? in the search term matches
# a single character (regex style) - so a '_' for the sql 'LIKE'
$profile_name_sql =~ s/\?/\_/og;
# and a * in the search term matches 0, 1 or many characters
# and therefore creates a '%' in the sql 'LIKE' search term.
$profile_name_sql =~ s/\*/\%/og;

# Regex-like 'start of' and 'end of' characters - if specified,
# remove them to create no partial search at the start/end
# otherwise add a '%' to partial match at start/end.
$profile_name_sql = '%' . $profile_name_sql
  unless $profile_name_sql =~ s/^\^//o;
$profile_name_sql .= '%'
  unless $profile_name_sql =~ s/\$$//o;

# If an advanced search type has been selected, then set up the
# search term to behave accordingly (override the stuff above!)
if ($params->{profile_name_search} eq 'start') {
  $profile_name_sql =~ s/^\%//o;
} elsif ($params->{profile_name_search} eq 'end') {
  $profile_name_sql =~ s/\%$//o;
} elsif ($params->{profile_name_search} eq 'full') {
  $profile_name_sql =~ s/\%$//o;
  $profile_name_sql =~ s/^\%//o;
}



my $query = <<ENDSQL
SELECT profile_name
FROM `user~profile`
WHERE profile_name LIKE ?
LIMIT 1
ENDSQL
;
my $sth = $DBH->prepare_cached($query);
$sth->execute($profile_name_sql);
if ($sth->fetchrow_array) {
  print "Status: 200\n\n";
} else {
  print "Status: 404\n\n";
}
$sth->finish;
