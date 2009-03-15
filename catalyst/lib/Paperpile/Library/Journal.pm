package Paperpile::Library::Journal;
use Moose;
use Moose::Util::TypeConstraints;

has 'key'    => ( is => 'rw', isa => 'Str' );
has 'name'  => ( is => 'rw', isa => 'Str' );
has 'issn'  => ( is => 'rw', isa => 'Str' );
has 'url'   => ( is => 'rw', isa => 'Str' );
has 'icon'  => ( is => 'rw', isa => 'Str' );

sub BUILD {

  my ( $self, $params ) = @_;

}

1;

