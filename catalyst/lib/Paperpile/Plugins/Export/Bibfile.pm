package Paperpile::Plugins::Export::Bibfile;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use 5.010;

extends 'Paperpile::Plugins::Export';

has 'file_name' => (
  is      => 'rw',
  isa     => 'Str',
);

## Supported settings (correspond to the Bibutils settings + "export_"-prefix

#  export_format_out: MODS, BIBTEX, RIS, ENDNOTE, COPAC, ISI, MEDLINE, ENDNOTEXML, BIBLATEX
#  export_charsetout
#  export_latexout
#  export_utf8out
#  export_xmlout
#  export_bibout_finalcomma
#  export_bibout_singledash
#  export_bibout_whitespace
#  export_bibout_brackets
#  export_bibout_uppercase
#  export_bibout_strictkey
#  export_modsout_dropkey
#  export_wordout_dropkey


sub write {

  my ($self) = @_;


  my %s=();

  foreach my $key (keys %{$self->settings}){
    my $new_key=$key;
    $new_key=~s/^export_//;
    $s{$new_key}=$self->settings->{$key};
  }

  my @bibutils = ();

  foreach my $pub ( @{ $self->data } ) {
    push @bibutils, $pub->_format_bibutils;
  }

  my $bu = Bibutils->new(
    in_file    => '',
    out_file   => $self->settings->{export_file},
    in_format  => Bibutils::BIBTEXIN,
    out_format => Bibutils::BIBTEXOUT,
  );

  $bu->set_data([@bibutils]);

  $bu->write({%s});

  my $error=$bu->error;

  if ($error != 0){

    my $msg="Data could not be exported. ";

    if ($error == Bibutils::ERR_CANTOPEN){
      $msg.="Could not open file.";
    }

    if ($error == Bibutils::ERR_MEMERR){
      $msg.="Not enough memory.";
    }

    die($msg);

  }

}

1;
