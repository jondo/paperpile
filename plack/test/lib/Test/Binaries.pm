package Test::Binaries;

use strict;

use Test::More;
use Test::Deep;
use Data::Dumper;
use Paperpile;
use Paperpile::Utils;
use File::Temp;

use XML::Simple;

use base 'Test::Class';

sub extpdf : Tests(5) {

  my ($self) = @_;

  my $extpdf = Paperpile::Utils->get_binary('extpdf');

  ok( "-x $extpdf", "Extpdf is present and executable" );

  foreach my $file ( 'info-1', 'wordlist-1', 'wordlist-2', 'text-1' ) {

    my $arguments = $self->_get_arguments("$file.xml");
    my $output    = Paperpile::Utils->extpdf($arguments);

    my $expected_file = Paperpile->path_to( "test", "data", "Binaries", "extpdf", "$file.out" );

    if ( $arguments->{command} eq 'TEXT' ) {
      $self->compare_file_flat( $output, $expected_file, $arguments->{comment} );
    } else {
      $self->compare_file_deep( $output, $expected_file, $arguments->{comment} );
    }
  }
}


# Get arguments for extpdf from xml file
sub _get_arguments {

  my ( $self, $file ) = @_;

  my $file = Paperpile->path_to( "test", "data", "Binaries", "extpdf", $file );

  my $arguments = XMLin($file);

  # Convert inFile to absolute path
  $arguments->{inFile} =
    Paperpile->path_to( "test", "data", "Binaries", "extpdf", $arguments->{inFile} );

  return $arguments;
}

# Compares $data to data in $expected_file
sub compare_file_flat {

  my ( $self, $data, $expected_file, $comment ) = @_;

  open( IN, "<$expected_file" );

  my @input = <IN>;

  my $expected;

  $expected .= $_ foreach (@input);

  is( $data, $expected, $comment );
}

# Compares $data to the perl object dumped in $expected_file via
# cmp_deeply
sub compare_file_deep {

  my ( $self, $data, $expected_file, $comment ) = @_;

  open( IN, "<$expected_file" );

  my @input = <IN>;

  my $expected;

  $expected .= $_ foreach (@input);

  # Eval the dump to $VAR1
  my $VAR1;
  eval($expected);

  cmp_deeply($data, $VAR1, $comment);
}


1;
