package PaperPile::Library::Source;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Iterator;

has 'entries_per_page' => ( is => 'rw', isa => 'Int', default => 10 );
has 'total_entries' => ( is => 'rw', isa => 'Int');
has '_iter' => ( is => 'rw', isa => 'MooseX::Iterator::Array');
has '_pager' => ( is => 'rw', isa => 'Data::Page');
has '_data' => ( is => 'rw', isa => 'ArrayRef');

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

sub page{

  (my $self, my $pg)=@_;

  $self->_pager->current_page($pg);

  return $self->_get_data_for_page;
}









1;
