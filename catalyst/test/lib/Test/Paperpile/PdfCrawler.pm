package Test::Paperpile::PdfCrawler;

use strict;
use Test::More;
use Data::Dumper;
use Paperpile;
use Paperpile::Utils;
use base 'Test::Paperpile';

sub class { 'Paperpile::PdfCrawler' }

sub startup : Tests(startup => 2) {
  my ($self) = @_;

  use_ok $self->class;

  $self->{driver_file} = Paperpile::Utils->path_to("data/pdf-crawler.xml")->stringify;

  ok( -e $self->{driver_file}, "Found driver file." ) || $self->SKIP_ALL("PDF crawler driver file not found");

}

sub crawler : Tests(99) {

  my ($self) = @_;

  my $crawler = Paperpile::PdfCrawler->new;
  $crawler->driver_file( $self->{driver_file} );
  $crawler->load_driver();
  $crawler->debug(0);

  my $tests = $crawler->get_tests;

  foreach my $site ( keys %$tests ) {
    my $test_no = 1;
    foreach my $test ( @{ $tests->{$site} } ) {
      my $file;
      eval { $file = $crawler->search_file($test) };
      diag($@) if ($@);
      ok( $file, "$site: getting pdf-url for $test" );
    SKIP: {
        skip( "No valid url found, not downloading PDF", 1 ) if not defined $file;
        is( $crawler->check_pdf($file), 1, "$site: checking if PDF" );
      }
      $test_no++;
    }
  }
}



1;
