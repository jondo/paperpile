package PaperPile::Library::Source;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Iterator;
use Data::Dumper;
use Data::Page;
use POSIX qw(ceil floor);

has 'entries_per_page' => (
  is      => 'rw',
  isa     => 'Int',
  default => 10,
  trigger => sub {
    ( my $self, my $value ) = @_;
    $self->_pager->entries_per_page($value);
  }
);

has 'total_entries' => ( is => 'rw', isa => 'Int' );
has '_hash'  => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );
has '_pager' => ( is => 'rw', isa => 'Data::Page' );

sub BUILD {

  ( my $self ) = @_;

  $self->_pager( Data::Page->new() );

}

sub connect {
  my $self = shift;
  return undef;
}

sub page {
  ( my $self, my $pg ) = @_;
  $self->_pager->current_page($pg);

  my $data = $self->_get_data_for_page;

  $self->_save_page_to_hash($data);

  return $data;

}

sub page_from_offset {
  ( my $self, my $offset, my $limit ) = @_;

  my $page = floor( $offset / $limit ) + 1;

  return $self->page($page);
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
