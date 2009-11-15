#!/usr/bin/perl -w

use strict;
use lib "../catalyst/lib";
use Paperpile::Model::App;
use Paperpile::Model::Library;
use Paperpile::Model::Queue;
use Data::Dumper;

use YAML qw(LoadFile);

chdir '../catalyst/db';

foreach my $key ( 'app', 'user', 'library','queue' ) {
  print STDERR "Initializing $key.db...\n";
  unlink "$key.db";
  my @out = `sqlite3 $key.db < $key.sql`;
  print @out;
}

my $model = Paperpile::Model::Library->new();
$model->set_dsn( "dbi:SQLite:" . "library.db" );

my $config = LoadFile('../paperpile.yaml');

foreach my $field ( keys %{ $config->{pub_fields} } ) {
  $model->dbh->do("ALTER TABLE Publications ADD COLUMN $field TEXT");
}

# Just for now set some defaults here, will be refactored to set these
# defaults with all other defaults in the Controller
$model->dbh->do("INSERT INTO Tags (tag,style) VALUES ('Important',11);");
$model->dbh->do("INSERT INTO Tags (tag,style) VALUES ('Review',22);");

print STDERR "Importing journal list into app.db...\n";

open( JOURNALS, "<../data/journals.list" );
$model = Paperpile::Model::App->new();
$model->set_dsn( "dbi:SQLite:" . "../db/app.db" );

$model->dbh->begin_work();

my %data = ();

my %seen=();

foreach my $line (<JOURNALS>) {

  next if $line =~ /^$/;
  next if $line =~ /^\s*#/;

  my ( $long, $short, $issn, $essn, $source, $url, $reviewed ) = split( /;/, $line );

  $short    = $model->dbh->quote($short);
  $long     = $model->dbh->quote($long);
  $issn     = $model->dbh->quote($issn);
  $essn     = $model->dbh->quote($essn);
  $source   = $model->dbh->quote($source);
  $url      = $model->dbh->quote($url);
  $reviewed = $model->dbh->quote($reviewed);

  next if $seen{$short};

  $seen{$short}=1;

  $model->dbh->do(
    "INSERT OR IGNORE INTO Journals (short, long, issn, essn, source, url, reviewed) VALUES ($short, $long, $issn, $essn, $source, $url, $reviewed);"
  );

  my $rowid = $model->dbh->func('last_insert_rowid');
  print STDERR "$rowid $short $long\n";
  $model->dbh->do("INSERT INTO Journals_lookup (rowid,short,long) VALUES ($rowid,$short,$long)");

}

$model->dbh->commit();

