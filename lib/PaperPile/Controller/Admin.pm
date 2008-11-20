package PaperPile::Controller::Admin;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;

=head1 NAME

PaperPile::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  $c->response->body('Matched PaperPile::Controller::Admin in Admin.');
}

# Parse JabRef abbreviation files

sub import_journals :Path {
  my ( $self, $c ) = @_;

  if ($c->request->uploads->{userfile}){
    open(TMP,"<". $c->request->uploads->{userfile}->tempname) || die($!);
    my %data=();

    while (<TMP>){
      next if /^\s*\#/;
      (my $long, my $short)=split /=/, $_;
      $short=~s/;.*$//;
      $short=~s/[.,-]/ /g;
      $short=~s/(^\s+|\s+$)//g;
      $long=~s/(^\s+|\s+$)//g;
      $short=~s/\s+/_/g;

      $short=~s/_\)/\)/g;

      $c->model('DB::Journal')->find_or_create({id=>$short,name=>$long,abbrv=>$short});

      $data{$short}=$long;
    }

    $c->stash->{data}={%data};

  }

  $c->stash->{template} = 'admin/import_journals.mas';

}



=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
