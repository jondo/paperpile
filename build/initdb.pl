#!/usr/bin/perl -w

use lib "../catalyst/lib";
use Paperpile::Model::App;

chdir '../catalyst/db';

print STDERR "Initializing app.db...\n";
unlink 'app.db';
my @out = `sqlite3 app.db < app.sql`;
print @out;

print STDERR "Initializing user.db...\n";
unlink 'user.db';
@out = `sqlite3 user.db < user.sql`;
print @out;


print STDERR "Importing journal list into app.db...\n";

open( JOURNALS, "<../data/journals.list" );
my $model = Paperpile::Model::App->new();
$model->set_dsn( "dbi:SQLite:" . "../db/app.db" );

$model->dbh->begin_work();

foreach my $line (<JOURNALS>) {

  $line =~ s/;.*$//;

  next if $line =~ /^$/;
  next if $line =~ /^\s*#/;

  ( my $short, my $long ) = split( /=/, $line );

  $short = $model->dbh->quote($short);
  $long  = $model->dbh->quote($long);

  $model->dbh->do("INSERT OR IGNORE INTO Journals (short, long) VALUES ($short, $long);");
}

$model->dbh->commit();

