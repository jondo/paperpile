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

my %data=();

foreach my $line (<JOURNALS>) {

  $line =~ s/;.*$//;

  next if $line =~ /^$/;
  next if $line =~ /^\s*#/;

  ( my $long, my $short ) = split( /\s*=\s*/, $line );

  if ($short and $long){
    chomp($short);
    chomp($long);
    $data{$short}=$long;
  }
}

foreach my $short (keys %data){

  my $long=$data{$short};

  $short = $model->dbh->quote($short);
  $long  = $model->dbh->quote($long);

  $model->dbh->do("INSERT OR IGNORE INTO Journals (short, long) VALUES ($short, $long);");

  my $rowid = $model->dbh->func('last_insert_rowid');
  print STDERR "$rowid $short $long\n";
  $model->dbh->do("INSERT INTO Journals_lookup (rowid,short,long) VALUES ($rowid,$short,$long)");

}


$model->dbh->commit();

