# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.


package Paperpile::Controller::Ajax::Settings;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Exceptions;
use File::Temp;
use File::Copy;
use File::Path;
use Data::Dumper;
use JSON;
use 5.010;

sub pattern_example : Local {

  my ( $self, $c ) = @_;

  my $paper_root = $c->request->params->{paper_root};
  my $library_db = $c->request->params->{library_db};

  my $key_pattern        = $c->request->params->{key_pattern};
  my $pdf_pattern        = $c->request->params->{pdf_pattern};
  my $attachment_pattern = $c->request->params->{attachment_pattern};

  my %data = ();

  foreach my $field ( 'key_pattern', 'pdf_pattern', 'attachment_pattern' ) {
    while ( $c->request->params->{$field} =~ /\[\s*(.*?)\s*\]/ig ) {
      if ( not $1 =~ /^(firstauthor|lastauthor|authors|title|journal|yy|yyyy|key)[:_0-9]*$/i ) {
        $data{$field}->{error} = "Invalid pattern [$1]";
      }
    }
  }

  my $minimum = qr/\[(firstauthor|lastauthor|authors|title|journal)[:_0-9]*\]/i;

  my $minimum_error_text =
    'Your pattern must include at least [firstauthor], [lastauthor], [authors], [title], or [journal]';

  if ( not $key_pattern =~ $minimum ) {
    $data{key_pattern}->{error} = $minimum_error_text;
  }

  if ( not $pdf_pattern =~ /\[key\]/i ) {
    if ( not $pdf_pattern =~ $minimum ) {
      $data{pdf_pattern}->{error} = $minimum_error_text;
    }
  }

  if ( not $attachment_pattern =~ /\[key\]/i ) {
    if ( not $attachment_pattern =~ $minimum ) {
      $data{attachment_pattern}->{error} = $minimum_error_text;
    }
  }

  $paper_root =~ s{/$}{};    # remove trailing /

  my %sample = (
    pubtype => 'ARTICLE',
    title   => 'A note on strategy elimination in bimatrix games',
    authors => 'Knuth, D.E. and Papadimitriou, C.H. and Tsitsiklis, J.H.',
    journal => 'Operations Research Letters',
    volume  => '7',
    pages   => '103--107',
    year    => '1988',
  );

  my $pub = Paperpile::Library::Publication->new( {%sample} );

  my $formatted_key        = $pub->format_pattern( $c->request->params->{key_pattern} );
  my $formatted_pdf        = $pub->format_pattern( $pdf_pattern, { key => $formatted_key } );
  my $formatted_attachment = $pub->format_pattern( $attachment_pattern, { key => $formatted_key } );

  my @tmp = split( /\//, $paper_root );

  $formatted_pdf        = ".../" . $tmp[$#tmp] . "/<b>$formatted_pdf.pdf</b>";
  $formatted_attachment = ".../" . $tmp[$#tmp] . "/<b>$formatted_attachment/</b>";

  $data{key_pattern}->{string}        = $formatted_key;
  $data{pdf_pattern}->{string}        = $formatted_pdf;
  $data{attachment_pattern}->{string} = $formatted_attachment;

  my $settings = $c->model('Library')->settings;
  $data{paper_root}->{string} = '';
  if ($paper_root ne $settings->{paper_root}) {
    if (scalar glob("$paper_root/*")){
	$data{paper_root}->{error} = "The PDF folder is not empty. To avoid conflicts with existing files please choose a new or empty folder for your PDFs";
    }
  }

  $c->stash->{data} = {%data};

}

sub update_patterns : Local {
  my ( $self, $c ) = @_;

  my $library_db         = $c->request->params->{library_db};
  my $paper_root         = $c->request->params->{paper_root};
  my $key_pattern        = $c->request->params->{key_pattern};
  my $pdf_pattern        = $c->request->params->{pdf_pattern};
  my $attachment_pattern = $c->request->params->{attachment_pattern};

  my $settings = $c->model('Library')->settings;
  $settings->{library_db} = $c->model('User')->get_setting('library_db');

  my $db_changed         = $library_db         ne $settings->{library_db};
  my $root_changed       = $paper_root         ne $settings->{paper_root};
  my $key_changed        = $key_pattern        ne $settings->{key_pattern};
  my $pdf_changed        = $pdf_pattern        ne $settings->{pdf_pattern};
  my $attachment_changed = $attachment_pattern ne $settings->{attachment_pattern};

  if ($key_changed) {
    $c->model('Library')->update_citekeys($key_pattern);
  }

  # Update files if either attachments or pdf pattern changed, or if
  # key pattern changed and either of them contains [key]
  my $update_files = 0;
  $update_files = 1 if ( $pdf_changed or $attachment_changed );
  $update_files = 1 if ( $key_changed and $pdf_pattern        =~ /\[key\]/ );
  $update_files = 1 if ( $key_changed and $attachment_pattern =~ /\[key\]/ );

  if ($update_files) {
    $c->model('Library')->rename_files( $c->request->params->{pdf_pattern},
                                        $c->request->params->{attachment_pattern});

    $c->model('Library')->set_setting( 'pdf_pattern',        $pdf_pattern );
    $c->model('Library')->set_setting( 'attachment_pattern', $attachment_pattern);
  }

  if ($root_changed) {
    $c->model('Library')->change_paper_root($paper_root);
  }

  if ($db_changed) {

    my $ok = 0;
    if ( not -e $library_db ) {
      $ok = move( $settings->{library_db}, $library_db );
    } else {
      $ok = 1;
    }

    if ($ok) {

      # update library_db in session variable
      Paperpile::Utils->session($c, {library_db => $library_db});

      ## Refactored tree, is not stored in session any more. So it should be reloaded without that...
      # Force reload of tree
      #Paperpile::Utils->session($c, {tree => undef});

      $c->model('User')->set_setting( 'library_db', $library_db );
    } else {
      FileError->throw("Could not change database file to $library_db ($!)");
    }
  }

  $c->stash->{data} = {};

}



# Store settings in the databases (library or user db). All data must
# be encoded as JSON. This allows to story arbitrary objects through
# this function.

sub set_settings : Local {

  my ( $self, $c ) = @_;

  my $json = JSON->new->allow_nonref;

  # Decode JSON data
  for my $field ( keys %{ $c->request->params } ) {
    $c->request->params->{$field} = $json->decode($c->request->params->{$field});
  }

  # Set user user_settings
  for my $field ( keys %{$c->config->{'user_settings'}}){

    # Only store settings that are defined in the parameters.
    if ( defined $c->request->params->{$field} ) {
      $c->model('User')->set_setting( $field, $c->request->params->{$field} );
    }
  }

  # Set library settings
  for my $field ( keys %{$c->config->{'library_settings'}}){
    if ( defined $c->request->params->{$field} ) {
      $c->model('Library')->set_setting( $field, $c->request->params->{$field} );
    }
  }

}

sub _submit {

  my ( $self, $c, $data ) = @_;

  $c->stash->{data}    = $data;
  $c->stash->{success} = 'true';

  $c->detach('Paperpile::View::JSON');
}

1;
