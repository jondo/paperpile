# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

package Paperpile::Formats::Bibtex;
use Moose;
use Data::Dumper;
use YAML qw(LoadFile);
use BibTeX::Parser;
use IO::File;
use Text::Wrap;
use Paperpile::Formats::TeXEncoding;
use Encode;

extends 'Paperpile::Formats';

sub BUILD {
  my ( $self, $args ) = @_;
  $self->format('BIBTEX');
  $self->readable(1);
  $self->writable(1);

  if ( not defined $args->{settings} ) {
    $self->settings( {
        import_strip_tex     => 1,
        export_escape        => 1,
        pretty_print         => 1,
        use_quotes           => 1,
        double_dash          => 1,
        title_quote_complete => 0,
        title_quote          => [ 'DNA', 'RNA' ],
        export_fields        => {
          abstract    => 1,
          affiliation => 0,
          eprint      => 0,
          issn        => 0,
          isbn        => 0,
          pmid        => 1,
          lccn        => 0,
          doi         => 1,
          keywords    => 0
        }
      }
    );
  }
}


sub read {

  my ($self) = @_;

  my $fh = IO::File->new( $self->file );

  my $config = LoadFile( Paperpile::Utils->path_to('conf/fields.yaml') );

  my %built_in = ();

  foreach my $field ( keys %{ $config->{pub_fields} } ) {
    $built_in{$field} = 1;
  }

  my @output = ();

  my $parser = BibTeX::Parser->new( $fh, $self->settings->{import_strip_tex} );

  while ( my $entry = $parser->next ) {

    next unless $entry->parse_ok;

    my $data = {};

    foreach my $field ( $entry->fieldlist ) {

      $field = lc($field);

      # 1:1 map between standard BibTeX fields and Paperpile fields
      if ( $built_in{$field} ) {
        $data->{$field} = $entry->field($field);
      }

      # Authors/Editors
      elsif ( $field eq 'author' || $field eq 'editor' ) {

        my $names = join( ' and ', $entry->$field );

        if ( $field eq 'author' ) {
          $data->{authors} = $names;
        }

        if ( $field eq 'editor' ) {
          $data->{editors} = $names;
        }
      }

      # Put other non-standard fields here
      else {
        if ( $field =~ /arxiv/ ) {
          $data->{arxivid} = $entry->field($field);
          next;
        }

        # annote is not defined in fields.yaml but in library.sql
        if ( $field =~ /annote/ ) {
          $data->{annote} = $entry->field($field);
          next;
        }

        if ( $field =~ /guid/ ) {
          $data->{guid} = $entry->field($field);
          next;
        }


        # File attachment. The convention seems to be that multiple
        # files are expected to be separated by semicolons and that
        # files are stored like this:
        # :/home/wash/PDFs/file.pdf:PDF

        if ( $field =~ /file/i ) {
          my @files       = split( /;/, $entry->field($field) );
          my $pdf         = '';
          my @attachments;

          foreach my $file (@files) {

            $file = Paperpile::Utils->process_attachment_name($file);

            next if !$file;

            # We treat the first PDF in the list as *the* PDF and all
            # other files as supplementary material
            if ( ( $file =~ /\.pdf/i ) and ( !$pdf ) ) {
              $pdf = $file;
              next;
            } else {
              push @attachments, $file;
            }
          }

          $data->{_pdf_tmp} = $pdf if $pdf;

          if (@attachments){
            $data->{_attachments_tmp} = [@attachments];
          }

          next;
        }

        print STDERR "Field $field not handled.\n";
      }
    }

    my $type = $entry->type;

    my @pub_types = keys %{ $config->{pub_types} };

    if ( not $type ~~ [@pub_types] ) {
      $type = 'MISC';
    }

    $data->{pubtype} = $type;
    $data->{citekey} = $entry->key;

    $data->{_light}        = 1;
    $data->{_auto_refresh} = 1;

    push @output, Paperpile::Library::Publication->new($data);

  }

  #print STDERR Dumper(\@output);

  return [@output];

}

sub write {

  my ($self) = @_;

  my $bibtex_export_fields =
    'annote,keywords,url,isbn,arxivid,doi,abstract,issn,eprint,lccn,note,pmid';
  my $bibtex_export_curly  = 0;
  my $bibtex_export_pretty = 1;

  my $left_quote  = '"';
  my $right_quote = '"';

  my $enc            = $Paperpile::Formats::TeXEncoding::encoded_chars;
  my %latex_encoding = %Paperpile::Formats::TeXEncoding::encoding_table;

  if ($bibtex_export_curly) {
    $left_quote  = '{';
    $right_quote = '}';
  }

  # We always write these fields (if non-empty) because they are
  # needed by BibTeX to work correctly
  my @mandatory_fields = qw(sortkey title booktitle authors editors
    address publisher organization school
    howpublished journal volume edition series number issue chapter pages
    year month day guid);

  # Non standard fields are only exported if set in the user settings.
  my @optional_fields = split( /,/, $bibtex_export_fields );

  #linkout=>$url!!;
  open( OUT, ">" . $self->file )
    || FileReadError->throw( error => "Could not write to file " . $self->file );

  foreach my $pub ( @{ $self->data } ) {
    my @all_fields = ( @mandatory_fields, @optional_fields );

    # Collect all fields and get maximum width to align properly
    my %data;
    my $max_width = 0;
    foreach my $key (@all_fields) {
      if ( $pub->$key ) {
        $data{$key} = $pub->$key;
        $max_width = length($key) if ( length($key) > $max_width );
      }
    }

    my @lines = ();
    foreach my $key (@all_fields) {

      if ( my $value = $data{$key} ) {
        $value =~ s/\s+/ /g;

        # UTF-8 to TeX conversion
        # decode_utf8 has to be called first
        # I do not know why this is necessary, but it does not
        # work without
        $value = decode_utf8($value);

        # this regexp replaces the characters
        $value =~ s{ ($enc)([\sa-zA-Z]?)}
              { my $encoded  = $latex_encoding{$1};
                my $nextchar = $2;
                my $sepchars = "";
                if ($nextchar and substr($encoded, -1) =~ /[a-zA-Z]/) {
                    $sepchars = ($nextchar =~ /\s/) ? '{}' : '';
                }
                "$encoded$sepchars$nextchar" }gxe;

        # for the title we enclose special words
        # in brackets
        if ( $key eq 'title' or $key eq 'booktitle' ) {
          my @tmp = split( /\s+/, $value );
          my $nr_upper_case = 0;
          foreach my $i ( 1 .. $#tmp ) {
            $nr_upper_case++ if ( $tmp[$i] =~ m/^[A-Z]/ );
          }

          foreach my $i ( 0 .. $#tmp ) {

            # enclose if we have more than one upper case letter
            # in a single word
            my $nr_capital_letters = ( $tmp[$i] =~ tr/[A-Z]// );

            # enclose if it is a one letter abbr.
            my $flag = ( $tmp[$i] =~ m/^[A-Z]\.$/ ) ? 1 : 0;

            # enclose if there are only a few upper case words
            if ( $i > 0 and $nr_upper_case / ( $#tmp + 1 ) < 0.25 ) {
              $flag = 1 if ( $tmp[$i] =~ m/^[A-Z]/ and $tmp[ $i - 1 ] !~ m/\./ );
            }
            $flag = 1 if ( $tmp[$i] =~ m/^[A-Z]/ and $tmp[$i] =~ m/-/ );
            $flag = 1 if ( $tmp[$i] =~ m/^[A-Z]$/ );
            $flag = 1 if ( $tmp[$i] =~ m/[A-Z]/ and $tmp[$i] =~ m/\d/ );
            $flag = 0 if ( $tmp[$i] eq 'A' );
            if ( $nr_capital_letters > 1 or $flag == 1 ) {
              $tmp[$i] = '{' . $tmp[$i] . '}';
              if ( $tmp[$i] =~ m/(.*)(:|\.|,|\?|\!)\}$/ ) {
                $tmp[$i] = $1 . '}' . $2;
              }
            }
          }
          $value = join( " ", @tmp );
        }

        # Wrap long fields and align the "=" sign
        if ($bibtex_export_pretty) {
          my $left = sprintf( "  %-" . ( $max_width + 2 ) . "s", $key ) . "= ";
          my $right = $value;
          $Text::Wrap::columns = 70;

          # if we have " in the regular text we change to { } as
          # field marks. We do not count \".
          if ( $value =~ m/(?<!\\)"/ ) {
            $right = wrap( $left, " " x ( $max_width + 7 ), '{' . $right . '}' );
          } else {
            $right = wrap( $left, " " x ( $max_width + 7 ), $left_quote . $right . $right_quote );
          }
          push @lines, $right;
        }

        # Simple output one field per line
        else {
          push @lines, "$key = {$value}";
        }
      }
    }

    my ( $type, $key ) = ( $pub->pubtype, $pub->citekey );

    print OUT "\@$type\{$key,\n";
    print OUT join( ",\n", @lines );
    print OUT "\n}\n\n";
  }
  close(OUT);
}


1;

