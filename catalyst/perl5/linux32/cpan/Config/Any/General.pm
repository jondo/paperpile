package Config::Any::General;

use strict;
use warnings;

use base 'Config::Any::Base';

=head1 NAME

Config::Any::General - Load Config::General files

=head1 DESCRIPTION

Loads Config::General files. Example:

    name = TestApp
    <Component Controller::Foo>
        foo bar
    </Component>
    <Model Baz>
        qux xyzzy
    </Model>

=head1 METHODS

=head2 extensions( )

return an array of valid extensions (C<cnf>, C<conf>).

=cut

sub extensions {
    return qw( cnf conf );
}

=head2 load( $file )

Attempts to load C<$file> via Config::General.

=cut

sub load {
    my $class = shift;
    my $file  = shift;
    my $args  = shift || {};

    # work around bug (?) in Config::General
    #   return if $class->_test_perl($file);

    $args->{ -ConfigFile } = $file;

    require Config::General;
    my $configfile = Config::General->new( %$args );
    my $config     = { $configfile->getall };

    return $config;
}

# this is a bit of a hack but necessary, because Config::General is *far* too lax
# about what it will load -- specifically, it seems to be quite happy to load a Perl
# config file (ie, a file which is valid Perl and creates a hashref) as if it were
# an Apache-style configuration file, presumably due to laziness on the part of the
# developer.

sub _test_perl {
    my ( $class, $file ) = @_;
    my $is_perl_src;
    eval { $is_perl_src = do "$file"; };
    delete $INC{ $file };    # so we don't screw stuff later on
    return defined $is_perl_src;
}

=head2 requires_all_of( )

Specifies that this module requires L<Config::General> in order to work.

=cut

sub requires_all_of { 'Config::General' }

=head1 AUTHOR

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=head1 CONTRIBUTORS

Joel Bernstein C<< <rataxis@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Brian Cassidy

Portions Copyright 2006 Portugal Telecom

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

=over 4 

=item * L<Catalyst>

=item * L<Config::Any>

=item * L<Config::General>

=back

=cut

1;

