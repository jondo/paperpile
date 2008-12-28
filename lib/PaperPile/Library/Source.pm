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
has '_iter'         => ( is => 'rw', isa => 'MooseX::Iterator::Array' );
has '_pager'        => ( is => 'rw', isa => 'Data::Page' );
has '_data'         => ( is => 'rw', isa => 'ArrayRef' );

sub BUILD{

  (my $self) = @_;

  $self->_pager(Data::Page->new() );

}

sub connect {
  my $self = shift;
  return undef;
}

sub next {
  my $self = shift;
  return $self->_iter->next;
}

sub has_next {
  my $self = shift;
  return $self->_iter->has_next;
}

sub peek {
  my $self = shift;
  return $self->_iter->peek;
}

sub all {
  my $self = shift;
  return $self->_data;
}

sub page {
  ( my $self, my $pg ) = @_;
  $self->_pager->current_page($pg);
  return $self->_get_data_for_page;
}

sub page_from_offset {
  ( my $self, my $offset, my $limit ) = @_;

  my $page = floor( $offset / $limit ) + 1;

  return $self->page($page);
}

sub find_sha1 {

  ( my $self, my $sha1 ) = @_;

  foreach my $entry (@{$self->all}){
    return $entry if ($entry->sha1 eq $sha1);
  }
}


1;
