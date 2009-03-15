package Paperpile;

use strict;
use warnings;
use parent qw/Catalyst/;
use Catalyst qw/ Session
  Session::State::Cookie
  Session::Store::File
  /;

use Catalyst::Runtime '5.70';

use LWP;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

our $VERSION = '0.01';

# Configure the application.
#
# Note that settings in paperpile.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with a external configuration file acting as an override for
# local deployment.


__PACKAGE__->config( {
    'View::JSON' => {
      expose_stash => qr/^[^_]/,    #Don't show variables starting with underscore (_)
                                    #Is necessary to hide __instancePerContext object
                                    #but might be useful in other context as well...
    }
  }
);

__PACKAGE__->config( {
    'View::JSON::Tree' => {
      expose_stash => 'tree',       #show only one array of objects
    }
  }
);

# Start the application
__PACKAGE__->setup(qw/-Debug ConfigLoader Static::Simple/);

=head1 NAME

Paperpile - Catalyst based application

=head1 SYNOPSIS

    script/paperpile_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Paperpile::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
