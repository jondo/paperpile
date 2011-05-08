package Test::Paperpile::Library::Publication;

use Test::More;
use Data::Dumper;
use YAML;

use base 'Test::Class';

use utf8;

use Paperpile;

sub class { 'Paperpile::Library::Publication' };

sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

  $self->{journal1} = {
    pubtype  => 'JOUR',
    title    => 'Strategies for measuring evolutionary conservation of RNA secondary structures',
    journal  => 'BMC Bioinformatics',
    authors  => 'Gruber, AR and Bernhart, SH and  Hofacker, I.L. and Washietl, S.',
    volume   => '9',
    pages    => '122',
    year     => '2008',
    month    => 'Feb',
    day      => '26',
    issn     => '1471-2105',
    pmid     => '18302738',
    doi      => '10.1186/1471-2105-9-122',
    url      => 'http://www.biomedcentral.com/1471-2105/9/122',
    abstract => 'BACKGROUND: Evolutionary conservation of RNA secondary structure..',
    notes    => 'These are my notes',
  };

}

sub format_patterns : Tests(45) {

  my ($self) = @_;

  my $pub = Paperpile::Library::Publication->new( $self->{journal1} );

  ## Test basic substitution patterns

  # Firstauthor
  is( $pub->format_pattern('[firstauthor]'),   'gruber', '[firstauthor]' );
  is( $pub->format_pattern('[Firstauthor]'),   'Gruber', '[Firstauthor]' );
  is( $pub->format_pattern('[FIRSTAUTHOR]'),   'GRUBER', '[FIRSTAUTHOR]' );
  is( $pub->format_pattern('[Firstauthor:3]'), 'Gru',    '[Firstauthor:3]' );

  # Lastauthor
  is( $pub->format_pattern('[lastauthor]'),   'washietl', '[lastauthor]' );
  is( $pub->format_pattern('[Lastauthor]'),   'Washietl', '[Lastauthor]' );
  is( $pub->format_pattern('[LASTAUTHOR]'),   'WASHIETL', '[LASTAUTHOR]' );
  is( $pub->format_pattern('[lastauthor:4]'), 'wash',     '[lastauthor:4]' );

  # Authors
  is( $pub->format_pattern('[Authors]'),    'Gruber_Bernhart_Hofacker_Washietl', '[Authors]' );
  is( $pub->format_pattern('[AUTHORS]'),    'GRUBER_BERNHART_HOFACKER_WASHIETL', '[AUTHORS]' );
  is( $pub->format_pattern('[Authors2]'),   'Gruber_Bernhart_et_al',             '[Authors2]' );
  is( $pub->format_pattern('[authors3:4]'), 'grub_bern_hofa_et_al',              '[authors3:4]' );

  # Title
  is( $pub->format_pattern('[Title]'),
    'Strategies_for_measuring_evolutionary_conservation_of_RNA_secondary_structures', '[Title]' );
  is( $pub->format_pattern('[title]'),
    'strategies_for_measuring_evolutionary_conservation_of_rna_secondary_structures', '[title]' );
  is( $pub->format_pattern('[TITLE]'),
    'STRATEGIES_FOR_MEASURING_EVOLUTIONARY_CONSERVATION_OF_RNA_SECONDARY_STRUCTURES', '[TITLE]' );
  is( $pub->format_pattern('[Title3]'), 'Strategies_for_measuring', '[Title3]' );
  is( $pub->format_pattern('[Title3:3]'), 'Str_for_mea', '[Title3:3]' );

  # Year
  is( $pub->format_pattern('[YY]'),   '08',   '[YY]' );
  is( $pub->format_pattern('[YYYY]'), '2008', '[YYYY]' );

  # Journal
  is( $pub->format_pattern('[Journal]'), 'BMC_Bioinformatics', '[Journal]' );
  is( $pub->format_pattern('[JOURNAL]'), 'BMC_BIOINFORMATICS', '[JOURNAL]' );
  is( $pub->format_pattern('[journal]'), 'bmc_bioinformatics', '[journal]' );

  # Key substitution
  is( $pub->format_pattern( '[key]', { key => 'Test' } ), 'Test', 'Custom substitution [key]' );

  ## Missing data
  $pub = Paperpile::Library::Publication->new();

  is( $pub->format_pattern('[firstauthor]'), 'unnamed', 'no firstauthor -> unnamed' );
  is( $pub->format_pattern('[authors]'),     'unnamed', 'no author -> unnamed' );
  is( $pub->format_pattern('[YY]'),          'undated', 'no YY -> undated' );
  is( $pub->format_pattern('[title]'),       '',        'no title -> empty' );
  is( $pub->format_pattern('[journal]'),     '',        'no journal -> empty' );
  is( $pub->format_pattern('[firstauthor][YY]'), 'incomplete_reference', 'incomplete_reference' );

  $pub = Paperpile::Library::Publication->new( year => 2000 );
  is( $pub->format_pattern('[firstauthor]_[YYYY]'), 'unnamed_2000', 'unnamed_2000' );

  $pub = Paperpile::Library::Publication->new( authors => "Doe, J" );
  is( $pub->format_pattern('[firstauthor]_[YYYY]'), 'doe_undated', 'doe_undated' );

  $pub = Paperpile::Library::Publication->new( title => "Some title" );
  is( $pub->format_pattern('[firstauthor][YY][title]'), 'some_title', 'incomplete with title' );

  ## Special characters
  $pub = Paperpile::Library::Publication->new(
    title   => 'Title \ with / slashes',
    year    => '2\0/00',
    authors => 'D\o/e, J',
    journal => 'Journal with \ slashes /'
  );

  is(
    $pub->format_pattern('[Firstauthor]_[YYYY]_[Title]_[Journal]'),
    'Doe_undated_Title_with_slashes_Journal_with_slashes',
    'Remove slashes'
  );
  is(
    $pub->format_pattern('[Firstauthor]/[YYYY]/[Title]/[Journal]'),
    'Doe/undated/Title_with_slashes/Journal_with_slashes',
    'Remove slashes - keep slashes from pattern'
  );

  $pub = Paperpile::Library::Publication->new( title => 'Title with unicode Ü', );

  is( $pub->format_pattern('[Title]'), 'Title_with_unicode_U', 'convert unicode characters' );

  ## Misc

  $pub = Paperpile::Library::Publication->new( editors => 'Doe, J and Mustermann, M', );

  is( $pub->format_pattern('[Firstauthor]'), 'Doe',        '[Firstauthor] from editors' );
  is( $pub->format_pattern('[Lastauthor]'),  'Mustermann', '[Lastauthor] from editors' );

  $pub->authors("Smith, J");
  is( $pub->format_pattern('[Firstauthor]'),
    'Smith', '[Firstauthor] from authors when editors are given' );

  $pub = Paperpile::Library::Publication->new( authors => '{Human genome sequencing consortium}' );
  is(
    $pub->format_pattern('[Firstauthor]'),
    'Human_genome_sequencing_consortium',
    '[Firstauthor] from collective author'
  );

  $pub = Paperpile::Library::Publication->new( editors => '{Human genome sequencing consortium}' );
  is(
    $pub->format_pattern('[Firstauthor]'),
    'Human_genome_sequencing_consortium',
    '[Firstauthor] from collective editor'
  );

  $pub = Paperpile::Library::Publication->new( authors => 'Doe, J', );
  is( $pub->format_pattern('[Firstauthor]'), 'Doe', '[Firstauthor] for single author paper' );
  is( $pub->format_pattern('[Lastauthor]'),  '',    '[Lastauthor] for single author paper' );

}

1;
