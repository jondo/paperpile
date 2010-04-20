package HTML::Mason::Plugin::Context;
use strict;
use warnings;

#------------------------------------------------------------

package HTML::Mason::Plugin::Context::StartRequest;
use base qw(HTML::Mason::Plugin::Context);

sub request   { $_[0]->[0] }
sub args      {
    if (wantarray) {
        return @{$_[0]->[1]};
    } else {
        return $_[0]->[1];
    }
}

#------------------------------------------------------------

package HTML::Mason::Plugin::Context::EndRequest;
use base qw(HTML::Mason::Plugin::Context);

sub request   { $_[0]->[0] }
sub args      {
    if (wantarray) {
        return @{$_[0]->[1]};
    } else {
        return $_[0]->[1];
    }
}
sub output    { $_[0]->[2] }
sub wantarray { $_[0]->[3] }
sub result    { $_[0]->[4] }
sub error     { $_[0]->[5] }

#------------------------------------------------------------

package HTML::Mason::Plugin::Context::StartComponent;
use base qw(HTML::Mason::Plugin::Context);

sub request   { $_[0]->[0] }
sub comp      { $_[0]->[1] }
sub args      { $_[0]->[2] }

#------------------------------------------------------------

package HTML::Mason::Plugin::Context::EndComponent;
use base qw(HTML::Mason::Plugin::Context);

sub request   { $_[0]->[0] }
sub comp      { $_[0]->[1] }
sub args      { $_[0]->[2] }
sub wantarray { $_[0]->[3] }
sub result    { $_[0]->[4] }
sub error     { $_[0]->[5] }

#------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Mason::Plugin::Context - encapsulates arguments passed to plugin methods

=head1 DESCRIPTION

This file defines the minimalist context classes that are instantiated
whenever a plugin hook is called. See HTML::Mason::Plugin for
documentation about plugins.

For efficiency these objects have no new() method - they are created
and blessed by hand inside HTML::Mason::Request just before they are
used.

=cut
