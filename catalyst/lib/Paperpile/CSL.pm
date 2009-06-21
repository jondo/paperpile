package Paperpile::CSL;

use Moose;
use Paperpile::Library::Publication;
use Paperpile::Utils;
use Paperpile::Exceptions;
use Data::Dumper;
use File::Temp qw/ tempfile /;
use JSON;
use 5.010;

has 'data'  => ( is => 'rw', isa => 'ArrayRef' );
has 'style' => ( is => 'rw', isa => 'String' );

sub format_bibliography {
  my ($self) = @_;

  my $bin = Paperpile::Utils->get_binary('js');

  my $citeproc_js = Paperpile::Utils->path_to('data/csl/citeproc-js.js');
  my $sys_js      = Paperpile::Utils->path_to('data/csl/sys.js');

  my $style_file  = Paperpile::Utils->path_to('data/csl/style/nature.csl');
  my $locale_file = Paperpile::Utils->path_to('data/csl/locale/locales-en-US.xml');

  my @output = ();

  my $style  = '';
  my $locale = '';

  open( IN, "<$style_file" );
  $style .= $_ while <IN>;

  open( IN, "<$locale_file" );
  $locale .= $_ while <IN>;

  $locale =~ s/<\?.*\?>//g;
  $style  =~ s/<\?.*\?>//g;

  $locale = JSON->new->allow_nonref->encode($locale);
  $style  = JSON->new->allow_nonref->encode($style);

  my @ids=();

  foreach my $pub ( @{ $self->data } ) {
    push @output, $pub->format_csl;
    push @ids, $pub->sha1;
  }

  my ( $script, $filename ) = tempfile( "paperpile-csl-XXXXX", DIR => '.' );

  say $script "load('$citeproc_js');";
  say $script "load('$sys_js');";

  my $string = to_json( \@output );

  say $script "sys.loadData($string);";
  say $script "locales = new Object();";
  say $script "locales[\"en\"] = $locale;";
  say $script "style = CSL.makeStyle(sys,$style);";

  $string= to_json(\@ids);

  say $script "style.insertItems($string);";
  say $script "print(style.makeBibliography());";

}

1;
