package Test::Paperpile::Plugins;

use Test::More;
use Data::Dumper;
use YAML;

use Paperpile::Library::Publication;
use Paperpile::Plugins::Import::PubMed;

use base 'Test::Paperpile';

sub class { 'Paperpile::Plugins' }


sub startup : Tests(startup => 1) {
  my ($self) = @_;
  use_ok $self->class;
}

sub test_match {

  my ( $self, $msg, $infile, $outfile ) = @_;

  my $plugin = $self->class->new();

  my @in = YAML::LoadFile("$infile");

  my @observed = ();

  foreach my $entry (@in) {

    my $pub = Paperpile::Library::Publication->new();

    foreach my $key ( keys %{$entry} ) {
      $pub->doi( $entry->{$key} )     if ( $key eq 'doi' );
      $pub->pmid( $entry->{$key} )    if ( $key eq 'pmid' );
      $pub->title( $entry->{$key} )   if ( $key eq 'title' );
      $pub->authors( $entry->{$key} ) if ( $key eq 'authors' );
    }
    $pub->create_guid();

    my $matchedpub = $plugin->match($pub);

    push @observed, $matchedpub;
  }

  my @expected = YAML::LoadFile("$outfile");

  is( $#observed, $#expected, "$msg: read " . ( $#observed + 1 ) . " items" );

  foreach my $i ( 0 .. $#expected ) {
    $self->test_fields( $observed[$i], $expected[$i], $msg );
  }
}

sub test_connect_page {

  my ( $self, $msg, $infile, $outfile ) = @_;

  my $plugin = $self->class->new();

  my @in = YAML::LoadFile("$infile");

  my @observed = ();

  foreach my $entry (@in) {
    if ( defined $entry->{query} ) {
      $plugin->query( $entry->{query} );
      my $nr_hits = $plugin->connect();
      my $pubs = $plugin->page( 0, 25 );
      foreach my $pub ( @{$pubs} ) {
        push @observed, $pub;
      }
    }
    elsif ( defined $entry->{file} ) {
      $plugin->file( $entry->{file} );
      my $nr_hits = $plugin->connect();
      my $pubs = $plugin->page( 0, 25 );
      foreach my $pub ( @{$pubs} ) {
        push @observed, $pub;
      }
    }

  }

  my @expected = YAML::LoadFile("$outfile");

  is( $#observed, $#expected, "$msg: read " . ( $#observed + 1 ) . " items" );

  foreach my $i ( 0 .. $#expected ) {
    $self->test_fields( $observed[$i], $expected[$i], $msg );
  }

}

1;
