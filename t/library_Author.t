#!/usr/bin/perl -w

use lib "../lib";
use PaperPile::Library::Author;
use Test::More 'no_plan';

BEGIN { use_ok 'PaperPile::Library::Author' }

my $author = PaperPile::Library::Author->new;


my %tests = ( 'bb CC, AA' => { first => 'AA', von => 'bb', last => 'CC', jr=>''},
              'bb CC, aa' => { first => 'aa', von => 'bb', last => 'CC', jr=>''},
              'bb CC dd EE, AA' => { first => 'AA', von => 'bb CC dd', last => 'EE', jr=>''},
              'bb, AA' => { first => 'AA', von => '', last => 'bb', jr=>''},
              'BB,' => { first => '', von=>'', last => 'BB', jr=>''},
              'bb CC,XX, AA' => { first => 'AA', von => 'bb', last => 'CC', jr=>'XX'},
              'BB,, AA' => { first => 'AA', von => '', last => 'BB', jr=>''});

foreach my $key (keys %tests){

  my $automatic=PaperPile::Library::Author->new;

  $automatic->full($key);


  my $manual=PaperPile::Library::Author->new($tests{$key});

  $automatic->full('');
  $manual->full('');

  is_deeply($automatic, $manual, "Parsing pattern '$key'");
}


my %initials = (
  ''                  => '',
  'Peter'             => 'P',
  'P'                 => 'P',
  'P.'                => 'P',
  ' Peter '           => 'P',
  'Peter Florian'     => 'PF',
  'Peter F.'          => 'PF',
  'Peter F'           => 'PF',
  'P.F.'              => 'PF',
  'P. F.'             => 'PF',
  '  P.F.  '          => 'PF',
  'P. Florian'        => 'PF',
  'P.Florian'         => 'PF',
  'Peter Florian Max' => 'PFM',
  'P F M'             => 'PFM',
  'P. F. M.'          => 'PFM',
  'P.F.M.'            => 'PFM',
  'Peter FM'          => 'PFM'
);

$author = PaperPile::Library::Author->new;

foreach my $input ( keys %initials ) {
  $author->first($input);
  is( $author->parse_initials(),
    $initials{$input}, "parse_initials() for $input" );
}

$author = PaperPile::Library::Author->new(full=>'Stadler, P.F.');

is( $author->create_key, "STADLER_PF", "Automatically create key" );

is( $author->nice, "Stadler PF", "nice printing" );

is ($author->normalized, "Stadler, PF", "normalized");

