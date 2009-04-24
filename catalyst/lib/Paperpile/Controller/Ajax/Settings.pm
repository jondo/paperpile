package Paperpile::Controller::Ajax::Settings;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use 5.010;

sub pattern_example : Local {
  my ( $self, $c ) = @_;

  my $pattern = $c->request->params->{pattern};
  my $key     = $c->request->params->{key};

  # Add full validation later
  if (!$pattern){
    $self->_submit( $c, { string => undef, error => 'Pattern must not be empty.' } );
  }

  my %book = (
    pubtype   => 'INBOOK',
    title     => 'Fundamental Algorithms',
    booktitle => 'The Art of Computer Programming',
    authors   => 'Knuth, D.E.',
    volume    => '1',
    pages     => '10-119',
    publisher => 'Addison-Wesley',
    city      => 'Reading',
    address   => "Massachusetts",
    year      => '2007',
    month     => 'Jan',
    isbn      => '0-201-03803-X',
    notes     => 'These are my notes',
    tags      => 'programming, algorithms',
  );

  my $pub = Paperpile::Library::Publication->new( {%book} );

  my $formatted_key = $pub->format_pattern($key);

  my $string = $pub->format_pattern( $pattern, { key => $formatted_key } );

  $self->_submit( $c, { string => $string } );

}

sub update_patterns : Local {
  my ( $self, $c ) = @_;

  my $user_db            = $c->request->params->{user_db};
  my $paper_root         = $c->request->params->{paper_root};
  my $key_pattern        = $c->request->params->{key_pattern};
  my $pdf_pattern        = $c->request->params->{pdf_pattern};
  my $attachment_pattern = $c->request->params->{attachment_pattern};

  # key_pattern has changed
  if ($key_pattern ne $c->model('User')->get_setting('user_db')){

    $c->model('User')->update_citekeys($key_pattern);

  }


  $c->stash->{data}    = {};
  $c->stash->{success} = 'true';

  $c->detach('Paperpile::View::JSON');

}



sub _submit {

  my ( $self, $c, $data ) = @_;

  $c->stash->{data}    = $data;
  $c->stash->{success} = 'true';

  $c->detach('Paperpile::View::JSON');
}







1;
