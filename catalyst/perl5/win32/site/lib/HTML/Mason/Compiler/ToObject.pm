# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package HTML::Mason::Compiler::ToObject;

use strict;
use warnings;

use Params::Validate qw(BOOLEAN SCALAR validate);
use HTML::Mason::Tools qw(taint_is_on);

use HTML::Mason::Compiler;
use base qw( HTML::Mason::Compiler );

use HTML::Mason::Exceptions( abbr => [qw(wrong_compiler_error system_error)] );

use File::Path qw(mkpath rmtree);
use File::Basename qw(dirname);

BEGIN
{
    __PACKAGE__->valid_params
        (
         comp_class =>
         { parse => 'string', type => SCALAR, default => 'HTML::Mason::Component',
           descr => "The class into which component objects will be blessed" },

         subcomp_class =>
         { parse => 'string', type => SCALAR, default => 'HTML::Mason::Component::Subcomponent',
           descr => "The class into which subcomponent objects will be blessed" },

         in_package =>
         { parse => 'string', type => SCALAR, default => 'HTML::Mason::Commands',
           descr => "The package in which component execution will take place" },

         preamble =>
         { parse => 'string', type => SCALAR, default => '',
           descr => "A chunk of Perl code to add to the beginning of each compiled component" },

         postamble =>
         { parse => 'string', type => SCALAR, default => '',
           descr => "A chunk of Perl code to add to the end of each compiled component" },

         use_strict =>
         { parse => 'boolean', type => SCALAR, default => 1,
           descr => "Whether to turn on Perl's 'strict' pragma in components" },

         define_args_hash =>
         { parse => 'string', type => SCALAR, default => 'auto',
           regex => qr/^(?:always|auto|never)$/,
           descr => "Whether or not to create the %ARGS hash" },

         named_component_subs =>
         { parse => 'boolean', type => BOOLEAN, default => 0,
           descr => "Whether to use named subroutines for component code" },
        );
}

use HTML::Mason::MethodMaker
    ( read_only => [
                    qw( comp_class
                        define_args_hash
                        in_package
                        named_component_subs
                        postamble
                        preamble
                        subcomp_class
                        use_strict
                        )
                    ],
      );

sub compile
{
    my $self = shift;
    my %p = @_;

    local $self->{comp_class} = delete $p{comp_class} if exists $p{comp_class};
    return $self->SUPER::compile( %p );
}

#
# compile_to_file( source => ..., file => ... )
# Save object text in an object file.
#
# We attempt to handle several cases in which a file already exists
# and we wish to create a directory, or vice versa.  However, not
# every case is handled; to be complete, mkpath would have to unlink
# any existing file in its way.
#
sub compile_to_file
{
    my $self = shift;

    my %p = validate( @_, {   file => { type => SCALAR },
                            source => { isa => 'HTML::Mason::ComponentSource' } },
                    );

    my ($file, $source) = @p{qw(file source)};
    my @newfiles = ($file);

    if (defined $file && !-f $file) {
        my ($dirname) = dirname($file);
        if (!-d $dirname) {
            unlink($dirname) if (-e _);
            push @newfiles, mkpath($dirname, 0, 0775);
            system_error "Couldn't create directory $dirname: $!"
                unless -d $dirname;
        }
        rmtree($file) if (-d $file);
    }

    ($file) = $file =~ /^(.*)/s if taint_is_on;  # Untaint blindly

    open my $fh, "> $file"
        or system_error "Couldn't create object file $file: $!";

    $self->compile( comp_source => $source->comp_source_ref,
                    name => $source->friendly_name,
                    comp_class => $source->comp_class,
                    comp_path => $source->comp_path,
                    fh => $fh );

    close $fh 
        or system_error "Couldn't close object file $file: $!";
    
    return \@newfiles;
}

sub _output_chunk
{
    my ($self, $fh, $string) = (shift, shift, shift);
    if ($fh)
    {
        print $fh (ref $_ ? $$_ : $_) foreach grep defined, @_;
    }
    else
    {
        $$string .= (ref $_ ? $$_ : $_) foreach @_;
    }
}

# There are some really spooky relationships between the variables &
# data members in the compiled_component() routine.

sub compiled_component
{
    my ($self, %p) = @_;
    my $c = $self->{current_compile};
    my $obj_text = '';

    local $c->{compiled_def} = $self->_compile_subcomponents if %{ $c->{def} };
    local $c->{compiled_method} = $self->_compile_methods if %{ $c->{method} };

    # Some preamble stuff, including 'use strict', 'use vars', and <%once> block
    my $header = $self->_make_main_header;
    $self->_output_chunk($p{fh}, \$obj_text, $header);

    my $params = $self->_component_params;

    $params->{load_time} = time;

    $params->{subcomps} = '\%_def' if %{ $c->{def} };
    $params->{methods} = '\%_method' if %{ $c->{method} };

    if ( $self->_blocks('shared') )
    {
        my %subs;
        while ( my ($name, $pref) = each %{ $c->{compiled_def} } )
        {
            my $key = "subcomponent_$name";
            $subs{$key} = $pref->{code};
            $pref->{code} = "sub {\nHTML::Mason::Request->instance->call_dynamic('$key',\@_)\n}";
        }
        while (my ($name, $pref) = each %{ $c->{compiled_method} } )
        {
            my $key = "method_$name";
            $subs{$key} = $pref->{code};
            $pref->{code} = "sub {\nHTML::Mason::Request->instance->call_dynamic( '$key', \@_ )\n}";
        }
        $subs{main} = $params->{code};
        $params->{code} = "sub {\nHTML::Mason::Request->instance->call_dynamic( 'main', \@_ )\n}";

        my $named_subs = '';
        my %named_subs = $self->_named_subs_hash;
        while ( my ( $name, $body ) = each %named_subs )
        {
            $named_subs .= '*' . $name . " = sub {\n" . $body . "\n};\n\n";
        }

        $params->{dynamic_subs_init} =
            join '', ( "sub {\n",
                       $self->_set_request,
                       $self->_blocks('shared'),
                       $named_subs,
                       "return {\n",
                       map( "'$_' => $subs{$_},\n", sort keys %subs ),
                       "\n}\n}"
                     );
    }
    else
    {
        my %named_subs = $self->_named_subs_hash;
        while ( my ( $name, $body ) = each %named_subs )
        {
            $self->_output_chunk( $p{fh}, \$obj_text,
                                  "sub $name {\n" . $body . "\n}\n"
                                );
        }
    }

    $self->_output_chunk($p{fh}, \$obj_text, $self->_subcomponents_footer);
    $self->_output_chunk($p{fh}, \$obj_text, $self->_methods_footer);

    $self->_output_chunk($p{fh}, \$obj_text,
                         $self->_constructor( $self->comp_class,
                                              $params ),
                         ';',
                        );

    return \$obj_text;
}

sub _named_subs_hash
{
    my $self = shift;

    return unless $self->named_component_subs;

    my %subs;
    $subs{ $self->_sub_name } = $self->_body;

    while ( my ( $name, $params ) =
            each %{ $self->{current_compile}{compiled_def} } )
    {
        $subs{ $self->_sub_name( 'def', $name ) } = $params->{body};
    }

    while ( my ( $name, $params ) =
            each %{ $self->{current_compile}{compiled_method} } )
    {
        $subs{ $self->_sub_name( 'method', $name ) } = $params->{body};
    }

    return %subs;
}

sub _sub_name
{
    my $self = shift;

    return join '_', $self->_escape_sub_name_part( $self->{comp_path}, @_ );
}

sub _escape_sub_name_part
{
    my $self = shift;

    return map { my $part = $_;
                 $part =~ s/([^\w_])/'_' . sprintf( '%x', ord $1 )/ge;
                 $part; } @_;
}

sub _compile_subcomponents
{
    my $self = shift;

    return $self->_compile_subcomponents_or_methods('def');
}

sub _compile_methods
{
    my $self = shift;

    return $self->_compile_subcomponents_or_methods('method');
}

sub _compile_subcomponents_or_methods
{
    my $self = shift;
    my $type = shift;

    my %compiled;
    foreach ( keys %{ $self->{current_compile}{$type} } )
    {
        local $self->{current_compile} = $self->{current_compile}{$type}{$_};
        local $self->{current_compile}->{in_named_block} = {type => $type, name => $_};
        $compiled{$_} = $self->_component_params;
    }

    return \%compiled;
}

sub _make_main_header
{
    my $self = shift;

    my $pkg = $self->in_package;

    return join '', ( "package $pkg;\n",
                      $self->use_strict ? "use strict;\n" : "no strict;\n",
                      sprintf( "use vars qw(\%s);\n",
                               join ' ', '$m', $self->allow_globals ),
                      $self->_blocks('once'),
                    );
}

sub _subcomponents_footer
{
    my $self = shift;

    return $self->_subcomponent_or_method_footer('def');
}

sub _methods_footer
{
    my $self = shift;

    return $self->_subcomponent_or_method_footer('method');
}

sub _subcomponent_or_method_footer
{
    my $self = shift;
    my $c = $self->{current_compile};
    my $type = shift;

    return '' unless %{ $c->{$type} };

    return join('',
                "my %_$type =\n(\n",
                map( {("'$_' => " ,
                       $self->_constructor( $self->{subcomp_class},
                                            $c->{"compiled_$type"}{$_} ) ,
                       ",\n")} keys %{ $c->{"compiled_$type"} } ) ,
                "\n);\n"
               );
}

sub _constructor
{
    my ($self, $class, $params) = @_;

    return ("${class}->new(\n",
            map( {("'$_' => ", $params->{$_}, ",\n")}
                 sort grep { $_ ne 'body' } keys %$params ),
            "\n)\n",
           );
}

sub _component_params
{
    my $self = shift;

    my %params;

    if ( $self->named_component_subs )
    {
        $params{code} =
            '\\&' .
            $self->_sub_name
                ( grep { defined }
                  @{ $self->{current_compile}{in_named_block} }
                  { 'type', 'name' } );
        $params{body} = $self->_body;
    }
    else
    {
        $params{code} = join '', "sub {\n", $self->_body, "}";
    }

    $params{flags} = join '', "{\n", $self->_flags, "\n}"
        if keys %{ $self->{current_compile}{flags} };

    $params{attr}  = join '', "{\n", $self->_attr, "\n}"
        if keys %{ $self->{current_compile}{attr} };

    $params{declared_args} = join '', "{\n", $self->_declared_args, "\n}"
        if @{ $self->{current_compile}{args} };

    $params{has_filter} = 1 if $self->_blocks('filter');

    return \%params;
}

sub _body
{
    my $self = shift;

    return join '', ( $self->preamble,
                      $self->_set_request,
                      $self->_set_buffer,
                      $self->_arg_declarations,
                      $self->_filter,
                      "\$m->debug_hook( \$m->current_comp->path ) if ( HTML::Mason::Compiler::IN_PERL_DB() );\n\n",
                      $self->_blocks('init'),

                      # do not add a block around this, it introduces
                      # a separate scope and might break cleanup
                      # blocks (or all sort of other things!)
                      $self->{current_compile}{body},

                      $self->_blocks('cleanup'),
                      $self->postamble,

                      # semi before return will help catch syntax
                      # errors in component body - don't return values
                      # explicitly
                      ";return;\n",
                    );
}

sub _set_request
{
    my $self = shift;

    return if $self->in_package eq 'HTML::Mason::Commands';

    return 'local $' . $self->in_package . '::m = $HTML::Mason::Commands::m;' . "\n";
}

sub _set_buffer
{
    my $self = shift;

    if ($self->enable_autoflush) {
        return '';
    } else {
        return 'my $_outbuf = $m->{top_stack}->[HTML::Mason::Request::STACK_BUFFER];' . "\n";
    }
}

my %coercion_funcs = ( '@' => 'HTML::Mason::Tools::coerce_to_array',
                       '%' => 'HTML::Mason::Tools::coerce_to_hash',
                     );
sub _arg_declarations
{
    my $self = shift;

    my $init;
    my @args_hash;
    my $pos;
    my @req_check;
    my @decl;
    my @assign;

    my $define_args_hash = $self->_define_args_hash;

    unless ( @{ $self->{current_compile}{args} } )
    {
        return unless $define_args_hash;

        return ( "my \%ARGS;\n",
                 "{ local \$^W; \%ARGS = \@_ unless (\@_ % 2); }\n"
               );
    }

    $init = <<'EOF';
HTML::Mason::Exception::Params->throw
    ( error =>
      "Odd number of parameters passed to component expecting name/value pairs"
    ) if @_ % 2;
EOF

    if ( $define_args_hash )
    {
        @args_hash = "my \%ARGS = \@_;\n";
    }

    # opening brace will be closed later.  we want this in a separate
    # block so that the rest of the component can't see %pos
    $pos = <<'EOF';
{
    my %pos;
    for ( my $x = 0; $x < @_; $x += 2 )
    {
        $pos{ $_[$x] } = $x + 1;
    }
EOF

    my @required =
        ( map { $_->{name} }
          grep { ! defined $_->{default} }
          @{ $self->{current_compile}{args} }
        );

    if (@required)
    {
        # just to be sure
        local $" = ' ';
        @req_check = <<"EOF";

    foreach my \$arg ( qw( @required ) )
    {
        HTML::Mason::Exception::Params->throw
            ( error => "no value sent for required parameter '\$arg'" )
                unless exists \$pos{\$arg};
    }
EOF
    }

    foreach ( @{ $self->{current_compile}{args} } )
    {
        my $var_name = "$_->{type}$_->{name}";
        push @decl, $var_name;

        my $arg_in_array = "\$_[ \$pos{'$_->{name}'} ]";

        my $coerce;
        if ( $coercion_funcs{ $_->{type} } )
        {
            $coerce = $coercion_funcs{ $_->{type} } . "( $arg_in_array, '$var_name')";
        }
        else
        {
            $coerce = $arg_in_array;
        }

        if ( defined $_->{line} && defined $_->{file} && $self->use_source_line_numbers )
        {
            my $file = $self->_escape_filename( $_->{file} );
            push @assign, qq{#line $_->{line} "$file"\n};
        }

        if ( defined $_->{default} )
        {
            my $default_val = $_->{default};
            # allow for comments after default declaration
            $default_val .= "\n" if defined $_->{default} && $_->{default} =~ /\#/;

            push @assign, <<"EOF";
     $var_name = exists \$pos{'$_->{name}'} ? $coerce : $default_val;
EOF
        }
        else
        {
            push @assign,
                "    $var_name = $coerce;\n";
        }
    }

    my $decl = 'my ( ';
    $decl .= join ', ', @decl;
    $decl .= " );\n";

    # closing brace closes opening of @pos
    return $init, @args_hash, $decl, $pos, @req_check, @assign, "}\n";
}

sub _define_args_hash
{
    my $self = shift;

    return 1 if $self->define_args_hash eq 'always';
    return 0 if $self->define_args_hash eq 'never';

    foreach ( $self->preamble,
              $self->_blocks('filter'),
              $self->_blocks('init'),
              $self->{current_compile}{body},
              $self->_blocks('cleanup'),
              $self->postamble,
              grep { defined } map { $_->{default} } @{ $self->{current_compile}{args} }
            )
    {
        return 1 if /ARGS/;
    }
}

sub _filter
{
    my $self = shift;

    my @filter;
    @filter = $self->_blocks('filter')
        or return;

    return ( join '',
             "\$m->current_comp->filter( sub { local \$_ = shift;\n",
             ( join ";\n", @filter ),
             ";\n",
             "return \$_;\n",
             "} );\n",
           );

}

sub _flags
{
    my $self = shift;

    return $self->_flags_or_attr('flags');
}

sub _attr
{
    my $self = shift;

    return $self->_flags_or_attr('attr');
}

sub _flags_or_attr
{
    my $self = shift;
    my $type = shift;

    return join "\n,", ( map { "$_ => $self->{current_compile}{$type}{$_}" }
                         keys %{ $self->{current_compile}{$type} } );
}

sub _declared_args
{
    my $self = shift;

    my @args;

    foreach my $arg ( sort {"$a->{type}$a->{name}" cmp "$b->{type}$b->{name}" }
                      @{ $self->{current_compile}{args} } )
    {
        my $def = defined $arg->{default} ? "$arg->{default}" : 'undef';
        $def =~ s,([\\']),\\$1,g;
        $def = "'$def'" unless $def eq 'undef';

        push @args, "  '$arg->{type}$arg->{name}' => { default => $def }";
    }

    return join ",\n", @args;
}

1;

__END__

=head1 NAME

HTML::Mason::Compiler::ToObject - A Compiler subclass that generates Mason object code

=head1 SYNOPSIS

  my $compiler = HTML::Mason::Compiler::ToObject->new;

  my $object_code =
      $compiler->compile( comp_source => $source,
                          name        => $comp_name,
                          comp_path   => $comp_path,
                        );

=head1 DESCRIPTION

This Compiler subclass generates Mason object code (Perl code).  It is
the default Compiler class used by Mason.

=head1 PARAMETERS TO THE new() CONSTRUCTOR

All of these parameters are optional.

=over

=item comp_class

The class into which component objects are blessed.  This defaults to
L<HTML::Mason::Component|HTML::Mason::Component>.

=item subcomp_class

The class into which subcomponent objects are blessed.  This defaults
to L<HTML::Mason::Component::Subcomponent|HTML::Mason::Component::Subcomponent>.

=item in_package

This is the package in which a component's code is executed.  For
historical reasons, this defaults to C<HTML::Mason::Commands>.

=item preamble

Text given for this parameter is placed at the beginning of each
component, but after the execution of any C<< <%once> >> block. See
also L<postamble|HTML::Mason::Params/postamble>. The request will be available as C<$m> in preamble
code.

=item postamble

Text given for this parameter is placed at the end of each
component. See also L<preamble|HTML::Mason::Params/preamble>.  The request will be available as
C<$m> in postamble code.

=item use_strict

True or false, default is true. Indicates whether or not a given
component should C<use strict>.

=item named_component_subs

When compiling a component, use uniquely named subroutines for the a
component's body, subcomponents, and methods. Doing this allows you to
effectively profile Mason components. Without this, all components
simply show up as __ANON__ or something similar in the profiler.

=item define_args_hash

One of "always", "auto", or "never".  This determines whether or not
an C<%ARGS> hash is created in components.  If it is set to "always",
one is always defined.  If set to "never", it is never defined.

The default, "auto", will cause the hash to be defined only if some
part of the component contains the string "ARGS".  This is somewhat
crude, and may result in some false positives, but this is preferable
to false negatives.

Not defining the args hash means that we can avoid copying component
arguments, which can save memory and slightly improve execution speed.

=back

=head1 ACCESSOR METHODS

All of the above properties have read-only accessor methods of the
same name. You cannot change any property of a compiler after it has
been created (but you can create multiple compilers with different
properties).

=head1 METHODS

This class is primarily meant to be used by the Interpreter object,
and as such has a very limited public API.

=over

=item compile(...)

This method will take component source and return the compiled object
code for that source. See L<HTML::Mason::Compiler/compile(...)> for
details on this method.

This subclass also accepts a C<comp_class> parameter, allowing you to
override the class into which the component is compiled.

=back

=cut
