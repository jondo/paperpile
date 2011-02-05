package Catalyst::Plugin::Session::Store::File;

use strict;
use warnings;

use base qw( Class::Data::Inheritable Catalyst::Plugin::Session::Store );

use MRO::Compat;
use Cache::FileCache ();
use Catalyst::Utils ();
use Path::Class ();

our $VERSION = '0.18';

__PACKAGE__->mk_classdata(qw/_session_file_storage/);

=head1 NAME

Catalyst::Plugin::Session::Store::File - File storage backend for session data.

=head1 SYNOPSIS

    use Catalyst qw/Session Session::Store::File Session::State::Foo/;

    MyApp->config->{'Plugin::Session'} = {
        storage => '/tmp/session'
    };

    # ... in an action:
    $c->session->{foo} = 'bar'; # will be saved

=head1 DESCRIPTION

C<Catalyst::Plugin::Session::Store::File> is an easy to use storage plugin
for Catalyst that uses an simple file to act as a shared memory interprocess
cache. It is based on C<Cache::FileCache>.

=head2 METHODS

=over 4

=item get_session_data

=item store_session_data

=item delete_session_data

=item delete_expired_sessions

These are implementations of the required methods for a store. See
L<Catalyst::Plugin::Session::Store>.

=cut

sub get_session_data {
    my ( $c, $sid ) = @_;
    $c->_check_session_file_storage;
    $c->_session_file_storage->get($sid);
}

sub store_session_data {
    my ( $c, $sid, $data ) = @_;
    $c->_check_session_file_storage;
    $c->_session_file_storage->set( $sid, $data );
}

sub delete_session_data {
    my ( $c, $sid ) = @_;
    $c->_check_session_file_storage;
    $c->_session_file_storage->remove($sid);
}

sub delete_expired_sessions { }

=item setup_session

Sets up the session cache file.

=cut

sub setup_session {
    my $c = shift;

    $c->maybe::next::method(@_);
}

sub _check_session_file_storage {
    my $c = shift;
    return if $c->_session_file_storage;

    $c->_session_plugin_config->{namespace} ||= '';
    my $root = $c->_session_plugin_config->{storage} ||=
      File::Spec->catdir( Catalyst::Utils::class2tempdir(ref $c),
        "session", "data", );

    $root = $c->path_to($root) if $c->_session_plugin_config->{relative};

    Path::Class::dir($root)->mkpath;

    my $cfg = $c->_session_plugin_config;
    $c->_session_file_storage(
        Cache::FileCache->new(
            {
                cache_root  => $cfg->{storage},
                (
                    map { $_ => $cfg->{$_} }
                      grep { exists $cfg->{$_} }
                      qw/namespace cache_depth directory_umask/
                ),
            }
        )
    );
}

=back

=head1 CONFIGURATION

These parameters are placed in the hash under the C<Plugin::Session> key in the
configuration hash.

=over 4

=item storage

Specifies the directory root to be used for the sharing of session data. The default
value will use L<File::Spec> to find the default tempdir, and use a file named
C<MyApp/session/data>, where C<MyApp> is replaced with the appname.

Note that the file will be created with mode 0640, which means that it
will only be writeable by processes running with the same uid as the
process that creates the file.  If this may be a problem, for example
if you may try to debug the program as one user and run it as another,
specify a directory like C<< /tmp/session-$> >>, which includes the
UID of the process in the filename.

=item relative

Makes the storage path relative to I<$c->path_to>

=item namespace

The namespace associated with this cache. Defaults to an empty string if not explicitly set.
If set, the session data will be stored in a directory called C<MyApp/session/data/<namespace>>.

=item cache_depth

The number of subdirectories deep to session object item. This should be large enough that
no session directory has more than a few hundred objects. Defaults to 3 unless explicitly set.

=item directory_umask

The directories in the session on the filesystem should be globally writable to allow for
multiple users. While this is a potential security concern, the actual cache entries are
written with the user's umask, thus reducing the risk of cache poisoning. If you desire it
to only be user writable, set the 'directory_umask' option to '077' or similar. Defaults
to '000' unless explicitly set.

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Session>, L<Cache::FileCache>.

=head1 AUTHOR

Sascha Kiefer, L<esskar@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 Sascha Kiefer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
