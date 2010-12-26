package Test::Paperpile::Formats::Bibtex;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Formats';

# The class being tested
sub class { 'Paperpile::Formats::Bibtex' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  $self->{settings} = {
    import_strip_tex     => 1,
    export_escape        => 1,
    pretty_print         => 1,
    use_quotes           => 0,
    double_dash          => 1,
    title_quote_complete => 0,
    title_quote_smart    => 1,
    title_quote          => [ 'DNA', 'RNA' ],
    export_fields        => {
      abstract    => 0,
      affiliation => 0,
      eprint      => 0,
      issn        => 0,
      isbn        => 0,
      pmid        => 1,
      lccn        => 0,
      doi         => 1,
      keywords    => 0
    }
  };

  use_ok $self->class;

}

# Add test functions here

sub read : Tests(29) {

  my ($self) = @_;

  $self->test_read(
    "Misc. test",
    "data/Formats/Bibtex/read/misc.bib",
    "data/Formats/Bibtex/read/misc.out",
    $self->{settings}
  );

  $self->test_read(
    "Publication types",
    "data/Formats/Bibtex/read/pubtypes.bib",
    "data/Formats/Bibtex/read/pubtypes.out",
    $self->{settings}
  );

  $self->{settings}->{import_strip_tex} = 1;
  $self->test_read(
    "Strip TeX",
    "data/Formats/Bibtex/read/latex.bib",
    "data/Formats/Bibtex/read/strip_latex.out",
    $self->{settings}
  );

  $self->{settings}->{import_strip_tex} = 0;
  $self->test_read(
    "Preserve TeX",
    "data/Formats/Bibtex/read/latex.bib",
    "data/Formats/Bibtex/read/no_strip_latex.out",
    $self->{settings}
  );

}


sub write : Tests(2) {

  my ($self) = @_;

  $self->test_write( "Misc", "data/Formats/Bibtex/write/misc.yaml", $self->{settings} );

}

1;
