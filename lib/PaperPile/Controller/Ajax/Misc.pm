package PaperPile::Controller::Ajax::Misc;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Library::Publication;
use PaperPile::Library::Source::File;
use PaperPile::Library::Source::DB;
use PaperPile::Library::Source::PubMed;
use PaperPile::PDFviewer;
use Data::Dumper;
use 5.010;


sub reset_db : Local {

  my ( $self, $c ) = @_;

  $c->model('DBI')->reset_db;
  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}

sub init_db : Local {

  my ( $self, $c ) = @_;

  $c->model('DBI')->init_db($c->config->{fields});
  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}


sub import_journals : Local {
  my ( $self, $c ) = @_;

  my $file="/home/wash/play/PaperPile/data/jabref.txt";

  my $sth=$c->model('DBI')->dbh->prepare("INSERT INTO Journals (key,name) VALUES(?,?)");

  open( TMP, "<$file" );

  my %alreadySeen = ();

  while (<TMP>) {
    next if /^\s*\#/;
    ( my $long, my $short ) = split /=/, $_;
    $short =~ s/;.*$//;
    $short =~ s/[.,-]/ /g;
    $short =~ s/(^\s+|\s+$)//g;
    $long  =~ s/(^\s+|\s+$)//g;

    if ( not $alreadySeen{$short} ) {
      $alreadySeen{$short} = 1;
      next;
    }

    $sth->execute($short,$long);

  }

  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}

sub reset_session : Local {

  my ( $self, $c ) = @_;

  foreach my $key ( keys %{ $c->session } ) {
    delete( $c->session->{$key} ) if $key =~ /^(source|viewer|tree)/;
  }

  $c->forward('PaperPile::View::JSON');

}

1;
