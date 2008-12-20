package PaperPile::Library::Source::DB;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use PaperPile::Model::DB;
use PaperPile::Library;

extends 'PaperPile::Library::Source';

has 'query' => ( is => 'rw' );

sub connect {
  my $self = shift;

  my $model = PaperPile::Model::DB->new;

  $self->_data( $model->search($self->query));

  $self->total_entries( scalar( @{ $self->_data } ) );

  $self->_iter( MooseX::Iterator::Array->new( collection => $self->_data ) );
  $self->_pager( Data::Page->new() );
  $self->_pager->total_entries( $self->total_entries );
  $self->_pager->entries_per_page( $self->entries_per_page );
  $self->_pager->current_page(1);

  return $self->total_entries;
}

sub _get_data_for_page {
  my $self = shift;

  my @output = ();

  for my $i ( $self->_pager->first .. $self->_pager->last ) {
    push @output, $self->_data->[ $i - 1 ];
  }

  return [@output];

}

1;
