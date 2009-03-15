package Paperpile::Plugins::Import;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use Data::Page;
use POSIX qw(ceil floor);

has 'limit' => (
  is      => 'rw',
  isa     => 'Int',
  default => 10,
);

has 'total_entries' => ( is => 'rw', isa => 'Int' );
has '_hash'  => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );

sub connect {
  my $self = shift;
  return undef;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;
  return 0;
}

sub _save_page_to_hash {

  ( my $self, my $data ) = @_;

  foreach my $entry (@$data) {
    $self->_hash->{ $entry->sha1 } = $entry;
  }
}

sub find_sha1 {

  ( my $self, my $sha1 ) = @_;

  return $self->_hash->{$sha1};

}

1;
