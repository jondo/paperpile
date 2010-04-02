package MooseX::Getopt::Dashes;
use Moose::Role;

with 'MooseX::Getopt';

around _get_cmd_flags_for_attr => sub {
    my $next = shift;
    my ( $class, $attr, @rest ) = @_;

    my ( $flag, @aliases ) = $class->$next($attr, @rest);
    $flag =~ tr/_/-/
        unless $attr->does('MooseX::Getopt::Meta::Attribute::Trait')
            && $attr->has_cmd_flag;

    return ( $flag, @aliases );
};

1;

__END__

=pod

=head1 NAME

MooseX::Getopt::Dashes - convert underscores in attribute names to dashes

=head1 SYNOPSIS

  package My::App;
  use Moose;
  with 'MooseX::Getopt::Dashes';

  # Will be called as --some-thingy, not --some_thingy
  has 'some_thingy' => (
      is      => 'ro',
      isa     => 'Str',
      default => 'foo'
  );

  # Will be called as --another_thingy, not --another-thingy
  has 'another_thingy' => (
      traits   => [ 'Getopt' ],
      cmd_flag => 'another_thingy'
      is       => 'ro',
      isa      => 'Str',
      default  => 'foo'
  );

  # use as MooseX::Getopt

=head1 DESCRIPTION

This is a version of C<MooseX::Getopt> which converts underscores in
attribute names to dashes when generating command line flags.

You can selectively disable this on a per-attribute basis by supplying
a L<cmd_flag|MooseX::Getopt::Meta::Attribute/METHODS> argument with
the command flag you'd like for a given attribute. No underscore to
dash replacement will be done on the C<cmd_flag>.

=head1 METHODS

=over 4

=item meta

=back

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Dagfinn Ilmari MannsE<aring>ker E<lt>ilmari@ilmari.orgE<gt>

Stevan Little E<lt>stevan@iinteractive.comE<gt>

Yuval Kogman  C<< <nuffin@cpan.org> >>

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason E<lt>avar@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
