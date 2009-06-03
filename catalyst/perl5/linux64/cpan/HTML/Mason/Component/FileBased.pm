# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package HTML::Mason::Component::FileBased;

use strict;
use warnings;

use File::Basename;
use File::Spec;

use HTML::Mason::Component;
use base qw(HTML::Mason::Component);

use HTML::Mason::Exceptions( abbr => ['error'] );

use HTML::Mason::MethodMaker ( read_only => [ qw( path source_file name dir_path ) ] );

sub is_file_based { 1 }
sub persistent { 1 }
sub source_dir {
    my $dir = dirname($_[0]->source_file);
    return File::Spec->canonpath($dir);
}
sub title {
    my ($self) = @_;
    return $self->path . ($self->{source_root_key} ? " [".lc($self->{source_root_key})."]" : "");
    #return $self->path . ($self->{source_root_key} ? " [$self->{source_root_key}]" : "");
}

# Ends up setting $self->{path, source_root_key, source_file} and a few in the parent class
sub assign_runtime_properties {
    my ($self, $interp, $source) = @_;

    $self->{source_file} = $source->friendly_name;
    $self->{source_root_key} = $source->extra->{comp_root};

    # We used to use File::Basename for this but that is broken
    # because URL paths always use '/' as the dir-separator but we
    # could be running on any OS.
    #
    # The regex itself is taken from File::Basename.
    #
    @{$self}{ 'dir_path', 'name'} = $source->comp_path =~ m,^(.*/)?(.*),s;
    $self->{dir_path} =~ s,/$,, unless $self->{dir_path} eq '/';

    $self->SUPER::assign_runtime_properties($interp, $source);
}

1;

__END__

=head1 NAME

HTML::Mason::Component::FileBased - Mason File-Based Component Class

=head1 DESCRIPTION

This is a subclass of
L<HTML::Mason::Component|HTML::Mason::Component>. Mason uses it to
implement components which are stored in files.

=head1 METHODS

See L<the FILE-BASED METHODS section of
HTML::Mason::Component|HTML::Mason::Component/FILE-BASED METHODS> for
documentation.

=head1 SEE ALSO

L<HTML::Mason::Component|HTML::Mason::Component>

=cut
