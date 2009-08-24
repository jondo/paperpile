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

  my $format = $self->settings->{out_format};
  $format = lc($format);
  $format = ucfirst($format);

  my $module="Paperpile::Formats::$format";

  my $writer = eval("use $module; $module->new()");

  $writer->file($self->settings->{out_file});
  $writer->settings($self->settings);
  $writer->data($self->data);

  $writer->write();

}

1;
