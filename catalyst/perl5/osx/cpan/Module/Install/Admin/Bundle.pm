package Module::Install::Admin::Bundle;

use strict;
use Module::Install::Base;

use vars qw{$VERSION @ISA};
BEGIN {
	$VERSION = '0.91';;
	@ISA     = qw{Module::Install::Base};
}

sub bundle {
    my $self       = shift;
    my $bundle_dir = $self->_top->{bundle};

    require Cwd;
    require CPANPLUS::Backend;

    my $cwd = Cwd::getcwd();

    # This code is what we _should_ be doing, but CPANPLUS doesn't
    # let you have multiple Backends in one program.
    # my $cp   = CPANPLUS::Backend->new;
    #
    # Jos Boumans tells us that this is the best way to do what we want
    # It still scares me.
    my $cp      = CPANPLUS::Internals->_retrieve_id( CPANPLUS::Internals->_last_id )
               || CPANPLUS::Backend->new;
    my $conf    = $cp->configure_object;
    my $modtree = $cp->module_tree;

    $conf->set_conf( verbose   => 1 );
    $conf->set_conf( signature => 0 );
    $conf->set_conf( md5       => 0 );

    mkdir $bundle_dir;

    my %bundles;

    while ( my ( $name, $version ) = splice( @_, 0, 2 ) ) {
        my $mod = $cp->module_tree($name);
        next unless $mod;
        if ( $mod->package_is_perl_core or $self->{already_bundled}{$mod->package} ) {
        	next;
        }

        my $where = $mod->fetch( fetchdir => $bundle_dir, );
        next unless ($where);
        my $file = Cwd::abs_path($where);

        my $extract_result = $mod->extract(
            files      => [ $file ],
            extractdir => $bundle_dir,
        );

        unlink $file;
        next unless ($extract_result);
        $bundles{$name} = $extract_result;
        $self->{already_bundled}{ $mod->package }++;

    }

    chdir $cwd;

    local *FH;
    open FH, ">> $bundle_dir.yml" or die "Cannot write to $bundle_dir.yml: $!";
    foreach my $name ( sort keys %bundles ) {
        print FH "$name: '$bundles{$name}'\n";
    }
    close FH;
}

1;
