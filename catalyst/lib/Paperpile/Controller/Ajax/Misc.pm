package Paperpile::Controller::Ajax::Misc;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Utils;
use Data::Dumper;
use File::Spec;
use File::Path;
use File::Copy;
use Paperpile::Exceptions;
use 5.010;

sub reset_db : Local {

  my ( $self, $c ) = @_;

  $c->model('Library')->init_db( $c->config->{pub_fields}, $c->config->{user_settings} );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub tag_list : Local {

  my ( $self, $c ) = @_;

  my $tags=$c->model('Library')->get_tags;

  my @data=();

  foreach my $row (@$tags){
    push @data, {tag  =>$row->{tag},
                 style=> $row->{style},
                };
  }

  my %metaData = (
   root          => 'data',
   fields        => ['tag', 'style'],
  );

  $c->stash->{data}          = [@data];

  $c->stash->{metaData}      = {%metaData};

  $c->forward('Paperpile::View::JSON');

}

sub journal_list : Local {

  my ( $self, $c ) = @_;
  my $query = $c->request->params->{query};

  my $model = $c->model('App');

  $query = $model->dbh->quote("$query*");

  my $sth = $model->dbh->prepare(
    "SELECT Journals.short, Journals.long FROM Journals 
     JOIN Journals_lookup ON Journals.rowid=Journals_lookup.rowid 
     WHERE Journals_lookup MATCH $query
     ORDER BY Journals.short LIMIT 100;"
  );

  my ( $short, $long );
  $sth->bind_columns( \$short, \$long );
  $sth->execute;

  my @data = ();
  while ( $sth->fetch ) {
    push @data, { long => $long, short => $short };
  }

  $c->stash->{data} = [@data];
  $c->forward('Paperpile::View::JSON');

}

sub get_settings : Local {

  my ( $self, $c ) = @_;

  my $tags=$c->model('Library')->get_tags;

  my $user_settings=$c->model('Library')->settings;
  my $app_settings=$c->model('App')->settings;

  my @list1=%{$c->model('App')->settings};
  my @list2=%{$c->model('User')->settings};
  my @list3=%{$c->model('Library')->settings};

  my %merged=(@list1,@list2, @list3);

  $merged{pub_types}=$c->config->{pub_types};

  $c->stash->{data}  = {%merged};

  $c->forward('Paperpile::View::JSON');

}



sub import_journals : Local {
  my ( $self, $c ) = @_;

  my $file="/home/wash/play/Paperpile/data/jabref.txt";

  my $sth=$c->model('Library')->dbh->prepare("INSERT INTO Journals (key,name) VALUES(?,?)");

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
  $c->forward('Paperpile::View::JSON');

}



1;
