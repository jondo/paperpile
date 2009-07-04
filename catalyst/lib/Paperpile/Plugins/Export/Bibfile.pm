package Paperpile::Plugins::Export::Bibfile;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use 5.010;

extends 'Paperpile::Plugins::Export';

## Supported settings (correspond to the Bibutils settings)

#  out_format: MODS, BIBTEX, RIS, ENDNOTE, COPAC, ISI, MEDLINE, ENDNOTEXML, BIBLATEX
#  charsetout
#  latexout
#  utf8out
#  xmlout
#  bibout_finalcomma
#  bibout_singledash
#  bibout_whitespace
#  bibout_brackets
#  bibout_uppercase
#  bibout_strictkey
#  modsout_dropkey
#  wordout_dropkey

sub write {

  my ($self) = @_;

  my %s = %{ $self->settings };

  #foreach my $key (keys %{$self->settings}){
  #  my $new_key=$key;
  #  $new_key=~s/^export_//;
  #  $s{$new_key}=$self->settings->{$key};
  #}

  my @bibutils = ();

  foreach my $pub ( @{ $self->data } ) {
    push @bibutils, $pub->_format_bibutils;
  }

  my %formats = (
    MODS       => Bibutils::MODSOUT,
    BIBTEX     => Bibutils::BIBTEXOUT,
    RIS        => Bibutils::RISOUT,
    ENDNOTE    => Bibutils::ENDNOTEOUT,
    ISI        => Bibutils::ISIOUT,
    WORD2007   => Bibutils::WORD2007OUT,
  );

  my $bu = Bibutils->new(
    in_file    => '',
    out_file   => $self->settings->{out_file},
    in_format  => Bibutils::BIBTEXIN,
    out_format => $formats{$self->settings->{out_format}},
  );

  $bu->set_data( [@bibutils] );

  $bu->write( {%s} );

  my $error = $bu->error;

  if ( $error != 0 ) {

    #my $msg = "Data could not be exported. ";
    #if ( $error == Bibutils::ERR_CANTOPEN ) {
    #  $msg .= "Could not open file.";
    #}
    #if ( $error == Bibutils::ERR_MEMERR ) {
    #  $msg .= "Not enough memory.";
    #}

    FileWriteError->throw( error => "Could not write ". $self->settings->{out_file} );

  }

}

1;
