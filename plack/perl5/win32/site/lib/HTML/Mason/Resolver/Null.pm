# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package HTML::Mason::Resolver::Null;

use strict;
use warnings;

use HTML::Mason::Resolver;
use base qw(HTML::Mason::Resolver);

sub get_info {
    return;
}

sub get_source {
    return;
}

sub comp_class {
    return 'HTML::Mason::Component';
}

sub glob_path {
    return;
}

1;

__END__

=head1 NAME

HTML::Mason::Resolver::Null - a do-nothing resolver

=head1 SYNOPSIS

  my $resolver = HTML::Mason::Resolver::Null->new;

=head1 DESCRIPTION

This HTML::Mason::Resolver subclass is useful if you want to create
components via the C<< HTML::Mason::Interp->make_component >> method
and you never plan to interact with the filesystem.

Basically, it provides all of the necessary resolver methods but none
of them do anything.

This means that if you use this method things like C<< $interp->exec >>
will simply not work at all.

However, if you just want to make a component with an interepreter and
execute that component it can be useful.  For example:

  my $interp = HTML::Mason::Interp->new( resolver_class => 'HTML::Mason::Resolver::Null',
                                         data_dir => '/tmp' );

  my $comp = $interp->make_component( comp_source => <<'EOF' );
% my $var = 'World';
Hello, <% $var %>!
EOF

  my $buffer;
  my $request = $interp->make_request( out_method => \$buffer, comp => $comp );
  $request->exec;

  print $buffer;

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>

=cut
