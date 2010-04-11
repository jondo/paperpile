#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -w

BEGIN {
  $ENV{CATALYST_DEBUG} = 0;
}

use strict;
use Data::Dumper;
use lib '../../lib';
use Paperpile;

my $model = Paperpile::Model::Library->new();
$model->set_dsn( "dbi:SQLite:" . "/home/wash/.paperdev/paperpile.ppl" );

$model->dbh->sqlite_create_function( 'now', 1, sub { 
                                       return $_[0];
                                     } );

#my $results = $model->fulltext_search('test',0,10);

my $sth = $model->dbh->prepare("SELECT now(matchinfo(Fulltext_citation)) as time, title  FROM Fulltext_citation WHERE Fulltext_citation MATCH 'washietl OR stefan';");

$sth->execute;

while ( my $row = $sth->fetchrow_hashref() ) {

  my $blob = $row->{time};

  my @list = unpack ('VV',$row->{time});

  print $list[0], " ", $list[1], "\n";

  print $row->{title}, " ",  $row->{time}, "\n";

}
#print Dumper($results);


#sub fulltext_search {
#  ( my $self, my $_query, my $offset, my $limit, my $order, my $search_pdf, my $trash ) = @_;


