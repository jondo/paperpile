# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package HTML::Mason::Resolver::File;

use strict;
use warnings;

use Cwd;

use File::Glob;
use File::Spec;
use HTML::Mason::Tools qw(read_file_ref paths_eq);
use Params::Validate qw(:all);

use HTML::Mason::ComponentSource;
use HTML::Mason::Resolver;
use base qw(HTML::Mason::Resolver);

use HTML::Mason::Exceptions (abbr => ['param_error']);

sub get_info {
    my ($self, $path, $comp_root_key, $comp_root_path) = @_;

    # Note that canonpath has the property of not collapsing a series
    # of /../../ dirs in an unsafe way. This means that if the
    # component path is /../../../../etc/passwd, we're still safe. I
    # don't know if this was intentional, but it's certainly a good
    # thing, and something we want to preserve if the code ever
    # changes.
    my $srcfile = File::Spec->canonpath( File::Spec->catfile( $comp_root_path, $path ) );
    return unless -f $srcfile;
    my $modified = (stat _)[9];
    my $base = $comp_root_key eq 'MAIN' ? '' : "/$comp_root_key";
    $comp_root_key = undef if $comp_root_key eq 'MAIN';

    return
      HTML::Mason::ComponentSource->new
          ( friendly_name => $srcfile,
            comp_id => "$base$path",
            last_modified => $modified,
            comp_path => $path,
            comp_class => 'HTML::Mason::Component::FileBased',
            extra => { comp_root => $comp_root_key },
            source_callback => sub { read_file_ref($srcfile) },
          );
}

#
# Return all existing url_paths matching the given glob pattern underneath the given root.
# glob_path is required for using the "preloads" parameter.
#
sub glob_path {
    my ($self, $pattern, $comp_root_path) = @_;

    my @files = File::Glob::bsd_glob($comp_root_path . $pattern);
    my $root_length = length $comp_root_path;
    my @paths;
    foreach my $file (@files) {
        next unless -f $file;
        if (substr($file, 0, $root_length) eq $comp_root_path) {
            push(@paths, substr($file, $root_length));
        }
    }
    return @paths;
}

#
# Given an apache request object and a list of component root pairs,
# return the associated component path or undef if none exists. This
# is called for top-level web requests that resolve to a particular
# file.
# apache_request_to_comp_path is required for running Mason under mod_perl.
#
sub apache_request_to_comp_path {
    my ($self, $r, @comp_root_array) = @_;

    my $file = $r->filename;
    $file .= $r->path_info unless -f $file;

    # Clear up any weirdness here so that paths_eq compares two
    # 'canonical' paths (canonpath is called on comp roots when
    # resolver object is created.  Seems to be needed on Win32 (see
    # bug #356).
    $file = File::Spec->canonpath($file);

    foreach my $root (map $_->[1], @comp_root_array) {
        if (paths_eq($root, substr($file, 0, length($root)))) {
            my $path = substr($file, length $root);
            $path = length $path ? join '/', File::Spec->splitdir($path) : '/';
            chop $path if $path ne '/' && substr($path, -1) eq '/';

            return $path;
        }
    }
    return undef;
}


1;

__END__

=head1 NAME

HTML::Mason::Resolver::File - Component path resolver for file-based components

=head1 SYNOPSIS

  my $resolver = HTML::Mason::Resolver::File->new();

  my $info = $resolver->get_info('/some/comp.html');

=head1 DESCRIPTION

This HTML::Mason::Resolver subclass is used when components are stored
on the filesystem, which is the norm for most Mason-based applications.

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>

=cut
