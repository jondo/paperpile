package Catalyst::Helper;
use Moose;
use Config;
use File::Spec;
use File::Spec::Unix;
use File::Path;
use FindBin;
use IO::File;
use POSIX 'strftime';
use Template;
use Catalyst::Devel;
use Catalyst::Utils;
use Catalyst::Exception;
use Path::Class qw/dir file/;
use File::ShareDir qw/dist_dir/;
use namespace::autoclean;

with 'MooseX::Emulate::Class::Accessor::Fast';

# Change Catalyst/Devel.pm also
our $VERSION = '1.23';

my %cache;

=head1 NAME

Catalyst::Helper - Bootstrap a Catalyst application

=head1 SYNOPSIS

  catalyst.pl <myappname>

=cut

sub get_sharedir_file {
    my ($self, @filename) = @_;
    my $dist_dir;
    if (exists $ENV{CATALYST_DEVEL_SHAREDIR}) {
        $dist_dir = $ENV{CATALYST_DEVEL_SHAREDIR};
    }
    elsif (-d "inc/.author" && -f "lib/Catalyst/Helper.pm"
            ) { # Can't use sharedir if we're in a checkout
                # this feels horrible, better ideas?
        $dist_dir = 'share';
    }
    else {
        $dist_dir = dist_dir('Catalyst-Devel');
    }
    my $file = file( $dist_dir, @filename);
    Carp::confess("Cannot find $file") unless -r $file;
    my $contents = $file->slurp;
    return $contents;
}

# Do not touch this method, *EVER*, it is needed for back compat.
sub get_file {
    my ( $self, $class, $file ) = @_;
    unless ( $cache{$class} ) {
        local $/;
        $cache{$class} = eval "package $class; <DATA>";
    }
    my $data = $cache{$class};
    Carp::confess("Could not get data from __DATA__ segment for $class")
        unless $data;
    my @files = split /^__(.+)__\r?\n/m, $data;
    shift @files;
    while (@files) {
        my ( $name, $content ) = splice @files, 0, 2;
        return $content if $name eq $file;
    }
    return 0;
}


sub mk_app {
    my ( $self, $name ) = @_;

    # Needs to be here for PAR
    require Catalyst;

    if ( $name =~ /[^\w:]/ || $name =~ /^\d/ || $name =~ /\b:\b|:{3,}/) {
        warn "Error: Invalid application name.\n";
        return 0;
    }
    $self->{name            } = $name;
    $self->{dir             } = $name;
    $self->{dir             } =~ s/\:\:/-/g;
    $self->{script          } = dir( $self->{dir}, 'script' );
    $self->{appprefix       } = Catalyst::Utils::appprefix($name);
    $self->{appenv          } = Catalyst::Utils::class2env($name);
    $self->{startperl       } = -r '/usr/bin/env'
                                ? '#!/usr/bin/env perl'
                                : "#!$Config{perlpath} -w";
    $self->{scriptgen       } = $Catalyst::Devel::CATALYST_SCRIPT_GEN;
    $self->{catalyst_version} = $Catalyst::VERSION;
    $self->{author          } = $self->{author} = $ENV{'AUTHOR'}
      || eval { @{ [ getpwuid($<) ] }[6] }
      || 'Catalyst developer';

    my $gen_scripts  = ( $self->{makefile} ) ? 0 : 1;
    my $gen_makefile = ( $self->{scripts} )  ? 0 : 1;
    my $gen_app = ( $self->{scripts} || $self->{makefile} ) ? 0 : 1;

    if ($gen_app) {
        for ( qw/ _mk_dirs _mk_config _mk_appclass _mk_rootclass _mk_readme
              _mk_changes _mk_apptest _mk_images _mk_favicon/ ) {
            
            $self->$_;
        }
    }
    if ($gen_makefile) {
        $self->_mk_makefile;
    }
    if ($gen_scripts) {
        for ( qw/ _mk_cgi _mk_fastcgi _mk_server 
                  _mk_test _mk_create _mk_information
        / ) {
              $self->$_;
        }
    }
    return $self->{dir};
}

## not much of this can really be changed, mk_compclass must be left for 
## backcompat
sub mk_component {
    my $self = shift;
    my $app  = shift;
    $self->{app} = $app;
    $self->{author} = $self->{author} = $ENV{'AUTHOR'}
      || eval { @{ [ getpwuid($<) ] }[6] }
      || 'A clever guy';
    $self->{base} ||= dir( $FindBin::Bin, '..' );
    unless ( $_[0] =~ /^(?:model|view|controller)$/i ) {
        my $helper = shift;
        my @args   = @_;
        my $class  = "Catalyst::Helper::$helper";
        eval "require $class";

        if ($@) {
            Catalyst::Exception->throw(
                message => qq/Couldn't load helper "$class", "$@"/ );
        }

        if ( $class->can('mk_stuff') ) {
            return 1 unless $class->mk_stuff( $self, @args );
        }
    }
    else {
        my $type   = shift;
        my $name   = shift || "Missing name for model/view/controller";
        my $helper = shift;
        my @args   = @_;
       return 0 if $name =~ /[^\w\:]/;
        $type              = lc $type;
        $self->{long_type} = ucfirst $type;
        $type              = 'M' if $type =~ /model/i;
        $type              = 'V' if $type =~ /view/i;
        $type              = 'C' if $type =~ /controller/i;
        my $appdir = dir( split /\:\:/, $app );
        my $test_path =
          dir( $self->{base}, 'lib', $appdir, 'C' );
        $type = $self->{long_type} unless -d $test_path;
        $self->{type}  = $type;
        $self->{name}  = $name;
        $self->{class} = "$app\::$type\::$name";

        # Class
        my $path =
          dir( $self->{base}, 'lib', $appdir, $type );
        my $file = $name;
        if ( $name =~ /\:/ ) {
            my @path = split /\:\:/, $name;
            $file = pop @path;
            $path = dir( $path, @path );
        }
        $self->mk_dir($path);
        $file = file( $path, "$file.pm" );
        $self->{file} = $file;

        # Test
        $self->{test_dir} = dir( $self->{base}, 't' );
        $self->{test}     = $self->next_test;

        # Helper
        if ($helper) {
            my $comp  = $self->{long_type};
            my $class = "Catalyst::Helper::$comp\::$helper";
            eval "require $class";

            if ($@) {
                Catalyst::Exception->throw(
                    message => qq/Couldn't load helper "$class", "$@"/ );
            }

            if ( $class->can('mk_compclass') ) {
                return 1 unless $class->mk_compclass( $self, @args );
            }
            else {
                return 1 unless $self->_mk_compclass
            }

            if ( $class->can('mk_comptest') ) {
                $class->mk_comptest( $self, @args );
            }
            else {
                $self->_mk_comptest
            }
        }

        # Fallback
        else {
            return 1 unless $self->_mk_compclass;
            $self->_mk_comptest;
        }
    }
    return 1;
}

sub mk_dir {
    my ( $self, $dir ) = @_;
    if ( -d $dir ) {
        print qq/ exists "$dir"\n/;
        return 0;
    }
    if ( mkpath [$dir] ) {
        print qq/created "$dir"\n/;
        return 1;
    }

    Catalyst::Exception->throw( message => qq/Couldn't create "$dir", "$!"/ );
}

sub mk_file {
    my ( $self, $file, $content ) = @_;
    if ( -e $file && -s _ ) {
        print qq/ exists "$file"\n/;
        return 0
          unless ( $self->{'.newfiles'}
            || $self->{scripts}
            || $self->{makefile} );
        if ( $self->{'.newfiles'} ) {
            if ( my $f = IO::File->new("< $file") ) {
                my $oldcontent = join( '', (<$f>) );
                return 0 if $content eq $oldcontent;
            }
            $file .= '.new';
        }
    }
    
    if ( my $f = IO::File->new("> $file") ) {
        binmode $f;
        print $f $content;
        print qq/created "$file"\n/;
        return 1;
    }

    Catalyst::Exception->throw( message => qq/Couldn't create "$file", "$!"/ );
}

sub next_test {
    my ( $self, $tname ) = @_;
    if ($tname) { $tname = "$tname.t" }
    else {
        my $name   = $self->{name};
        my $prefix = $name;
        $prefix =~ s/::/-/g;
        $prefix         = $prefix;
        $tname          = $prefix . '.t';
        $self->{prefix} = $prefix;
        $prefix         = lc $prefix;
        $prefix =~ s/-/\//g;
        $self->{uri} = "/$prefix";
    }
    my $dir  = $self->{test_dir};
    my $type = lc $self->{type};
    $self->mk_dir($dir);
    return file( $dir, "$type\_$tname" );
}

# Do not touch this method, *EVER*, it is needed for back compat.
## addendum: we had to split this method so we could have backwards
## compatability.  otherwise, we'd have no way to pass stuff from __DATA__

sub render_file {
    my ( $self, $file, $path, $vars ) = @_;
    my $template = $self->get_file( ( caller(0) )[0], $file );
    $self->render_file_contents($template, $path, $vars);
}

sub render_sharedir_file {
    my ( $self, $file, $path, $vars ) = @_;
    my $template = $self->get_sharedir_file( $file );
    die("Cannot get template from $file for $self\n") unless $template;
    $self->render_file_contents($template, $path, $vars);
}

sub render_file_contents {
    my ( $self, $template, $path, $vars ) = @_;
    $vars ||= {};
    my $t = Template->new;
    return 0 unless $template;
    my $output;
    $t->process( \$template, { %{$self}, %$vars }, \$output )
      || Catalyst::Exception->throw(
        message => qq/Couldn't process "$template", / . $t->error() );
    $self->mk_file( $path, $output );
}

sub _mk_information {
    my $self = shift;
    print qq/Change to application directory and Run "perl Makefile.PL" to make sure your install is complete\n/;
}

sub _mk_dirs {
    my $self = shift;
    $self->mk_dir( $self->{dir} );
    $self->mk_dir( $self->{script} );
    $self->{lib} = dir( $self->{dir}, 'lib' );
    $self->mk_dir( $self->{lib} );
    $self->{root} = dir( $self->{dir}, 'root' );
    $self->mk_dir( $self->{root} );
    $self->{static} = dir( $self->{root}, 'static' );
    $self->mk_dir( $self->{static} );
    $self->{images} = dir( $self->{static}, 'images' );
    $self->mk_dir( $self->{images} );
    $self->{t} = dir( $self->{dir}, 't' );
    $self->mk_dir( $self->{t} );

    $self->{class} = dir( split( /\:\:/, $self->{name} ) );
    $self->{mod} = dir( $self->{lib}, $self->{class} );
    $self->mk_dir( $self->{mod} );

    if ( $self->{short} ) {
        $self->{m} = dir( $self->{mod}, 'M' );
        $self->mk_dir( $self->{m} );
        $self->{v} = dir( $self->{mod}, 'V' );
        $self->mk_dir( $self->{v} );
        $self->{c} = dir( $self->{mod}, 'C' );
        $self->mk_dir( $self->{c} );
    }
    else {
        $self->{m} = dir( $self->{mod}, 'Model' );
        $self->mk_dir( $self->{m} );
        $self->{v} = dir( $self->{mod}, 'View' );
        $self->mk_dir( $self->{v} );
        $self->{c} = dir( $self->{mod}, 'Controller' );
        $self->mk_dir( $self->{c} );
    }
    my $name = $self->{name};
    $self->{rootname} =
      $self->{short} ? "$name\::C::Root" : "$name\::Controller::Root";
    $self->{base} = dir( $self->{dir} )->absolute;
}

sub _mk_appclass {
    my $self = shift;
    my $mod  = $self->{mod};
    $self->render_sharedir_file( file('lib', 'MyApp.pm.tt'), "$mod.pm" );
}

sub _mk_rootclass {
    my $self = shift;
    $self->render_sharedir_file( file('lib', 'MyApp', 'Controller', 'Root.pm.tt'),
        file( $self->{c}, "Root.pm" ) );
}

sub _mk_makefile {
    my $self = shift;
    $self->{path} = dir( 'lib', split( '::', $self->{name} ) );
    $self->{path} .= '.pm';
    my $dir = $self->{dir};
    $self->render_sharedir_file( 'Makefile.PL.tt', file($dir, "Makefile.PL") );

    if ( $self->{makefile} ) {

        # deprecate the old Build.PL file when regenerating Makefile.PL
        $self->_deprecate_file(
            file( $self->{dir}, 'Build.PL' ) );
    }
}

sub _mk_config {
    my $self      = shift;
    my $dir       = $self->{dir};
    my $appprefix = $self->{appprefix};
    $self->render_sharedir_file( 'myapp.conf.tt',
        file( $dir, "$appprefix.conf" ) );
}

sub _mk_readme {
    my $self = shift;
    my $dir  = $self->{dir};
    $self->render_sharedir_file( 'README.tt', file($dir, "README") );
}

sub _mk_changes {
    my $self = shift;
    my $dir  = $self->{dir};
    my $time = strftime('%Y-%m-%d %H:%M:%S', localtime time);
    $self->render_sharedir_file( 'Changes.tt', file($dir, "Changes"), { time => $time } );
}

sub _mk_apptest {
    my $self = shift;
    my $t    = $self->{t};
    $self->render_sharedir_file( file('t', '01app.t.tt'),         file($t, "01app.t") );
    $self->render_sharedir_file( file('t', '02pod.t.tt'),         file($t, "02pod.t") );
    $self->render_sharedir_file( file('t', '03podcoverage.t.tt'), file($t, "03podcoverage.t") );
}

sub _mk_cgi {
    my $self      = shift;
    my $script    = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_sharedir_file( file('script', 'myapp_cgi.pl.tt'), file($script,"$appprefix\_cgi.pl") );
    chmod 0700, file($script,"$appprefix\_cgi.pl");
}

sub _mk_fastcgi {
    my $self      = shift;
    my $script    = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_sharedir_file( file('script', 'myapp_fastcgi.pl.tt'), file($script, "$appprefix\_fastcgi.pl") );
    chmod 0700, file($script, "$appprefix\_fastcgi.pl");
}

sub _mk_server {
    my $self      = shift;
    my $script    = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_sharedir_file( file('script', 'myapp_server.pl.tt'), file($script, "$appprefix\_server.pl") );
    chmod 0700, file($script, "$appprefix\_server.pl");
}

sub _mk_test {
    my $self      = shift;
    my $script    = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_sharedir_file( file('script', 'myapp_test.pl.tt'), file($script, "$appprefix\_test.pl") );
    chmod 0700, file($script, "$appprefix\_test.pl");
}

sub _mk_create {
    my $self      = shift;
    my $script    = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_sharedir_file( file('script', 'myapp_create.pl.tt'), file($script, "$appprefix\_create.pl") );
    chmod 0700, file($script, "$appprefix\_create.pl");
}

sub _mk_compclass {
    my $self = shift;
    my $file = $self->{file};
    return $self->render_sharedir_file( file('lib', 'Helper', 'compclass.pm.tt'), $file );
}

sub _mk_comptest {
    my $self = shift;
    my $test = $self->{test};
    $self->render_sharedir_file( file('t', 'comptest.tt'), $test );  ## wtf do i rename this to?
}

sub _mk_images {
    my $self   = shift;
    my $images = $self->{images};
    my @images =
      qw/catalyst_logo btn_120x50_built btn_120x50_built_shadow
      btn_120x50_powered btn_120x50_powered_shadow btn_88x31_built
      btn_88x31_built_shadow btn_88x31_powered btn_88x31_powered_shadow/;
    for my $name (@images) {
        my $image = $self->get_sharedir_file("root", "static", "images", "$name.png.bin");
        $self->mk_file( file( $images, "$name.png" ), $image );
    }
}

sub _mk_favicon {
    my $self    = shift;
    my $root    = $self->{root};
    my $favicon = $self->get_sharedir_file( 'root', 'favicon.ico.bin' );
    my $dest = dir( $root, "favicon.ico" );
    $self->mk_file( $dest, $favicon );

}

sub _deprecate_file {
    my ( $self, $file ) = @_;
    if ( -e $file ) {
        my ($f, $oldcontent);
        if ( $f = IO::File->new("< $file") ) {
            $oldcontent = join( '', (<$f>) );
        }
        my $newfile = $file . '.deprecated';
        if ( $f = IO::File->new("> $newfile") ) {
            binmode $f;
            print $f $oldcontent;
            print qq/created "$newfile"\n/;
            unlink $file;
            print qq/removed "$file"\n/;
            return 1;
        }
        Catalyst::Exception->throw(
            message => qq/Couldn't create "$file", "$!"/ );
    }
}

=head1 DESCRIPTION

This module is used by B<catalyst.pl> to create a set of scripts for a
new catalyst application. The scripts each contain documentation and
will output help on how to use them if called incorrectly or in some
cases, with no arguments.

It also provides some useful methods for a Helper module to call when
creating a component. See L</METHODS>.

=head1 SCRIPTS

=head2 _create.pl

Used to create new components for a catalyst application at the
development stage.

=head2 _server.pl

The catalyst test server, starts an HTTPD which outputs debugging to
the terminal.

=head2 _test.pl

A script for running tests from the command-line.

=head2 _cgi.pl

Run your application as a CGI.

=head2 _fastcgi.pl

Run the application as a fastcgi app. Either by hand, or call this
from FastCgiServer in your http server config.

=head1 HELPERS

The L</_create.pl> script creates application components using Helper
modules. The Catalyst team provides a good number of Helper modules
for you to use. You can also add your own.

Helpers are classes that provide two methods.

    * mk_compclass - creates the Component class
    * mk_comptest  - creates the Component test

So when you call C<scripts/myapp_create.pl view MyView TT>, create
will try to execute Catalyst::Helper::View::TT->mk_compclass and
Catalyst::Helper::View::TT->mk_comptest.

See L<Catalyst::Helper::View::TT> and
L<Catalyst::Helper::Model::DBIC::Schema> for examples.

All helper classes should be under one of the following namespaces.

    Catalyst::Helper::Model::
    Catalyst::Helper::View::
    Catalyst::Helper::Controller::

=head2 COMMON HELPERS

=over

=item *

L<Catalyst::Helper::Model::DBIC::Schema> - DBIx::Class models

=item *

L<Catalyst::Helper::View::TT> - Template Toolkit view

=item *

L<Catalyst::Helper::Model::LDAP>

=item *

L<Catalyst::Helper::Model::Adaptor> - wrap any class into a Catalyst model

=back

=head3 NOTE

The helpers will read author name from /etc/passwd by default.
To override, please export the AUTHOR variable.

=head1 METHODS

=head2 mk_compclass

This method in your Helper module is called with C<$helper>
which is a L<Catalyst::Helper> object, and whichever other arguments
the user added to the command-line. You can use the $helper to call methods
described below.

If the Helper module does not contain a C<mk_compclass> method, it
will fall back to calling L</render_file>, with an argument of
C<compclass>.

=head2 mk_comptest

This method in your Helper module is called with C<$helper>
which is a L<Catalyst::Helper> object, and whichever other arguments
the user added to the command-line. You can use the $helper to call methods
described below.

If the Helper module does not contain a C<mk_compclass> method, it
will fall back to calling L</render_file>, with an argument of
C<comptest>.

=head2 mk_stuff

This method is called if the user does not supply any of the usual
component types C<view>, C<controller>, C<model>. It is passed the
C<$helper> object (an instance of L<Catalyst::Helper>), and any other
arguments the user typed.

There is no fallback for this method.

=head1 INTERNAL METHODS

These are the methods that the Helper classes can call on the
<$helper> object passed to them.

=head2 render_file ($file, $path, $vars)

Render and create a file from a template in DATA using Template
Toolkit. $file is the relevent chunk of the __DATA__ section, $path is
the path to the file and $vars is the hashref as expected by
L<Template Toolkit|Template>.

=head2 get_file ($class, $file)

Fetch file contents from the DATA section. This is used internally by
L</render_file>.  $class is the name of the class to get the DATA
section from.  __PACKAGE__ or ( caller(0) )[0] might be sensible
values for this.

=head2 mk_app

Create the main application skeleton. This is called by L<catalyst.pl>.

=head2 mk_component ($app)

This method is called by L<create.pl> to make new components
for your application.

=head2 mk_dir ($path)

Surprisingly, this function makes a directory.

=head2 mk_file ($file, $content)

Writes content to a file. Called by L</render_file>.

=head2 next_test ($test_name)

Calculates the name of the next numbered test file and returns it.
Don't give the number or the .t suffix for the test name.

=cut

=head2 get_sharedir_file

Method for getting a file out of share/

=cut

=head2 render_file_contents

Process a L<Template::Toolkit> template.

=cut

=head2 render_sharedir_file

Render a template/image file from our share directory

=cut

=head1 NOTE

The helpers will read author name from /etc/passwd by default.
To override, please export the AUTHOR variable.

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Test>, L<Catalyst::Request>,
L<Catalyst::Response>, L<Catalyst>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

