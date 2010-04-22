#!/usr/bin/perl

package Catalyst::Plugin::Session::Store::Dummy;
use base qw/Catalyst::Plugin::Session::Store/;

use strict;
use warnings;

my %store;

sub get_session_data {
    my ( $c, @keys ) = @_;
    @store{@keys};
}

sub store_session_data {
    my $c = shift;
    my %data = @_;

    @store{ keys %data } = values %data;
}

sub delete_session_data {
    my ( $c, $sid ) = @_;
    delete $store{$sid};
}

sub delete_expired_sessions { }

__PACKAGE__;

__END__

=pod

=head1 NAME

Catalyst::Plugin::Session::Store::Dummy - Doesn't really store sessions - useful for tests.

=head1 SYNOPSIS

    use Catalyst qw/Session Session::Store::Dummy/;

=head1 DESCRIPTION

This plugin will "store" data in a hash.

=head1 METHODS

See L<Catalyst::Plugin::Session::Store>.

=over 4

=item get_session_data

=item store_session_data

=item delete_session_data

=item delete_expired_sessions

=back

=cut


