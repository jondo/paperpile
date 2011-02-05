package BibTeX::Parser::Author;
our $VERSION = '0.4';

use warnings;
use strict;

use overload
	'""' => \&to_string;

=head1 NAME

BibTeX::Author - Contains a single author for a BibTeX document.

=head1 VERSION

version 0.4

=cut

=head1 SYNOPSIS

This class ist a wrapper for a single BibTeX author. It is usually created
by a BibTeX::Parser.


    use BibTeX::Parser::Author;

    my $entry = BibTeX::Parser::Author->new($full_name);

    my $firstname = $author->first;
    my $von	  = $author->von;
    my $last      = $author->last;
    my $jr	  = $author->jr;

    # or ...

    my ($first, $von, $last, $jr) = BibTeX::Author->split($fullname);


=head1 FUNCTIONS

=head2 new

Create new author object. Expects full name as parameter.

=cut

sub new {
  my $class = shift;

  if (@_) {
    my $self = [ $class->split(@_) ];
    return bless $self, $class;
  } else {
    return bless [], $class;
  }
}

sub _get_or_set_field {
  my ( $self, $field, $value ) = @_;
  if ( defined $value ) {
    $self->[$field] = $value;
  } else {
    return if ( ! $self->[$field] );
    # some final cleaning
    # remove curly brackets around a single letter
    (my $tmp = $self->[$field]) =~ s/\{(\S)\}/$1/g;
    # remove bracktes enclosing the whole word
    if ( $tmp =~ m/^\{([^\{\}]+)\}$/ ) {
      $tmp = $1;
    }
    $tmp =~ s/~/ /g;
    $tmp =~ s/^\s+//g;
    $tmp =~ s/\s+$//g;
    return $tmp;
  }
}

=head2 first

Set or get first name(s).

=cut

sub first {
  shift->_get_or_set_field( 0, @_ );
}

=head2 von

Set or get 'von' part of name.

=cut

sub von {
  shift->_get_or_set_field( 1, @_ );
}

=head2 last

Set or get last name(s).

=cut

sub last {
  shift->_get_or_set_field( 2, @_ );
}

=head2 jr

Set or get 'jr' part of name.

=cut

sub jr {
  shift->_get_or_set_field( 3, @_ );
}

=head2 collective

Set or get collective name.

=cut

sub collective {
  shift->_get_or_set_field( 4, @_ );
}


sub _get_name_parts {
  my $name = $_[0];

  my @name_parts   = ();
  my $braces_level = 0;
  my @tmp = split( /\s+/, $name );

  foreach my $i ( 0 .. $#tmp ) {
    my $o = ( $tmp[$i] =~ tr/\{// );
    my $c = ( $tmp[$i] =~ tr/\}// );

    #print STDERR " $tmp[$i] $braces_level\n";

    if ( $braces_level + $o - $c == 0 and $braces_level > 0 ) {
      $tmp[$i] =~ s/(\{|\})//g;
      if ( $#name_parts > -1 ) {
        $name_parts[$#name_parts] .= " $tmp[$i]";
      } else {
        push @name_parts, $tmp[$i];
      }
      $braces_level += $o - $c;
      next;
    }
    if ( $braces_level > 0 ) {
      $tmp[$i] =~ s/(\{|\})//g;
      $name_parts[$#name_parts] .= " $tmp[$i]";
      $braces_level += $o - $c;
      next;
    }

    if ( $braces_level == 0 ) {
      $tmp[$i] =~ s/(\{|\})//g;
      push @name_parts, $tmp[$i];
    }
    $braces_level += $o - $c;
  }

  return @name_parts;
}

=head2 split

Split name into (firstname, von part, last name, jr part). Returns array
with four strings, some of them possibly empty.

=cut

sub split {
  my ( $self_or_class, $name ) = @_;

  $name =~ s/(.*\S)\{(\s.*)/$1 \{$2/g;

  # remove whitespace at start and end of string
  $name =~ s/^\s*(.*)\s*$/$1/s;

  # everything is totally enclosed in curly brackets
  # treat it as collective name
  if ( $name =~ m/^\{([^\{\}]+)\}$/ ) {
    return ( undef, undef, undef, undef, $1 );
  }

  # This simple split does not work, because
  # commas in braces are not considered correctly
  # we now do a split in a while loop and control
  # the braces nesting level of each comma
  #my @parts = split /\s*,\s*/, $name;

  my @parts  = ();
  my $last_one = 0;
  while ( $name =~ m/,/g ) {
    my $current = pos($name);
    my $left_part = substr( $name, $last_one, $current - 1 -$last_one );
    my $bracelevel = _count_braces_left($left_part) -
      _count_braces_right($left_part);
    if ( $bracelevel == 0 ) {
      push @parts, $left_part;
      $last_one = $current;
    }
  }

  # now add the last part
  my $last_part = substr( $name, $last_one, length($name) - $last_one );
  push @parts, $last_part;

  if ( $#parts == -1 ) {
    # nothing in the string
    return ( undef, undef, undef, undef, undef );
  } elsif ( $#parts == 0 ) {    # name without comma
    my @name_parts = _get_name_parts($name);

    my $do_von_parsing = 0;
    foreach my $part ( @name_parts ) {
      $do_von_parsing = 1 if ( $part =~ m/^[[:lower:]]/ );
    }

    if ( $do_von_parsing == 1 ) {    # name has von part or has only lowercase names
      my $first;
      while ( @name_parts && ucfirst( $name_parts[0] ) eq $name_parts[0] ) {
        $first .= $first ? ' ' . shift @name_parts : shift @name_parts;
      }

      my $von;

      # von part are lowercase words
      while ( @name_parts && lc( $name_parts[0] ) eq $name_parts[0] ) {
        $von .= $von ? ' ' . shift @name_parts : shift @name_parts;
      }

      if (@name_parts) {
        return ( $first, $von, join( " ", @name_parts ), undef, undef );
      } else {
        return ( undef, undef, $name, undef, undef );
      }
    } else {
      # regular case
      my $last = pop @name_parts;
      my $first = join(" ", @name_parts);
      return ( $first, undef, $last, undef, undef );
    }

  } elsif ( $#parts == 1 ) {
    my @von_last_parts = _get_name_parts($parts[0]);
    my $von;
    # von part are lowercase words
    while ( $von_last_parts[0] =~ m/^[a-z]/ ) {
      $von .= $von ? ' ' . shift @von_last_parts : shift @von_last_parts;
      last if ( ! $von_last_parts[0] );
    }
    return ( $parts[1], $von, join( " ", @von_last_parts ), undef, undef );
  } else {
    my @von_last_parts = _get_name_parts($parts[0]);
    my $von;

    # von part are lowercase words
    while ( lc( $von_last_parts[0] ) eq $von_last_parts[0] ) {
      $von .= $von ? ' ' . shift @von_last_parts : shift @von_last_parts;
    }
    return ( $parts[2], $von, join( " ", @von_last_parts ), $parts[1], undef );
  }

}

=head2 to_string

Return string representation of the name.

=cut

sub to_string {
  my $self = shift;

  if ( $self->jr ) {
    return ( $self->von ? $self->von . " " : '' ) . $self->last . ", " . $self->jr . ", " . $self->first;
  } else {
    return
        ( $self->von ? $self->von . " " : '' )
      . ( $self->last ? $self->last : '' )
      . ( $self->first ? ", " . $self->first : '' );
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


1;
