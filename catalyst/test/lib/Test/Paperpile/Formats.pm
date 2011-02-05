package Test::Paperpile::Formats;

use Test::More;
use Data::Dumper;
use YAML;

use Paperpile::Library::Publication;

use base 'Test::Paperpile';

sub class { 'Paperpile::Formats' }

sub startup : Tests(startup => 1) {
  my ($self) = @_;
  use_ok $self->class;
}

# Test $infile against $outfile file. $settings is passed directly to
# the Formats class. Adds one test for each specified field and an
# additional one for the correct number of entries read.

sub test_read {

  my ( $self, $msg, $infile, $outfile, $settings ) = @_;

  my @observed = @{ $self->class->new( file => "$infile", settings => $settings || {} )->read };
  my @expected = YAML::LoadFile("$outfile");

  is( $#observed, $#expected, "$msg: read ".($#expected+1)." items" );

  foreach my $i ( 0 .. $#expected ) {
    $self->test_fields( $observed[$i], $expected[$i], $msg );
  }
}

sub test_write {

  my ( $self, $msg, $file, $settings ) = @_;

  $settings = {} if not defined $settings;

  my @data = YAML::LoadFile($file);

  foreach my $test (@data) {

    my ( $msg, $expected, $test_settings, %pub_data );

    foreach my $field ( keys %$test ) {

      if ( $field eq 'test_comment' ) {

        $msg = $test->{$field};

      } elsif ( $field eq 'test_expected' ) {

        $expected = $test->{$field};

      } elsif ( $field eq 'test_settings' ) {

        $test_settings = $test->{$field};

      } else {

        $pub_data{$field} = $test->{$field};

      }
    }

    foreach my $field (%$test_settings) {
      $settings->{$field} = $test_settings->{$field};
    }

    my $pub = Paperpile::Library::Publication->new(%pub_data);

    my $observed = $self->class->new( data => [$pub], settings => $settings)->write_string;

    $expected =~ s/^\s+//;
    $expected =~ s/\s+$//;
    $observed =~ s/^\s+//;
    $observed =~ s/\s+$//;

    cmp_ok( $observed, "eq", $expected, $msg );

  }
}


1;
