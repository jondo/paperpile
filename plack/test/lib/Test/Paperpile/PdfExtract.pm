package Test::Paperpile::PdfExtract;

use Test::More;
use Data::Dumper;
use YAML;

use Paperpile::Library::Publication;

use base 'Test::Paperpile';

sub class { 'Paperpile::PdfExtract' }

sub startup : Tests(startup => 1) {
  my ($self) = @_;
  use_ok $self->class;
}

sub extract : Tests(5327) {

  my ($self) = @_;

  $self->test_extract(
    'Testcases 00001-00100',
    'data/PdfExtract/testcases_00001_00100.in',
    'data/PdfExtract/testcases_00001_00100.out'
  );
  $self->test_extract(
    'Testcases 00101-00200',
    'data/PdfExtract/testcases_00101_00200.in',
    'data/PdfExtract/testcases_00101_00200.out'
  );
  $self->test_extract(
    'Testcases 00201-00300',
    'data/PdfExtract/testcases_00201_00300.in',
    'data/PdfExtract/testcases_00201_00300.out'
  );
  $self->test_extract(
    'Testcases 00301-00400',
    'data/PdfExtract/testcases_00301_00400.in',
    'data/PdfExtract/testcases_00301_00400.out'
  );
  $self->test_extract(
    'Testcases 00401-00500',
    'data/PdfExtract/testcases_00401_00500.in',
    'data/PdfExtract/testcases_00401_00500.out'
  );
  $self->test_extract(
    'Testcases 00501-00600',
    'data/PdfExtract/testcases_00501_00600.in',
    'data/PdfExtract/testcases_00501_00600.out'
  );
  $self->test_extract(
    'Testcases 00601-00700',
    'data/PdfExtract/testcases_00601_00700.in',
    'data/PdfExtract/testcases_00601_00700.out'
  );
  $self->test_extract(
    'Testcases 00701-00800',
    'data/PdfExtract/testcases_00701_00800.in',
    'data/PdfExtract/testcases_00701_00800.out'
  );
  $self->test_extract(
    'Testcases 00801-00900',
    'data/PdfExtract/testcases_00801_00900.in',
    'data/PdfExtract/testcases_00801_00900.out'
  );
  $self->test_extract(
    'Testcases 00901-01000',
    'data/PdfExtract/testcases_00901_01000.in',
    'data/PdfExtract/testcases_00901_01000.out'
  );
  $self->test_extract(
    'Testcases 01001-01100',
    'data/PdfExtract/testcases_01001_01100.in',
    'data/PdfExtract/testcases_01001_01100.out'
  );
  $self->test_extract(
    'Testcases 01101-01200',
    'data/PdfExtract/testcases_01101_01200.in',
    'data/PdfExtract/testcases_01101_01200.out'
  );
  $self->test_extract(
    'Testcases 01201-01300',
    'data/PdfExtract/testcases_01201_01300.in',
    'data/PdfExtract/testcases_01201_01300.out'
  );
  $self->test_extract(
    'Testcases 01301-01400',
    'data/PdfExtract/testcases_01301_01400.in',
    'data/PdfExtract/testcases_01301_01400.out'
  );
  $self->test_extract(
    'Testcases 01401-01500',
    'data/PdfExtract/testcases_01401_01500.in',
    'data/PdfExtract/testcases_01401_01500.out'
  );
  $self->test_extract(
    'Testcases 01501-01600',
    'data/PdfExtract/testcases_01501_01600.in',
    'data/PdfExtract/testcases_01501_01600.out'
  );
  $self->test_extract(
    'Testcases 01601-01700',
    'data/PdfExtract/testcases_01601_01700.in',
    'data/PdfExtract/testcases_01601_01700.out'
  );
  $self->test_extract(
    'Testcases 01701-01800',
    'data/PdfExtract/testcases_01701_01800.in',
    'data/PdfExtract/testcases_01701_01800.out'
  );
  $self->test_extract(
    'Testcases 01801-01900',
    'data/PdfExtract/testcases_01801_01900.in',
    'data/PdfExtract/testcases_01801_01900.out'
  );
  $self->test_extract(
    'Testcases 01901-02000',
    'data/PdfExtract/testcases_01901_02000.in',
    'data/PdfExtract/testcases_01901_02000.out'
  );
  $self->test_extract(
    'Testcases 02001-02100',
    'data/PdfExtract/testcases_02001_02100.in',
    'data/PdfExtract/testcases_02001_02100.out'
  );
  $self->test_extract(
    'Testcases 02101-02200',
    'data/PdfExtract/testcases_02101_02200.in',
    'data/PdfExtract/testcases_02101_02200.out'
  );
  $self->test_extract(
    'Testcases 02101-02200',
    'data/PdfExtract/testcases_02201_02300.in',
    'data/PdfExtract/testcases_02201_02300.out'
  );
}


sub test_extract {

  my ( $self, $msg, $infile, $outfile ) = @_;

  my $pdfextract = $self->class->new();

  my @infiles  = YAML::LoadFile("$infile");
  my @observed = ();
  foreach my $entry (@infiles) {
    $pdfextract->file( $entry->{file} );
    my $pub = $pdfextract->parsePDF();
    push @observed, $pub;
  }

  open FH, "<:encoding(UTF-8)", "$outfile";
  my $out = '';
  $out .= $_ foreach (<FH>);
  close(FH);

  my @expected = YAML::Load($out);

  if ( $#observed == $#expected ) {
    foreach my $i ( 0 .. $#expected ) {
      ( my $file = $infiles[$i]->{file} ) =~ s/(.*\/)(\d+\.pdf)/$2/;
      if ( defined $expected[$i]->{title} ) {
        $expected[$i]->{title} .= " | $file";
        my $tmp = $observed[$i]->title();
        $observed[$i]->title("$tmp | $file");
      }
      if ( defined $expected[$i]->{authors} ) {
        $expected[$i]->{authors} .= " | $file";
        my $tmp = $observed[$i]->authors();
        $observed[$i]->authors("$tmp | $file");
      }
      if ( defined $expected[$i]->{doi} ) {
        $expected[$i]->{doi} .= " | $file";
        my $tmp = $observed[$i]->doi();
        $observed[$i]->doi("$tmp | $file");
      }
      if ( defined $expected[$i]->{arxivid} ) {
        $expected[$i]->{arxivid} .= " | $file";
        my $tmp = $observed[$i]->arxivid();
        $observed[$i]->arxivid("$tmp | $file");
      }
    }
  }

  is( $#observed, $#expected, "$msg: read " . ( $#expected + 1 ) . " items" );

  foreach my $i ( 0 .. $#expected ) {
    $self->test_fields( $observed[$i], $expected[$i], $msg );
  }
}
1;
