#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -w

BEGIN {
  $ENV{CATALYST_DEBUG} = 0;
}

use strict;
use Data::Dumper;
use lib '../../lib';

#use Paperpile;
#use Paperpile::Model::Library;

my $query = 'author : "washietl s" 2007 text:test hofacker il "term1   term2" ';

print "$query\n";

# Remove trailing/leading whitespace
$query =~ s/^\s+//;
$query =~ s/\s+$//;

# Normalize all whitespace to one blank
$query =~ s/\s+/ /g;

# remove whitespaces around colons
$query =~ s/\s+:\s+/:/g;

# Normalize all quotes to double quotes
$query =~ tr/'/"/;

# Make sure quotes are balanced; if not silently remove all quotes
my ($quote_count) = ( $query =~ tr/"/"/ );
if ( $quote_count % 2 ){
  $query=~s/"//g;
}

# Parse fields respecting quotes
my @chars      = split( //, $query );
my $curr_field = '';
my @fields     = ();
my $in_quotes  = 0;
foreach my $c (@chars) {
  if ( $c eq ' ' and !$in_quotes ) {
    push @fields, $curr_field;
    $curr_field = '';
    next;
  }
  if ( $c eq '"' ) {
    $in_quotes = $in_quotes ? 0 : 1;
    $curr_field .= $c;
    next;
  }
  $curr_field .= $c;
}
push @fields, $curr_field;

my @new_fields = ();

foreach my $field (@fields) {

  # We have a key:value pair. Silently ignore unknown fields
  if ( $field =~ /(.*):(.*)/ ) {

    my $known = 0;

    foreach my $supported (
      'text',  'abstract', 'notes',   'title',  'key',  'author',
      'label', 'labelid',  'keyword', 'folder', 'year', 'journal'
      ) {
      if ( $1 eq $supported ) {
        $known = 1;
        last;
      }
    }
    push @new_fields, $field if ($known);
    next;
  }

  # We have a quoted "query" and use this verbatim
  if ( $field =~ /".*"/ ) {
    push @new_fields, $field;
    next;
  }

  # We interpret one letter or two letters as initials and merge them
  # with the previous term
  if ( $field =~ /^\w{1,2}$/ ) {

    # We ignore it if it is the first term
    if ( scalar @new_fields == 0 ) {
      next;
    }

    my $prev_field = pop @new_fields;
    if (!( ( $prev_field =~ /:/ ) or ( $prev_field =~ /"/ ) )
      or ( $prev_field =~ /author:/ and !( $prev_field =~ /"/ ) ) ) {
      $prev_field =~ s/\*//;
      push @new_fields, '"' . $prev_field . " " . $field . '"';
    }
    next;
  }

  # For all other terms:
  $field .= "*";
  push @new_fields, $field;

}

foreach my $field (@new_fields) {
  print "$field\n";
}

# use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

# print "Opening model... ";

# my $model = Paperpile::Model::Library->new();
# $model->set_dsn( "dbi:SQLite:" . "/home/wash/.paperdev/paperpile.ppl" );

# print "Done.\n";

# my $t0 = [gettimeofday];

# my $page  = $model->fulltext_search( ' a*', 0,  25, undef , 0, 1);

# print "Done\n";

# my $t1 = [gettimeofday];

# my $elapsed = tv_interval ($t0);

# print "$elapsed\n";

# $t0 = [gettimeofday];

# my  $sth = $model->dbh->prepare(
#    qq{
# SELECT *,
#      Publications.rowid as _rowid,
#      Publications.title as title,
#      Publications.abstract as abstract,offsets(Fulltext) as offsets FROM Publications JOIN Fulltext ON Publications.rowid=Fulltext.rowid  WHERE Fulltext MATCH ' r*' AND Publications.trashed=0 ORDER BY author ASC LIMIT 25 OFFSET 0;

#  }
#  );

# $sth->execute;

# $t1 = [gettimeofday];

# $elapsed = tv_interval ($t0);

# print "$elapsed\n";
