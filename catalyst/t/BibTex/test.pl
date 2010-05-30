#!../../perl5/linux64/bin/perl -w
#!../../perl5/linux32/bin/perl -w

BEGIN {
  $ENV{CATALYST_DEBUG} = 0;
}

use strict;
use Data::Dumper;
use lib '../../lib';
use Paperpile;
use Paperpile::Formats::Bibtex;
use IO::File;
use BibTeX::Parser;

my $file = 'test.bib';

my $module = Paperpile::Formats->guess_format( $file );

my $f = $module->new( file => $file );

my $data = $f->read();

$f->data($data);

#foreach my $pub (@$data){
  #print STDERR $pub->sha1, "\n";
#}

$f->write();

