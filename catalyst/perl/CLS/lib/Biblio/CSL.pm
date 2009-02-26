package Biblio::CSL;

use 5.010000;
use strict;
use warnings;
use Moose;
use XML::Simple;
require Exporter;

use Data::Dumper;    # TODO: just for debugging

our @ISA    = qw(Exporter);
our @EXPORT = qw(
  $VERSION
);

# TODO: better as read-only attribute?
our $VERSION = "0.01";

# input xml data file in mods format
has 'mods' => (
  is       => 'rw',
  isa      => 'Str',
  reader   => 'get_mods',
  writer   => 'set_mods',
  required => 1
);

# input csl style file
has 'csl' => (
  is       => 'rw',
  isa      => 'Str',
  reader   => 'get_csl',
  writer   => 'set_csl',
  required => 1
);

# output format
has 'format' => (
  is       => 'rw',
  isa      => 'Str',
  reader   => 'get_format',
  writer   => 'set_format',
  default  => 'txt',
  trigger  => \&_format_set,
  required => 1
);

# output text, will keep the complete output string
has 'text' => (
  is       => 'ro',
  isa      => 'Str',
  reader   => 'get_text',
  required => 0
);

# trigger to check that the format is validly set to a supported type
sub _format_set {
  my ( $self, $format, $meta_attr ) = @_;

  if ( $format ne "txt" ) {
    die "ERROR: Unknwon output format\n";
  }
}

### class methods

# do the transformation of the mods file given the csl style file
sub transform {
  my $self = shift;

  my $m = XMLin( $self->get_mods );
  my $c = XMLin( $self->get_csl );

  #print Dumper $m;

  # transform the author passage
  if ( exists $c->{macro}->{author} ) {
    my $rounds = scalar( @{ $m->{name} } );
    foreach my $n ( @{ $m->{name} } ) {
      foreach my $np ( sort { $b <=> $a } @{ $n->{namePart} } ) {
        print $np->{content};
        print " " if ( $np->{type} eq "family" );
      }
      $rounds--;
      my $a if ( $c->{macro}->{author}->{names}->{name}->{and} eq "text" );
      print $c->{macro}->{author}->{names}->{name}->{delimiter} . "and " if ( $rounds > 0 );
    }
  }
  print "\n";

}

# print the current version of the modul

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
sub version {
  print "This is XML::CSL version ", $VERSION, "\n";
}
