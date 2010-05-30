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

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('BIBTEX');
  $self->readable(1);
  $self->writable(1);
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

  my $parser = BibTeX::Parser->new( $fh, 1 );

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

        # File attachment. The convention seems to be that multiple
        # files are expected to be separated by semicolons and that
        # files are stored like this:
        # :/home/wash/PDFs/file.pdf:PDF

        if ( $field =~ /file/i ) {

          my @files       = split( /;/, $entry->field($field) );
          my $pdf         = '';
          my @attachments;
          foreach my $file (@files) {

            # Try to grap the actual path
            if ( $file =~ /^.*:(.*):.*$/ ) {
              $file = $1;
            }

            # Mendeley does not show the first '/'. Relative paths are
            # useless so if we don't find the file we try to make this absolute
            # by brute force TODO: make this work for Windows
            if ( !-e $file ) {
              $file = "/$file";
            }

            # If we still do not find a file, we give up
            if ( !-e $file || !-r $file ) {
              next;
            }

            # We treat the first PDF in the list as *the* PDF and all
            # other files as supplementary material
            if ( ( $file =~ /\.pdf/i ) and ( !$pdf ) ) {
              $data->{_pdf_tmp} = $file;
              next;
            } else {
              push @attachments, $file;
            }
          }
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

  my $bibtex_export_fields='annote,keywords,url,isbn,arxivid,doi,abstract,issn,eprint,lccn,note,pmid';
  my $bibtex_export_curly = 0;
  my $bibtex_export_pretty = 1;

  my $left_quote = '"';
  my $right_quote = '"';

  if ($bibtex_export_curly){
    $left_quote = '{';
    $right_quote = '}';
  }

  # We always write these fields (if non-empty) because they are
  # needed by BibTeX to work correctly
  my @mandatory_fields = qw(sortkey title booktitle authors editors
                            address publisher organization school
                            howpublished journal volume edition series number issue chapter pages
                            year month day);

  # Non standard fields are only exported if set in the user settings.
  my @optional_fields = split(/,/,$bibtex_export_fields);

  #linkout=>$url!!;

  foreach my $pub ( @{ $self->data } ) {

    my @all_fields = (@mandatory_fields, @optional_fields);

    # Collect all fields and get maximum width to align properly
    my %data;
    my $max_width = 0;
    foreach my $key (@all_fields){
      if ($pub->$key){
        $data{$key} = $pub->$key;
        $max_width = length($key) if (length($key)> $max_width);
      }
    }

    my @lines = ();
    foreach my $key (@all_fields){

      if (my $value = $data{$key}){
        # Wrap long fields and align the "=" sign
        if ($bibtex_export_pretty){
          my $left = sprintf("  %-".($max_width+2)."s", $key)."= ";
          my $right = $value;
          $Text::Wrap::columns=70;
          $right = wrap($left," "x($max_width+7),$left_quote.$right.$right_quote);
          push @lines, $right;
        }
        # Simple output one field per line
        else {
          push @lines, "$key = {$value}";
        }
      }
    }

    my ($type, $key) = ($pub->pubtype, $pub->citekey);

    # Write to STDOUT while testing

    print "\@$type\{$key,\n";
    print join(",\n", @lines);
    print "\n}\n\n";
  }
}


1;

