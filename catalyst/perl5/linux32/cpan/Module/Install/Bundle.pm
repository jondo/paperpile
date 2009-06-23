package Module::Install::Bundle;

use strict;
use Cwd                   ();
use File::Find            ();
use File::Copy            ();
use File::Basename        ();
use Module::Install::Base ();

use vars qw{$VERSION @ISA $ISCORE};
BEGIN {
	$VERSION = '0.91';
	@ISA     = 'Module::Install::Base';
	$ISCORE  = 1;
}

sub auto_bundle {
    my $self = shift;

    # Flatten array of arrays into a single array
    my @core = map @$_, map @$_, grep ref, $self->requires;

    $self->bundle(@core);
}

sub bundle {
    my $self = shift;
    $self->admin->bundle(@_) if $self->is_admin;

    my $cwd = Cwd::cwd();
    my $bundles = $self->read_bundles;
    my $bundle_dir = $self->_top->{bundle};
    $bundle_dir =~ s/\W+/\\W+/g;

    while (my ($name, $version) = splice(@_, 0, 2)) {
        $version ||= 0;

        my $source = $bundles->{$name} or die "Cannot find bundle source for $name";
        my $target = File::Basename::basename($source);
        $self->bundles($name, $target);

        next if eval "use $name $version; 1";
        mkdir $target or die $! unless -d $target;

        # XXX - clean those directories upon "make clean"?
        File::Find::find({
            wanted => sub {
                my $out = $_;
                $out =~ s/$bundle_dir/./i;
                mkdir $out if -d;
                File::Copy::copy($_ => $out) unless -d;
            },
            no_chdir => 1,
        }, $source);
    }

    chdir $cwd;
}

sub read_bundles {
    my $self = shift;
    my %map;

    local *FH;
    open FH, $self->_top->{bundle} . ".yml" or return {};
    while (<FH>) {
        /^(.*?): (['"])?(.*?)\2$/ or next;
        $map{$1} = $3;
    }
    close FH;

    return \%map;
}


sub auto_bundle_deps {
    my $self = shift;

    # Flatten array of arrays into a single array
    my @core = map @$_, map @$_, grep ref, $self->requires;
    while (my ($name, $version) = splice(@core, 0, 2)) {
        next unless $name;
         $self->bundle_deps($name, $version);
         $self->bundle($name, $version);
    }
}

sub bundle_deps {
    my ($self, $pkg, $version) = @_;
    my $deps = $self->admin->scan_dependencies($pkg) or return;

    foreach my $key (sort keys %$deps) {
        $self->bundle($key, ($key eq $pkg) ? $version : 0);
    }
}

1;

__END__

=pod

=head1 NAME

Module::Install::Bundle - Bundle distributions along with your distribution

=head1 SYNOPSIS

Have your Makefile.PL read as follows:

  use inc::Module::Install;
  
  name      'Foo-Bar';
  all_from  'lib/Foo/Bar.pm';
  requires  'Baz' => '1.60';
  
  # one of either:
  bundle    'Baz' => '1.60';
  # OR:
  auto_bundle;
  
  WriteAll;

=head1 DESCRIPTION

Module::Install::Bundle allows you to bundle a CPAN distribution within your
distribution. When your end-users install your distribution, the bundled
distribution will be installed along with yours, unless a newer version of
the bundled distribution already exists on their local filesystem.

While bundling will increase the size of your distribution, it has several
benefits:

  Allows installation of bundled distributions when CPAN is unavailable
  Allows installation of bundled distributions when networking is unavailable
  Allows everything your distribution needs to be packaged in one place

Bundling differs from auto-installation in that when it comes time to
install, a bundled distribution will be installed based on the distribution
bundled with your distribution, whereas with auto-installation the distibution
to be installed will be acquired from CPAN and then installed.

=head1 METHODS

=over 4

=item * auto_bundle()

Takes no arguments, will bundle every distribution specified by a C<requires()>.
When you, as a module author, do a C<perl Makefile.PL> the latest versions of
the distributions to be bundled will be acquired from CPAN and placed in
F<inc/BUNDLES/>.

=item * bundle($name, $version)

Takes a list of key/value pairs specifying a distribution name and version
number. When you, as a module author, do a perl Makefile.PL the distributions
that you specified with C<bundle()> will be acquired from CPAN and placed in
F<inc/BUNDLES/>.

=item * bundle_deps($name, $version)

Same as C<bundle>, except that all dependencies of the bundled modules are
also detected and bundled.  To use this function, you need to declare the
minimum supported perl version first, like this:

    requires( perl => 5.005 );

=item * auto_bundle_deps

Same as C<auto_bundle>, except that all dependencies of the bundled
modules are also detected and bundled. This function has the same constraints as bundle_deps.

=back

=head1 BUGS

Please report any bugs to (patches welcome):

    http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Module-Install

=head1 AUTHORS

Audrey Tang E<lt>autrijus@autrijus.orgE<gt>

Documentation by Adam Foxson E<lt>afoxson@pobox.comE<gt>

=head1 COPYRIGHT

Copyright 2003, 2004, 2005 by Audrey Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
