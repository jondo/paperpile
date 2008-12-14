#!/usr/bin/perl -w

use lib "../lib";
use PaperPile::Library;
use PaperPile::Library::Author;
use Test::More 'no_plan';

my $author = PaperPile::Library::Author->new;

ok( defined $author, 'New returns object' );

ok( $author->isa('PaperPile::Library::Author'), 'Object is of right class' );

$author = PaperPile::Library::Author->new(
  first_names_raw => 'Peter F.',
  last_name       => 'Stadler',
  suffix          => 'jr.'
);

is( $author->first_names_raw, 'Peter F.', 'first_names_raw()' );
is( $author->last_name,       'Stadler',  'last_name()' );
is( $author->suffix,          'jr.',      'suffix()' );

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
  $author->first_names_raw($input);
  is( $author->parse_initials($input),
    $initials{$input}, "parse_initials() for $input" );
}

$author = PaperPile::Library::Author->new(
  first_names_raw => 'Peter F.',
  initials        => 'PF',
  last_name       => 'Stadler',
  suffix          => 'jr'
);

is( $author->id, "STADLER_JR_PF", "Automatically create id" );

is ($author->flat, "Stadler jr PF", "flat");

$author = PaperPile::Library::Author->new(
  initials        => 'H',
  last_name       => 'von Hugo',
  suffix          => ''
);

is ($author->flat, "von Hugo H", "flat");



