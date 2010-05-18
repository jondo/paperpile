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

  my $parser = BibTeX::Parser->new($fh, 1);

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

        my $names = join(' and ',  $entry->$field);

        if ( $field eq 'author' ) {
          $data->{authors} = $names;
        }

        if ( $field eq 'editor' ) {
          $data->{editors} = $names;
        }
      }
      # Put other non-standard fields here
      else {
        if ($field =~ /arxiv/){
          $data->{arxivid} = $entry->$field;
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

  my $bibtex_export_fields='annote, keywords,url,isbn,arxivid,doi,abstract,issn,eprint,lccn,note,pmid';
  my $bibtex_export_curly = 0;
  my $bibtex_export_pretty = 1;

  my $left_quote = '"';
  my $right_quote = '"';

  if ($bibtex_export_curly){
    $left_quote = '{';
    $right_quote = '}';
  }

  my @mandatory_fields = qw(sortkey title booktitle authors editors
                            address publisher organization school
                            howpublished journal volume edition series number issue chapter pages
                            year month day);

  my @optional_fields = split(/,/,$bibtex_export_fields);

  #linkout=>$url!!;

  foreach my $pub ( @{ $self->data } ) {

    my @all_fields = (@mandatory_fields, @optional_fields);

    my $max_width = 0;

    my %data;

    foreach my $key (@all_fields){
      if ($pub->$key){
        $data{$key} = $pub->$key;
        $max_width = length($key) if (length($key)> $max_width);
      }
    }

    my @lines = ();

    foreach my $key (@all_fields){

      #my $max_width = 12;

      if (my $value = $data{$key}){

        if ($bibtex_export_pretty){
          my $left = sprintf("  %-".($max_width+2)."s", $key)."= ";
          my $right = $value;
          $Text::Wrap::columns=70;
          $right = wrap($left," "x($max_width+7),$left_quote.$right.$right_quote);

          push @lines, $right;
        } else {
          push @lines, "$key = {$value}";
        }
      }

    }

    my ($type, $key) = ($pub->pubtype, $pub->citekey);

    print "\@$type\{$key,\n";
    print join(",\n", @lines);
    print "\n}\n\n";
  }
}


1;

