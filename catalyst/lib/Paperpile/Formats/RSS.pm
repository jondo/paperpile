package Paperpile::Formats::Paperpile;
use Moose;
use XML::Simple;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('RSS');
  $self->readable(1);
  $self->writable(0);
}


sub read {

    my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );
    $pub->title('Test');
    $pub->authors('Gruber AR');
    
    my @output = ();
    push @output, $pub;
    
    return [@output];

}

sub write{



}



1;



