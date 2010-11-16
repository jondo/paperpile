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


package Paperpile::Formats::Bibtex;
use Moose;
use Data::Dumper;
use YAML qw/LoadFile/;
use IO::File;
use Text::Wrap;
use Paperpile::Formats::TeXEncoding;
use BibTeX::Parser;
use BibTeX::Parser::EncodingTable;
use Encode;
use File::Temp qw/tempfile tempdir/;
use File::Spec::Functions qw/catfile splitpath/;
use MIME::Base64;

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
        use_quotes           => 0,
        double_dash          => 1,
        title_quote_complete => 0,
        title_quote_smart    => 1,
        title_quote          => [ 'DNA', 'RNA' ],
        export_fields        => {
          abstract    => 0,
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

  # Keywords are handled special
  $built_in{keywords} = 0;

  my @output = ();
  my %warnings;

  my $parser = BibTeX::Parser->new( $fh, $self->settings->{import_strip_tex} );

  while ( my $entry = $parser->next ) {

    next unless $entry->parse_ok;

    # Collect meta data, $pdf file and attachments
    my $data        = {};
    my $pdf         = '';
    my @attachments = ();

    foreach my $field ( $entry->fieldlist ) {

      $field = lc($field);

      # 1:1 map between standard BibTeX fields and Paperpile fields
      if ( $built_in{$field} ) {
        my $content = $entry->field($field);
	# sometimes people code UTF-8 in bibtex, we have to decode it here
	$content = decode_utf8($content);
        if ( $field eq 'pages' ) {
          $content =~ s/--/-/g;
          $content =~ s/(.*)(\(\d+\))$/$1/;    # remove number of pages in braces
        }
        if ( $field eq 'doi' ) {
          # Normalize doi to just something like 10.1038/nature06340
          # without urls or anything else.
          $content =~ s/^doi://;
          $content =~ s!^(http://)?dx.doi.org/!!;
        }
        if ( $field eq 'year' ) {
          $content =~ s/(.*)(\d{4})$/$2/;
        }
        $data->{$field} = $content;
      }

      # Authors/Editors
      elsif ( $field eq 'author' || $field eq 'editor' ) {

        my $names = join( ' and ', $entry->$field );

	# sometimes people code UTF-8 in bibtex, we have to decode it here
	$names = decode_utf8($names);

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
        if ( $field =~ /(annote|comments?)/ ) {

          my $value = $entry->field($field);
	  # sometimes people code UTF-8 in bibtex, we have to decode it here
	  $value = decode_utf8($value);

          # Specifically handle CiteULike BibTex
          if ( $field eq 'comment' ) {
            $value =~ s/\(private-note\)//g;
            $value =~ s/---=note-separator=---/<br><br>/g;
          }

          $data->{annote} = $value;
          next;
        }

        if ( $field =~ /guid/ ) {
          $data->{guid} = $entry->field($field);
          next;
        }

        if ( $field =~ /(tags|labels|keywords)/ ) {

          my $tags = $entry->field($field);

          # Delimiter is generally either comma or semicolon. We
          # internally use commas, so we simply convert semicolons to
          # commas (ignoring more complex scenarios of having both
          # commas and semicolons)

          $tags=~s/;/,/g;

          $data->{labels_tmp} = $tags;
          next;
        }

        # File attachment. The convention seems to be that multiple
        # files are expected to be separated by semicolons and that
        # files are stored like this:
        # :/home/wash/PDFs/file.pdf:PDF

        if ( $field =~ /^file/i ) {
          my @files = split( /;/, $entry->field($field) );
          foreach my $file (@files) {

            $file = Paperpile::Utils->process_attachment_name($file);

            next if !$file;

            # We treat the first PDF we find  as *the* PDF and all
            # other files as supplementary material
            if ( ( $file =~ /\.pdf/i ) and ( !$pdf ) ) {
              $pdf = $file;
              next;
            } else {
              push @attachments, $file;
            }
          }
          next;
        }

        # Handle BibDesk file attachments. The file names are stored
        # as MIME64 encoded binary Mac property list file (argh!!)
        if ( $field =~ /Bdsk-File-\d+/i ) {

          my $dir = tempdir( CLEANUP => 1 );
          my ($fh, $tmp_file) = tempfile( DIR => $dir );

          # Get current directory of BibTeX file. All attachemnts seem
          # to be relative to this file.
          my ( $dummy, $base_dir, $dummy1 ) = splitpath($self->file);

          # First check if the "plutil" tool is available. This
          # implicitly checks whether we are on OSX.
          my $check = `which plutil`;
          chomp($check);
          if ($check eq '/usr/bin/plutil'){

            # First write the decoded plist file into a temporary file.
            print $fh decode_base64($entry->field($field)) || die("Could not write to tmp file");

            # Then convert the binary plist format to readable xml.
            my $xml = `plutil -convert xml1 $tmp_file -o -`;

            # I don't understand the XML format, so I just parse all
            # <string> tags and see if they contain a readable file
            while ($xml =~/<string>(.*?)<\/string>/mgi){
              my $file = catfile($base_dir, $1);
              if (-r $file){
                if ( ( $file =~ /\.pdf/i ) and ( !$pdf ) ) {
                  $pdf = $file;
                  next;
                } else {
                  push @attachments, $file;
                }
              }
            }
          } else {
            print STDERR "Skipping Bdsk-File. plutil executable not found.\n";
          }
          next;
        }

        # Warn only once for an unsupported field.
        if (!$warnings{$field}){
          print STDERR "Field $field not handled.\n";
          $warnings{$field}=1;
        }
      }

      $data->{_pdf_tmp} = $pdf if $pdf;

      if (@attachments) {
        $data->{_attachments_tmp} = [@attachments];
      }
    }

    my $type = $entry->type;

    my @pub_types = keys %{ $config->{pub_types} };

    if ( not $type ~~ [@pub_types] ) {
      $type = 'MISC';
    }

    # Sometimes booktitle is not correctly used, we override it here
    if ( $type eq 'BOOK' || $type eq 'INBOOK' ) {
      if ( ( !$data->{title} ) && ( $data->{booktitle} ) ) {
        $data->{title} = $data->{booktitle};
        delete $data->{booktitle};
      }
    }

    $data->{pubtype} = $type;
    $data->{citekey} = $entry->key;

    $data->{_light}        = 1;
    $data->{_auto_refresh} = 1;

    push @output, Paperpile::Library::Publication->new($data);

  }

  return [@output];

}

sub write {

  my ($self) = @_;

  my $left_quote  = ( $self->settings->{use_quotes} == 1 ) ? '"' : '{';
  my $right_quote = ( $self->settings->{use_quotes} == 1 ) ? '"' : '}';

  my $out_umlaute_string       = $BibTeX::Parser::EncodingTable::out_umlaute_string;
  my %out_umlaute_table        = %BibTeX::Parser::EncodingTable::out_umlaute_table;
  my $out_math_symbols_string  = $BibTeX::Parser::EncodingTable::out_math_symbols_string;
  my %out_math_symbols_table   = %BibTeX::Parser::EncodingTable::out_math_symbols_table;
  my $out_other_symbols_string = $BibTeX::Parser::EncodingTable::out_other_symbols_string;
  my %out_other_symbols_table  = %BibTeX::Parser::EncodingTable::out_other_symbols_table;

  # We always write these fields (if non-empty) because they are
  # needed by BibTeX to work correctly
  my @mandatory_fields = qw(sortkey title booktitle author editor
    address publisher organization school
    howpublished journal volume edition series number issue chapter pages
    year month day guid);

  # Non standard fields are only exported if set in the user settings.
  my @optional_fields = ();
  while ( my ( $key, $value ) = each( %{ $self->settings->{export_fields} } ) ) {
    push @optional_fields, $key if ( $value == 1 );
  }

  my @all_fields = ( @mandatory_fields, @optional_fields );

  open( OUT, ">" . $self->file )
    || FileWriteError->throw( error => "Could not write to file " . $self->file );

  foreach my $pub ( @{ $self->data } ) {

    # Collect all fields and get maximum width to align properly
    my %data;
    my $max_width = 0;
    foreach my $key (@all_fields) {
      my $value;
      # Note, there is a little discrepancy
      # In paperile we have 'authors' and 'editors'
      # while in Bibtex there is 'author' and 'editor'
      if ( $key eq 'author' ) {
	$value = $pub->authors();
      } elsif ( $key eq 'editor' ) {
	$value = $pub->editors();
      } else {
	$value = $pub->$key;
      }
      if ( $value ) {
        $data{$key} = $value;
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

        if ( $self->settings->{export_escape} == 1 ) {

          # before we do any conversion we convert
          # backslahes that are in the text to \textbackslash
          $value =~ s/\\/\\textbackslash/g;

          # curly braces are escaped
          $value =~ s/\{/\\\{/g if ( $key ne 'author' and $key ne 'editor' );
          $value =~ s/\}/\\\}/g if ( $key ne 'author' and $key ne 'editor' );
        }

        # this regexp replaces all umlaute symbols
        # this is always done as it is roundtrip safe
        $value =~ s{ ($out_umlaute_string)([\sa-zA-Z]?)}
              { my $encoded  = $out_umlaute_table{$1};
                my $nextchar = $2;
                my $sepchars = "";
                if ($nextchar and substr($encoded, -1) =~ /[a-zA-Z]/) {
                    $sepchars = ($nextchar =~ /\s/) ? '{}' : '';
                }
                "$encoded$sepchars$nextchar" }gxe;

        if ( $self->settings->{export_escape} == 1 ) {
          $value =~ s{ ($out_other_symbols_string)([\sa-zA-Z]?)}
              { my $encoded  = $out_other_symbols_table{$1};
                my $nextchar = $2;
                my $sepchars = "";
                if ($nextchar and substr($encoded, -1) =~ /[a-zA-Z]/) {
                    $sepchars = ($nextchar =~ /\s/) ? '{}' : '';
                }
                "$encoded$sepchars$nextchar" }gxe;
          $value =~ s{ ($out_math_symbols_string)([\sa-zA-Z]?)}
              { my $encoded  = '$'.$out_math_symbols_table{$1}.'$';
                my $nextchar = $2;
                my $sepchars = "";
                if ($nextchar and substr($encoded, -1) =~ /[a-zA-Z]/) {
                    $sepchars = ($nextchar =~ /\s/) ? '{}' : '';
                }
                "$encoded$sepchars$nextchar" }gxe;
        }

        # for the title we enclose special words in brackets
	if ( $key eq 'author' or $key eq 'editor' ) {
	  my @tmp = split(/\sand\s/, $value );
	  foreach my $i ( 0 .. $#tmp ) {
	    if ( $tmp[$i] !~ m/\w/ ) {
	      $tmp[$i] = '';
	      next;
	    }
	    $tmp[$i] = '{'.$tmp[$i].'}' if ( $tmp[$i] !~ m/,/ and $tmp[$i] !~ m/^\{.*\}$/);
	  }
	  $value = join(" and ", @tmp);
	}


        if ( $key eq 'title' or $key eq 'booktitle' ) {
          if ( $self->settings->{title_quote_complete} == 1 ) {
            $value = '{' . $value . '}';
          } else {
            my @tmp = split( /\s+/, $value );
            foreach my $i ( 0 .. $#tmp ) {

              # enclose if we have more than one upper case letter
              # in a single word
              my $nr_capital_letters = ( $tmp[$i] =~ tr/[A-Z]// );
              my $flag = ( $nr_capital_letters > 1 and $tmp[$i] !~ m/(\(|\)|\$|~)/ ) ? 1 : 0;
	      $flag = 1 if ( $tmp[$i] =~ m/^[A-Z\d-]+$/ and $tmp[$i] =~ m/[A-Z]/ );
              $flag = 0 if ( $tmp[$i] =~ m/^\{.*\}$/ );
              $flag = 0 if (!$self->settings->{title_quote_smart});
	      $flag = 0 if ( $tmp[$i] eq 'A' );

              # escape items from the list
              foreach my $item ( @{ $self->settings->{title_quote} } ) {
                $flag = 1 if ( $tmp[$i] eq $item );
              }

              if ( $flag == 1 ) {
                $tmp[$i] = '{' . $tmp[$i] . '}';
                if ( $tmp[$i] =~ m/(.*)(:|\.|,|\?|\!)\}$/ ) {
                  $tmp[$i] = $1 . '}' . $2;
                }
              }
            }
            $value = join( " ", @tmp );
          }
        }

	if ( $key eq 'pages' and $self->settings->{double_dash} == 1 ) {
	  $value =~ s/-/--/g;
	}

        # Wrap long fields and align the "=" sign
        if ( $self->settings->{pretty_print} == 1 ) {
          my $left = sprintf( "  %-" . ( $max_width + 2 ) . "s", $key ) . "= ";
          my $right = $value;
          $Text::Wrap::columns = 70;

          # if we have " in the regular text we have
          # to esacpe it with { }
          if ( $self->settings->{use_quotes} == 1 ) {
            $right =~ s/(?<!\\)"/\{"\}/g;
            $right =~ s/\{\{"\}\}/\{"\}/g;    # avoid double escapes
          }

          $right = wrap( $left, " " x ( $max_width + 7 ), $left_quote . $right . $right_quote );
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

