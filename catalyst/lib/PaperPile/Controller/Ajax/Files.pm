package PaperPile::Controller::Ajax::Files;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use File::Spec;
use 5.010;

sub get : Local {
  my ( $self, $c ) = @_;

  my $path=$c->request->params->{path};
  my $root = File::Spec->rootdir();

  $path=~s/^root/$root/;

  opendir(DIR, File::Spec->catdir($root,$path)) || die "can't open $path ($!)";
  my @contents = readdir(DIR);
  closedir DIR;

  my @output=();

  foreach my $item (@contents){

    print STDERR "=======> $root $item\n";

    next if $item eq '.';
    next if $item eq '..';


    if (-d File::Spec->catdir($path,$item)){
      push @output, {text=>$item,
                     iconCls=>"folder",
                     disabled=>0,
                     leaf=>0};
    }
  }

  $c->stash->{tree} = [@output];

  $c->forward('PaperPile::View::JSON::Tree');

}


1;
