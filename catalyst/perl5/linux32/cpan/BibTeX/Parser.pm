package BibTeX::Parser;
our $VERSION = '0.4';

# ABSTRACT: A pure perl BibTeX parser
use warnings;
use strict;
use Encode;

use BibTeX::Parser::Entry;

=for stopwords jr von

=head1 NAME

BibTeX::Parser - A pure perl BibTeX parser

=head1 VERSION

version 0.4

=cut

my $re_namechar = qr/[a-zA-Z0-9\!\$\&\*\+\-\.\/\:\;\<\>\?\[\]\^\_\`\|]/o;
my $re_name     = qr/$re_namechar+/o;

=head1 SYNOPSIS

Parses BibTeX files.

    use BibTeX::Parser;
    use IO::File;

    my $doLaTeXcleaning = 1;
    my $fh     = IO::File->new("filename", $doLaTeXcleaning);

    # Create parser object ...
    my $parser = BibTeX::Parser->new($fh);

    # ... and iterate over entries
    while (my $entry = $parser->next ) {
	    if ($entry->parse_ok) {
		    my $type    = $entry->type;
		    my $title   = $entry->field("title");

		    my @authors = $entry->author;
		    # or:
		    my @editors = $entry->editor;

		    foreach my $author (@authors) {
			    print $author->first . " "
			    	. $author->von . " "
				. $author->last . ", "
				. $author->jr;
		    }
	    } else {
		    warn "Error parsing file: " . $entry->error;
	    }
    }


=head1 FUNCTIONS

=head2 new

Creates new parser object.

Parameters:

	* fh: A filehandle

=cut

sub new {
  my ( $class, $fh, $cleaning_flag ) = @_;

  $cleaning_flag = (!$cleaning_flag) ? $cleaning_flag : 1;

  return bless {
    fh      => $fh,
    strings => {
      jan => "January",
      feb => "February",
      mar => "March",
      apr => "April",
      may => "May",
      jun => "June",
      jul => "July",
      aug => "August",
      sep => "September",
      oct => "October",
      nov => "November",
      dec => "December",

    },
    line       => -1,
    buffer     => "",
    cleanLaTeX => $cleaning_flag
  }, $class;
}

sub _slurp_close_bracket;

sub _parse_next {
  my $self = shift;

  while (1) {    # loop until regular entry is finished
    return 0 if $self->{fh}->eof;
    local $_ = $self->{buffer};

    until (/@/m) {
      my $line = $self->{fh}->getline;
      return 0 unless defined $line;
      # there are a lot of malformed bibtex files 
      # out there. If we find a bracket before the 
      # entry, we simply ignore it
      next if ( $line =~ m/^\s*\}\s*\n$/ );
      next if ( $line =~ m/^%/ );
      $_ .= $line;
    }

    my $current_entry = new BibTeX::Parser::Entry;
    if (/@($re_name)/cgo) {
      #print STDERR "$_\n";
      my $type = uc $1;
      $current_entry->type($type);
      my $start_pos = pos($_) - length($type) - 1;

      # read rest of entry (matches braces)
      my $bracelevel = 0;
      $bracelevel += _count_braces_left($_);    #count braces
      $bracelevel -= _count_braces_right($_);
      while ( $bracelevel != 0 ) {
        my $position = pos($_);
	my $backup_pos = $self->{fh}->getpos;
        my $line     = $self->{fh}->getline;
        last unless defined $line;
	# sometimes there are missing braces
	# we also stopp if we see that a next
	# entry starts already
	if ( $line =~ m/^\s*@(article|book|booklet|conference|inbook|incollection|inproceedings|manual|mastersthesis|misc|phdthesis|proceedings|techreport|unpublished|comment|string)/i ) {
	  $self->{fh}->setpos($backup_pos);
	  last;
	}
	$bracelevel += _count_braces_left($line);
	$bracelevel -= _count_braces_right($line);

        $_ .= $line;
        pos($_) = $position;
      }

      # Remember raw bibtex code
      my $raw = substr( $_, $start_pos );
      if ( $bracelevel > 0 ) {
	print STDERR "This entry is not correctly formatted and will";
	print STDERR " be skipped.\n$raw\n";
	next;
      }

      $raw =~ s/^\s+//;
      $raw =~ s/\s+$//;
      $raw = encode_utf8($raw);
      $current_entry->raw_bibtex($raw);

      my $pos = pos $_;
      tr/\n/ /;
      pos($_) = $pos;

      if ( $type eq "STRING" ) {
        if (/\G{\s*($re_name)\s*=\s*/cgo) {
          my $key   = $1;
          my $value = _parse_string( $self->{strings} );
          if ( defined $self->{strings}->{$key} ) {
            warn("Redefining string $key!");
          }
          $self->{strings}->{$key} = $value;
          /\G[\s\n]*\}/cg;
        } else {
          $current_entry->error("Malformed string!");
          return $current_entry;
        }
      } elsif ( $type eq "COMMENT" or $type eq "PREAMBLE" ) {
        /\G\{./cgo;
        _slurp_close_bracket;
      } else {    # normal entry
        $current_entry->parse_ok(1);

        # parse key
        if (/\G\{\s*($re_name),[\s\n]*/cgo) {
          $current_entry->key($1);

          # fields
          while (/\G[\s\n]*($re_name)[\s\n]*=[\s\n]*/cgo) {
            $current_entry->field( $1 => _parse_string( $self->{strings} ), $self->{cleanLaTeX} );
            my $idx = index( $_, ',', pos($_) );
            pos($_) = $idx + 1 if $idx > 0;
          }

          return $current_entry;

        } else {

          $current_entry->error( "Malformed entry (key contains illegal characters) at "
              . substr( $_, pos($_) || 0, 20 )
              . ", ignoring" );
          _slurp_close_bracket;
          return $current_entry;
        }
      }

      $self->{buffer} = substr $_, pos($_);

    } else {
      $current_entry->error( "Did not find type at " . substr( $_, pos($_) || 0, 20 ) );
      return $current_entry;
    }

  }
}

# helper functions to count NON-ESCAPED braces
# simply doing a tr/\{/\{/ also counts
# escaped braces which leads to incorrect parsing
sub _count_braces_left {
  my $string = $_[0];

  my $count = 0;
  while ( $string =~ m/(?<!\\)\{/g ) {
    $count++;
  }

  return $count;

}

sub _count_braces_right {
  my $string = $_[0];

  my $count = 0;
  while ( $string =~ m/(?<!\\)\}/g ) {
    $count++;
  }

  return $count;
}



=head2 next

Returns the next parsed entry or undef.

=cut

sub next {
  my $self = shift;

  return $self->_parse_next;
}

# slurp everything till the next closing brace. Handels
# nested brackets
sub _slurp_close_bracket {
  my $bracelevel = 0;
BRACE: {
    /\G[^\}]*\{/cg && do { $bracelevel++; redo BRACE };
    /\G[^\{]*\}/cg
      && do {
      if ( $bracelevel > 0 ) {
        $bracelevel--;
        redo BRACE;
      } else {
        return;
      }
      }
  }
}

# parse bibtex string in $_ and return. A BibTeX string is either enclosed
# in double quotes '"' or matching braces '{}'. The braced form may contain
# nested braces.
sub _parse_string {
  my $strings_ref = shift;
  my $value = "";

  #foreach my $key ( keys %{$strings_ref} ) {
  #  print STDERR $key," ",$strings_ref->{$key},"\n";
  #}

PART: {

    if (/\G(\d+)/cg) {
      $value .= $1;
    } elsif (/\G($re_name)/cgo) {
      #warn("Using undefined string $1") unless defined $strings_ref->{$1};
      $value .= $strings_ref->{$1} || "$1";
    #} elsif (/\G"(([^"\\]*(\\.)*[^\\"]*)*)"/cgs) {
    } elsif (/\G"/cgs) {
      # if the entry starts with quotes, we earch for the next
      # quotes that have a local braces level of 0
      # Used to be a bug in the original CPAN module
      my $start_pos = pos($_);
      while ( m/(?<!\\)"/g ) {
	my $act_pos = pos($_);
	my $a = substr($_,$start_pos, ($act_pos-$start_pos));
	my $brace_level = _count_braces_left($a) - _count_braces_right($a);
	last if ( $brace_level == 0 );
      }
      my $last_pos = pos($_)-1;
      my $tmp_val = substr($_,$start_pos, ($last_pos-$start_pos));
      # we use an exact match here to grab the value from the hash
      # I have to lookup in the bibtex manual how @STRING
      # is handled correctly
      $value .= $strings_ref->{$tmp_val} || $tmp_val;
      
    } else {
      my $part = _extract_bracketed($_);
      $value .= substr $part, 1, length($part) - 2;
      # strip quotes
    }

    if (/\G\s*#\s*/cg) {

      # string concatenation by #
      redo PART;
    }
  }
  $value =~ s/[\s\n]+/ /g;

  return $value;
}

sub _extract_bracketed {

  # alias to $_
  for ( $_[0] ) {
    /\G\s+/cg;
    my $start = pos($_);
    my $depth = 0;
    while (1) {
      /\G\\./cg          && next;
      /\G\{/cg           && ( ++$depth, next );
      /\G\}/cg           && ( --$depth > 0 ? next : last );
      /\G([^\\\{\}]+)/cg && next;

      # end of string
      last;
    }
    return substr( $_, $start, pos($_) - $start );
  }
}

1;
