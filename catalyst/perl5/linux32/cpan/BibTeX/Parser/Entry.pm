package BibTeX::Parser::Entry;
our $VERSION = '0.4';

use warnings;
use strict;
use Encode;
use charnames ':full';

use BibTeX::Parser::Author;
use BibTeX::Parser::Defly;

=head1 NAME

BibTeX::Entry - Contains a single entry of a BibTeX document.

=head1 VERSION

version 0.4

=cut

=head1 SYNOPSIS

This class ist a wrapper for a single BibTeX entry. It is usually created
by a BibTeX::Parser.


    use BibTeX::Parser::Entry;

    my $entry = BibTeX::Parser::Entry->new($type, $key, $parse_ok, \%fields);

    if ($entry->parse_ok) {
	    my $type    = $entry->type;
	    my $key     = $enty->key;
	    print $entry->field("title");
	    my @authors = $entry->author;
	    my @editors = $entry->editor;

	    ...
    }

=head1 FUNCTIONS

=head2 new

Create new entry.

=cut

sub new {
  my ( $class, $type, $key, $parse_ok, $fieldsref ) = @_;

  my %fields = defined $fieldsref ? %$fieldsref : ();
  $fields{_type}     = uc($type);
  $fields{_key}      = $key;
  $fields{_parse_ok} = $parse_ok;
  $fields{_raw}      = '';
  return bless \%fields, $class;
}


=head2 parse_ok

If the entry was correctly parsed, this method returns a true value, false otherwise.

=cut

sub parse_ok {
  my $self = shift;
  if (@_) {
    $self->{_parse_ok} = shift;
  }
  $self->{_parse_ok};
}

=head2 error

Return the error message, if the entry could not be parsed or undef otherwise.

=cut

sub error {
  my $self = shift;
  if (@_) {
    $self->{_error} = shift;
    $self->parse_ok(0);
  }
  return $self->parse_ok ? undef : $self->{_error};
}

=head2 type

Get or set the type of the entry, eg. 'ARTICLE' or 'BOOK'. Return value is 
always uppercase.

=cut

sub type {
  if ( scalar @_ == 1 ) {

    # get
    my $self = shift;
    return $self->{_type};
  } else {

    # set
    my ( $self, $newval ) = @_;
    $self->{_type} = uc($newval);
  }
}

=head2 key

Get or set the reference key of the entry.

=cut

sub key {
  if ( scalar @_ == 1 ) {

    # get
    my $self = shift;
    return $self->{_key};
  } else {

    # set
    my ( $self, $newval ) = @_;
    $self->{_key} = $newval;
  }

}

=head2 field($name [, $value])

Get or set the contents of a field. The first parameter is the name of the
field, the second (optional) value is the new value. The third (optional) value
tells wheter to clean (1) the field from LaTeX commands or not (0). Default is
cleaning enabled.

=cut

sub field {
  if ( scalar @_ == 2 ) {

    # get
    my ( $self, $field ) = @_;
    return $self->{ lc($field) };
  } else {
    my ( $self, $key, $value, $clean ) = @_;
    $clean = 1 if ( !$clean );
    # different cleaning level for authors
    $clean = 2 if ( lc($key) eq 'author'  );
    $self->{ lc($key) } = _sanitize_field( $value, $clean );
  }

}

sub _handle_author_editor {
  my $type = shift;
  my $self = shift;
  if (@_) {
    if ( @_ == 1 ) {    #single string
      my @names = _split_author_field( $_[0] );
      $self->{"_$type"} = [ map { new BibTeX::Parser::Author $_} @names ];
      $self->field( $type, join " and ", @{ $self->{"_$type"} } );
    } else {
      $self->{"_$type"} = [];
      foreach my $param (@_) {
        if ( ref $param eq "BibTeX::Author" ) {
          push @{ $self->{"_$type"} }, $param;
        } else {
          push @{ $self->{"_$type"} }, new BibTeX::Parser::Author $param;
        }

        $self->field( $type, join " and ", @{ $self->{"_$type"} } );
      }
    }
  } else {
    unless ( defined $self->{"_$type"} ) {
      my @names = _split_author_field( $self->{$type} || "" );
      $self->{"_$type"} = [ map { new BibTeX::Parser::Author $_} @names ];
    }
    return @{ $self->{"_$type"} };
  }
}

# _split_author_field($field)
#
# Split an author field into different author names.
# Handles quoted names ({name}).
sub _split_author_field {
  my $field = shift;

  return () if !defined $field || $field eq '';

  # real world Bibtex data can be a mess
  # we do some cleaning of standard typos
  $field =~ s/\sand\sand\s/ and /g;
  $field =~ s/\sand(?=[A-Z])/ and /g;
  $field =~ s/(?<=\.)and\s/ and /g;
  $field =~ s/(?<=\.)\sad\s(?=[A-Z])/ and /g;

  my @names;
  my @tmp     = split( /\s+/, $field );
  my @buffer  = ();
  my $opening = 0;
  my $closing = 0;
  foreach my $word (@tmp) {
    my $count_opening = ( $word =~ tr/\{// );
    my $count_closing = ( $word =~ tr/\}// );
    $opening += $count_opening;
    $closing += $count_closing;
    if ( $word eq 'and' and $opening == $closing ) {
      push @names, join( " ", @buffer );
      @buffer = ();
    } else {
      push @buffer, $word;
    }
  }
  push @names, join( " ", @buffer ) if ( $#buffer > -1 );

  return @names;
}

=head2 author([@authors])

Get or set the authors. Returns an array of L<BibTeX::Author|BibTeX::Author> 
objects. The parameters can either be L<BibTeX::Author|BibTeX::Author> objects
or strings.

Note: You can also change the authors with $entry->field('author', $authors_string)

=cut

sub author {
	_handle_author_editor('author', @_);
}

=head2 editor([@editors])

Get or set the editors. Returns an array of L<BibTeX::Author|BibTeX::Author> 
objects. The parameters can either be L<BibTeX::Author|BibTeX::Author> objects
or strings.

Note: You can also change the authors with $entry->field('editor', $editors_string)

=cut

sub editor {
	_handle_author_editor('editor', @_);
}

=head2 fieldlist()

Returns a list of all the fields used in this entry.

=cut

sub fieldlist {
  my $self = shift;

  return grep { !/^_/ } keys %$self;
}

=head2 has($fieldname)

Returns a true value if this entry has a value for $fieldname.

=cut

sub has {
  my ( $self, $field ) = @_;

  return defined $self->{$field};
}

sub uchr {
  my($c) = @_;
  encode_utf8(chr($c));
}

sub _sanitize_field {
  my $value = shift;
  my $clean = shift;

  # some cleaning before UTF-8 conversion
  if ( $clean >= 1 ) {
    $value =~ s/\\~\{\}/~/g;
    $value =~ s/\\\././g;
  }

  # char conversion from LaTeX to UTF-8
  $value = defly $value;
  # do more LaTeX parsing here, not everything
  # is covered by defly
  if ( $clean >= 1 ) {
    $value =~ s/\\textit//g;
    $value =~ s/\\textbf//g;
    $value =~ s/\\textsl//g;
    $value =~ s/\\textsc//g;
    $value =~ s/\\textsf//g;
    $value =~ s/\\texttt//g;
    $value =~ s/\\textsubscript//g;
    $value =~ s/\\textsuperscript//g;
    $value =~ s/\\emph//g;
    $value =~ s/\\mbox//g;
    $value =~ s/\\url//g;
    $value =~ s/\\it //g;
    $value =~ s/\\em //g;
    $value =~ s/\\emph//g;
    $value =~ s/\\%/%/g;
    $value =~ s/\\\$/\$/g;
    $value =~ s/\\&/&/g;
    $value =~ s/\\#/#/g;
    $value =~ s/\\_/_/g;
    $value =~ s/\\pounds/encode_utf8("\N{POUND SIGN}")/ge;
    $value =~ s/\\texttimes/uchr(hex('d7'))/ge;
    $value =~ s/\?`/uchr(hex('bf'))/ge;
    $value =~ s/\!`/uchr(hex('a1'))/ge;
    $value =~ s/\$<\$/</g;
    $value =~ s/\$>\$/>/g;
    $value =~ s/\\texttildelow/~/g;
    $value =~ s/\\textdollar/\$/g;
    $value =~ s/\\textunderscore/_/g;
    $value =~ s/\$\\backslash\$/\\/g;
    $value =~ s/\\\s/ /g;
    $value =~ s/\s+/ /g;
    $value =~ s/\\\{/**PPRPILEOPEN**/g;
    $value =~ s/\\\}/**PPRPILECLOSE**/g;
    $value =~ s/{//g if ( $clean == 1);
    $value =~ s/}//g if ( $clean == 1);
    $value =~ s/\*\*PPRPILEOPEN\*\*/{/g;
    $value =~ s/\*\*PPRPILECLOSE\*\*/}/g;
  }

  return $value;
}


=head2 raw_bibtex

Return raw BibTeX entry (if available).

=cut

sub raw_bibtex {
  my $self = shift;
  if (@_) {
    $self->{_raw} = shift;
  }
  return $self->{_raw};
}

1; # End of BibTeX::Entry
