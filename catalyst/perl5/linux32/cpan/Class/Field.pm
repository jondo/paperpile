package Class::Field;
use 5.006001;
use strict;
use warnings;
use base 'Exporter';
use Encode;

our $VERSION = '0.15';
our @EXPORT_OK = qw(field const);

my %code = (
    sub_start =>
      "sub {\n  local \*__ANON__ = \"%s::%s\";\n",
    set_default =>
      "  \$_[0]->{%s} = %s\n    unless exists \$_[0]->{%s};\n",
    init =>
      "  return \$_[0]->{%s} = do { my \$self = \$_[0]; %s }\n" .
      "    unless \$#_ > 0 or defined \$_[0]->{%s};\n",
    weak_init =>
      "  return do {\n" .
      "    \$_[0]->{%s} = do { my \$self = \$_[0]; %s };\n" .
      "    Scalar::Util::weaken(\$_[0]->{%s}) if ref \$_[0]->{%s};\n" .
      "    \$_[0]->{%s};\n" .
      "  } unless \$#_ > 0 or defined \$_[0]->{%s};\n",
    return_if_get =>
      "  return \$_[0]->{%s} unless \$#_ > 0;\n",
    set =>
      "  \$_[0]->{%s} = \$_[1];\n",
    weaken =>
      "  Scalar::Util::weaken(\$_[0]->{%s}) if ref \$_[0]->{%s};\n",
    sub_end =>
      "  return \$_[0]->{%s};\n}\n",
);

sub field {
    my $package = caller;
    my ($args, @values) = do {
        no warnings;
        local *boolean_arguments = sub { (qw(-weak)) };
        local *paired_arguments = sub { (qw(-package -init)) };
        Class::Field->parse_arguments(@_);
    };
    my ($field, $default) = @values;
    $package = $args->{-package} if defined $args->{-package};
    die "Cannot have a default for a weakened field ($field)"
        if defined $default && $args->{-weak};
    return if defined &{"${package}::$field"};
    require Scalar::Util if $args->{-weak};
    my $default_string =
        ( ref($default) eq 'ARRAY' and not @$default )
        ? '[]'
        : (ref($default) eq 'HASH' and not keys %$default )
          ? '{}'
          : default_as_code($default);

    my $code = sprintf $code{sub_start}, $package, $field;
    if ($args->{-init}) {
        my $fragment = $args->{-weak} ? $code{weak_init} : $code{init};
        $code .= sprintf $fragment, $field, $args->{-init}, ($field) x 4;
    }
    $code .= sprintf $code{set_default}, $field, $default_string, $field
      if defined $default;
    $code .= sprintf $code{return_if_get}, $field;
    $code .= sprintf $code{set}, $field;
    $code .= sprintf $code{weaken}, $field, $field 
      if $args->{-weak};
    $code .= sprintf $code{sub_end}, $field;

    my $sub = eval $code;
    die $@ if $@;
    no strict 'refs';
    use utf8;
    my $method = "${package}::$field";
    $method = Encode::decode_utf8($method);
    *{$method} = $sub;
    return $code if defined wantarray;
}

sub default_as_code {
    no warnings 'once';
    require Data::Dumper;
    local $Data::Dumper::Sortkeys = 1;
    my $code = Data::Dumper::Dumper(shift);
    $code =~ s/^\$VAR1 = //;
    $code =~ s/;$//;
    return $code;
}

sub const {
    my $package = caller;
    my ($args, @values) = do {
        no warnings;
        local *paired_arguments = sub { (qw(-package)) };
        Class::Field->parse_arguments(@_);
    };
    my ($field, $default) = @values;
    $package = $args->{-package} if defined $args->{-package};
    no strict 'refs';
    return if defined &{"${package}::$field"};
    *{"${package}::$field"} = sub { $default }
}

sub parse_arguments {
    my $class = shift;
    my ($args, @values) = ({}, ());
    my %booleans = map { ($_, 1) } $class->boolean_arguments;
    my %pairs = map { ($_, 1) } $class->paired_arguments;
    while (@_) {
        my $elem = shift;
        if (defined $elem and defined $booleans{$elem}) {
            $args->{$elem} = (@_ and $_[0] =~ /^[01]$/)
            ? shift
            : 1;
        }
        elsif (defined $elem and defined $pairs{$elem} and @_) {
            $args->{$elem} = shift;
        }
        else {
            push @values, $elem;
        }
    }
    return wantarray ? ($args, @values) : $args;        
}

sub boolean_arguments { () }
sub paired_arguments { () }

__END__

=head1 NAME

Class::Field - Class Field Accessor Generator

=head1 SYNOPSIS

    package Thing;
    use Class::Field qw'field const';

    field 'this';
    field 'list' => [];
    field 'map' => {};
    field 'that', -init => '$self->setup_that';
    field 'circular_ref' => -weaken;
    const 'answer' => 42;

=head1 DESCRIPTION

Class::Field exports two subroutines, C<field> and C<const>. These
functions are used to declare fields and constants in your class.

Class::Field generates custom code for each accessor that is optimized
for speed.

=head1 FUNCTIONS

=over 4

=item * field

Defines accessor methods for a field of your class:

    package Example;
    use base 'Parent';
    use Class::Field qw'field const';
    
    field 'foo';
    field bar => [];

    sub lalala {
        my $self = shift;
        $self->foo(42);
        push @{$self->{bar}}, $self->foo;
    }

The first parameter passed to C<field> is the name of the attribute
being defined. Accessors can be given an optional default value.
This value will be returned if no value for the field has been set
in the object.

=item * const

    const bar => 42;

The C<const> function is similar to <field> except that it is immutable.
It also does not store data in the object. You probably always want to
give a C<const> a default value, otherwise the generated method will be
somewhat useless.

=back

=head1 NOTE

This code was taken directly out the Spiffy module for those people who just
want this functionality without using the rest of Spiffy.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2006, 2008, 2009. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
