# -*- cperl-indent-level: 4; cperl-continued-brace-offset: -4; cperl-continued-statement-offset: 4 -*-

# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

use strict;
use warnings;

package HTML::Mason::ApacheHandler;

use vars qw($VERSION);
# do not change the version number
$VERSION = 1.69;


# PerlAddVar was introduced in mod_perl-1.24
# Support for modperl2 < 1.999022 was removed due to API changes
BEGIN
{
    if ( $ENV{MOD_PERL} && $ENV{MOD_PERL} =~ /1\.99|2\.0/ )
    {
        require mod_perl2;
    }
    elsif ( $ENV{MOD_PERL} )
    {
        require mod_perl;
    }

    my $mpver = (mod_perl2->VERSION || mod_perl->VERSION || 0);

    # This is the version that introduced PerlAddVar
    if ($mpver && $mpver < 1.24)
    {
        die "mod_perl VERSION >= 1.24 required";
    }
    elsif ($mpver >= 1.99 && $mpver < 1.999022)
    {
        die "mod_perl-1.99 is not supported; upgrade to 2.00";
    }
}

#----------------------------------------------------------------------
#
# APACHE-SPECIFIC REQUEST OBJECT
#
package HTML::Mason::Request::ApacheHandler;

use HTML::Mason::Request;
use Class::Container;
use Params::Validate qw(BOOLEAN);
Params::Validate::validation_options( on_fail => sub { param_error( join '', @_ ) } );

use base qw(HTML::Mason::Request);

use HTML::Mason::Exceptions( abbr => [qw(param_error error)] );

use constant APACHE2    => ($mod_perl2::VERSION || $mod_perl::VERSION || 0) >= 1.999022;
use constant OK         => 0;
use constant HTTP_OK    => 200;
use constant DECLINED   => -1;
use constant NOT_FOUND  => 404;
use constant REDIRECT   => 302;

BEGIN
{
    my $ap_req_class = APACHE2 ? 'Apache2::RequestRec' : 'Apache';

    __PACKAGE__->valid_params
        ( ah         => { isa => 'HTML::Mason::ApacheHandler',
                          descr => 'An ApacheHandler to handle web requests',
                          public => 0 },

          apache_req => { isa => $ap_req_class, default => undef,
                          descr => "An Apache request object",
                          public => 0 },

          cgi_object => { isa => 'CGI',    default => undef,
                          descr => "A CGI.pm request object",
                          public => 0 },

          auto_send_headers => { parse => 'boolean', type => BOOLEAN, default => 1,
                                 descr => "Whether HTTP headers should be auto-generated" },
        );
}

use HTML::Mason::MethodMaker
    ( read_write => [ map { [ $_ => __PACKAGE__->validation_spec->{$_} ] }
                      qw( ah apache_req auto_send_headers ) ] );

# A hack for subrequests
sub _properties { qw(ah apache_req), shift->SUPER::_properties }

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);  # Magic!

    unless ($self->apache_req or $self->cgi_object)
    {
        param_error __PACKAGE__ . "->new: must specify 'apache_req' or 'cgi_object' parameter";
    }

    # Record a flag indicating whether the user passed a custom out_method
    my %params = @_;
    $self->ah->{has_custom_out_method} = exists $params{out_method};

    return $self;
}

sub cgi_object
{
    my ($self) = @_;

    error "Can't call cgi_object() unless 'args_method' is set to CGI.\n"
        unless $self->ah->args_method eq 'CGI';

    if (defined($_[1])) {
        $self->{cgi_object} = $_[1];
    } else {
        # We may not have created a CGI object if, say, request was a
        # GET with no query string. Create one on the fly if necessary.
        $self->{cgi_object} ||= CGI->new('');
    }

    return $self->{cgi_object};
}

#
# Override this method to return NOT_FOUND when we get a
# TopLevelNotFound exception. In case of POST we must trick
# Apache into not reading POST content again. Wish there were
# a more standardized way to do this...
#
sub exec
{
    my $self = shift;
    my $r = $self->apache_req;
    my $retval;

    if ( $self->is_subrequest )
    {
        # no need to go through all the rigamorale below for
        # subrequests, and it may even break things to do so, since
        # $r's print should only be redefined once.
        $retval = $self->SUPER::exec(@_);
    }
    else
    {
        # ack, this has to be done at runtime to account for the fact
        # that Apache::Filter changes $r's class and implements its
        # own print() method.
        my $real_apache_print = $r->can('print');

        # Remap $r->print to Mason's $m->print while executing
        # request, but just for this $r, in case user does an internal
        # redirect or apache subrequest.
        local $^W = 0;
        no strict 'refs';

        my $req_class = ref $r;
        no warnings 'redefine';
        local *{"$req_class\::print"} = sub {
            my $local_r = shift;
            return $self->print(@_) if $local_r eq $r;
            return $local_r->$real_apache_print(@_);
        };
        $retval = $self->SUPER::exec(@_);
    }

    # On a success code, send headers if they have not been sent and
    # if we are the top-level request. Since the out_method sends
    # headers, this will typically only apply after $m->abort.
    # On an error code, leave it to Apache to send the headers.
    if (    !$self->is_subrequest
         and !APACHE2
         and $self->auto_send_headers
         and !$r->notes('mason-sent-headers')
         and ( !$retval or $retval eq HTTP_OK ) ) {

        $r->send_http_header();
    }

    # mod_perl 1 treats HTTP_OK and OK the same, but mod_perl-2 does not.
    return defined $retval && $retval ne HTTP_OK ? $retval : OK;
}

#
# Override this method to always die when top level component is not found,
# so we can return NOT_FOUND.
#
sub _handle_error
{
    my ($self, $err) = @_;

    if (isa_mason_exception($err, 'TopLevelNotFound')) {
        rethrow_exception $err;
    } else {
        if ( $self->error_format eq 'html' ) {
            $self->apache_req->content_type('text/html');

            unless (APACHE2) {
                $self->apache_req->send_http_header;
            }
        }
        $self->SUPER::_handle_error($err);
    }
}

sub redirect
{
    my ($self, $url, $status) = @_;
    my $r = $self->apache_req;

    $r->method('GET');
    $r->headers_in->unset('Content-length');
    $r->err_headers_out->{Location} = $url;
    $self->clear_and_abort($status || REDIRECT);
}

#----------------------------------------------------------------------
#
# APACHEHANDLER OBJECT
#
package HTML::Mason::ApacheHandler;

use File::Path;
use File::Spec;
use HTML::Mason::Exceptions( abbr => [qw(param_error system_error error)] );
use HTML::Mason::Interp;
use HTML::Mason::Tools qw( load_pkg );
use HTML::Mason::Utils;
use Params::Validate qw(:all);
Params::Validate::validation_options( on_fail => sub { param_error( join '', @_ ) } );

use constant APACHE2    => ($mod_perl2::VERSION || $mod_perl::VERSION || 0) >= 1.999022;
use constant OK         => 0;
use constant HTTP_OK    => 200;
use constant DECLINED   => -1;
use constant NOT_FOUND  => 404;
use constant REDIRECT   => 302;

BEGIN {
   if ($ENV{MOD_PERL}) {
        if (APACHE2) {
            require Apache2::RequestRec;
            require Apache2::RequestIO;
            require Apache2::ServerUtil;
            require Apache2::RequestUtil;
            require Apache2::Log;
            require APR::Table;
        } else {
            require Apache;
            require Apache::Request;
            require HTML::Mason::Apache::Request;
            Apache->import();
        }
    }
}

if ( $ENV{MOD_PERL} && ! APACHE2 )
{
    # No modern distro/OS packages a mod_perl without all of this
    # stuff turned on, does it?

    error "mod_perl must be compiled with PERL_METHOD_HANDLERS=1 (or EVERYTHING=1) to use ", __PACKAGE__, "\n"
        unless Apache::perl_hook('MethodHandlers');

    error "mod_perl must be compiled with PERL_TABLE_API=1 (or EVERYTHING=1) to use ", __PACKAGE__, "\n"
        unless Apache::perl_hook('TableApi');
}

use base qw(HTML::Mason::Handler);

BEGIN
{
    __PACKAGE__->valid_params
        (
         apache_status_title =>
         { parse => 'string', type => SCALAR, default => 'HTML::Mason status',
           descr => "The title of the Apache::Status page" },

         args_method =>
         { parse => 'string',  type => SCALAR,
           default => APACHE2 ? 'CGI' : 'mod_perl',
           regex => qr/^(?:CGI|mod_perl)$/,
           descr => "Whether to use CGI.pm or Apache::Request for parsing the incoming HTTP request",
         },

         decline_dirs =>
         { parse => 'boolean', type => BOOLEAN, default => 1,
           descr => "Whether Mason should decline to handle requests for directories" },

         # the only required param
         interp =>
         { isa => 'HTML::Mason::Interp',
           descr => "A Mason interpreter for processing components" },
        );

    __PACKAGE__->contained_objects
        (
         interp =>
         { class => 'HTML::Mason::Interp',
           descr => 'The interp class coordinates multiple objects to handle request execution'
         },
        );
}

use HTML::Mason::MethodMaker
    ( read_only  => [ 'args_method' ],
      read_write => [ map { [ $_ => __PACKAGE__->validation_spec->{$_} ] }
                      qw( apache_status_title
                          decline_dirs
                          interp ) ]
    );

sub _get_apache_server
{
        return APACHE2 ? Apache2::ServerUtil->server() : Apache->server();
}

my ($STARTED);

# The "if _get_apache_server" bit is a hack to let this module load
# when not under mod_perl, which is needed to generate Params.pod
__PACKAGE__->_startup() if eval { _get_apache_server };
sub _startup
{
    my $pack = shift;
    return if $STARTED++; # Allows a subclass to call this method without running it twice

    if ( my $args_method = $pack->_get_string_param('MasonArgsMethod') )
    {
        if ($args_method eq 'CGI')
        {
            eval { require CGI unless defined CGI->VERSION; };
            # mod_perl2 does not warn about this, so somebody should
            if (APACHE2 && CGI->VERSION < 3.08) {
                die "CGI version 3.08 is required to support mod_perl2 API";
            }
            die $@ if $@;
        }
        elsif ( $args_method eq 'mod_perl' && APACHE2 )
        {
            eval "require Apache2::Request" unless defined Apache2::Request->VERSION;
        }
    }
}

# Register with Apache::Status at module startup.  Will get replaced
# with a more informative status once an interpreter has been created.
my $status_name = 'mason0001';
my $apstat_module = APACHE2 ? 'Apache2::Status' : 'Apache::Status';
if ( load_pkg($apstat_module) )
{
    $apstat_module->menu_item
        ($status_name => __PACKAGE__->allowed_params->{apache_status_title}{default},
         sub { ["<b>(no interpreters created in this child yet)</b>"] });
}


my %AH_BY_CONFIG;
sub make_ah
{
    my ($package, $r) = @_;

    my $config = $r->dir_config;

    #
    # If the user has virtual hosts, each with a different document
    # root, then we will have to be called from the handler method.
    # This means we have an active request.  In order to distinguish
    # between virtual hosts with identical config directives that have
    # no comp root defined (meaning they expect to use the default
    # comp root), we append the document root for the current request
    # to the key.
    #
    my $key =
        ( join $;,
          $r->document_root,
          map { $_, sort $config->get($_) }
          grep { /^Mason/ }
          keys %$config
        );

    return $AH_BY_CONFIG{$key} if exists $AH_BY_CONFIG{$key};

    my %p = $package->_get_mason_params($r);

    # can't use hash_list for this one because it's _either_ a string
    # or a hash_list
    if (exists $p{comp_root}) {
        if (@{$p{comp_root}} == 1 && $p{comp_root}->[0] !~ /=>/) {
            $p{comp_root} = $p{comp_root}[0];  # Convert to a simple string
        } else {
            my @roots;
            foreach my $root (@{$p{comp_root}}) {
                $root = [ split /\s*=>\s*/, $root, 2 ];
                param_error "Configuration parameter MasonCompRoot must be either ".
                            "a single string value or multiple key/value pairs ".
                            "like 'foo => /home/mason/foo'.  Invalid parameter:\n$root"
                    unless defined $root->[1];

                push @roots, $root;
            }

            $p{comp_root} = \@roots;
        }
    }

    my $ah = $package->new(%p, $r);
    $AH_BY_CONFIG{$key} = $ah if $key;

    return $ah;
}

# The following routines handle getting information from $r->dir_config

sub calm_form {
    # Transform from StudlyCaps to name_like_this
    my ($self, $string) = @_;
    $string =~ s/^Mason//;
    $string =~ s/(^|.)([A-Z])/$1 ? "$1\L_$2" : "\L$2"/ge;
    return $string;
}

sub studly_form {
    # Transform from name_like_this to StudlyCaps
    my ($self, $string) = @_;
    $string =~ s/(?:^|_)(\w)/\U$1/g;
    return $string;
}

sub _get_mason_params
{
    my $self = shift;
    my $r = shift;

    my $config = $r ? $r->dir_config : _get_apache_server->dir_config;

    # Get all params starting with 'Mason'
    my %candidates;

    foreach my $studly ( keys %$config )
    {
        (my $calm = $studly) =~ s/^Mason// or next;
        $calm = $self->calm_form($calm);

        $candidates{$calm} = $config->{$studly};
    }

    return unless %candidates;

    #
    # We will accumulate all the string versions of the keys and
    # values here for later use.
    #
    return ( map { $_ =>
                   scalar $self->_get_param( $_, \%candidates, $config, $r )
                 }
             keys %candidates );
}

sub _get_param {
    # Gets a single config item from dir_config.

    my ($self, $key, $candidates, $config, $r) = @_;

    $key = $self->calm_form($key);

    my $spec = $self->allowed_params( $candidates || {} )->{$key}
        or error "Unknown config item '$key'";

    # Guess the default parse type from the Params::Validate validation spec
    my $type = ($spec->{parse} or
                $spec->{type} & ARRAYREF ? 'list' :
                $spec->{type} & SCALAR   ? 'string' :
                $spec->{type} & CODEREF  ? 'code' :
                undef)
        or error "Unknown parse type for config item '$key'";

    my $method = "_get_${type}_param";
    return $self->$method('Mason'.$self->studly_form($key), $config, $r);
}

sub _get_string_param
{
    my $self = shift;
    return scalar $self->_get_val(@_);
}

sub _get_boolean_param
{
    my $self = shift;
    return scalar $self->_get_val(@_);
}

sub _get_code_param
{
    my $self = shift;
    my $p = $_[0];
    my $val = $self->_get_val(@_);

    return unless $val;

    my $sub_ref = eval $val;

    param_error "Configuration parameter '$p' is not valid perl:\n$@\n"
        if $@;

    return $sub_ref;
}

sub _get_list_param
{
    my $self = shift;
    my @val = $self->_get_val(@_);
    if (@val == 1 && ! defined $val[0])
    {
        @val = ();
    }

    return \@val;
}

sub _get_hash_list_param
{
    my $self = shift;
    my @val = $self->_get_val(@_);
    if (@val == 1 && ! defined $val[0])
    {
        return {};
    }

    my %hash;
    foreach my $pair (@val)
    {
        my ($key, $val) = split /\s*=>\s*/, $pair, 2;
        param_error "Configuration parameter $_[0] must be a key/value pair ".
                    qq|like "foo => bar".  Invalid parameter:\n$pair|
                unless defined $key && defined $val;

        $hash{$key} = $val;
    }

    return \%hash;
}

sub _get_val
{
    my ($self, $p, $config, $r) = @_;

    my @val;
    if (wantarray || !$config)
    {
        if ($config)
        {
            @val = $config->get($p);
        }
        else
        {
            my $c = $r ? $r : _get_apache_server;
            @val = $c->dir_config->get($p);
        }
    }
    else
    {
        @val = exists $config->{$p} ? $config->{$p} : ();
    }

    param_error "Only a single value is allowed for configuration parameter '$p'\n"
        if @val > 1 && ! wantarray;

    return wantarray ? @val : $val[0];
}

sub new
{
    my $class = shift;

    # Get $r off end of params if its there
    my $r;
    $r = pop() if @_ % 2;
    my %params = @_;

    my %defaults;
    $defaults{request_class}  = 'HTML::Mason::Request::ApacheHandler'
        unless exists $params{request};

    my $allowed_params = $class->allowed_params(%defaults, %params);

    if ( exists $allowed_params->{comp_root} and
         my $req = $r || (APACHE2 ? undef : Apache->request) )  # DocumentRoot is only available inside requests
    {
        $defaults{comp_root} = $req->document_root;
    }

    if (exists $allowed_params->{data_dir} and not exists $params{data_dir})
    {
        # constructs path to <server root>/mason
        if (UNIVERSAL::can('Apache2::ServerUtil','server_root')) {
                $defaults{data_dir} = File::Spec->catdir(Apache2::ServerUtil::server_root(),'mason');
        } else {
                $defaults{data_dir} = Apache->server_root_relative('mason');
        }
        my $def = $defaults{data_dir};
        param_error "Default data_dir (MasonDataDir) '$def' must be an absolute path"
            unless File::Spec->file_name_is_absolute($def);
          
        my @levels = File::Spec->splitdir($def);
        param_error "Default data_dir (MasonDataDir) '$def' must be more than two levels deep (or must be set explicitly)"
            if @levels <= 3;
    }

    # Set default error_format based on error_mode
    if (exists($params{error_mode}) and $params{error_mode} eq 'fatal') {
        $defaults{error_format} = 'line';
    } else {
        $defaults{error_mode} = 'output';
        $defaults{error_format} = 'html';
    }

    # Push $r onto default allow_globals
    if (exists $allowed_params->{allow_globals}) {
        if ( $params{allow_globals} ) {
            push @{ $params{allow_globals} }, '$r';
        } else {
            $defaults{allow_globals} = ['$r'];
        }
    }

    my $self = eval { $class->SUPER::new(%defaults, %params) };

    # We catch this exception just to provide a better error message
    if ( $@ && isa_mason_exception( $@, 'Params' ) && $@->message =~ /comp_root/ )
    {
        param_error "No comp_root specified and cannot determine DocumentRoot." .
                    " Please provide comp_root explicitly.";
    }
    rethrow_exception $@;

    unless ( $self->interp->resolver->can('apache_request_to_comp_path') )
    {
        error "The resolver class your Interp object uses does not implement " .
              "the 'apache_request_to_comp_path' method.  This means that ApacheHandler " .
              "cannot resolve requests.  Are you using a handler.pl file created ".
              "before version 1.10?  Please see the handler.pl sample " .
              "that comes with the latest version of Mason.";
    }

    # If we're running as superuser, change file ownership to http user & group
    if (!($> || $<) && $self->interp->files_written)
    {
        chown $self->get_uid_gid, $self->interp->files_written
            or system_error( "Can't change ownership of files written by interp object: $!\n" );
    }

    $self->_initialize;
    return $self;
}

sub get_uid_gid
{
    return (Apache->server->uid, Apache->server->gid) unless APACHE2;

    # Apache2 lacks $s->uid.
    # Workaround by searching the config tree.
    require Apache2::Directive;

    my $conftree = Apache2::Directive::conftree();
    my $user = $conftree->lookup('User');
    my $group = $conftree->lookup('Group');

    $user =~ s/^["'](.*)["']$/$1/;
    $group =~ s/^["'](.*)["']$/$1/;

    my $uid = $user ? getpwnam($user) : $>;
    my $gid = $group ? getgrnam($group) : $);

    return ($uid, $gid);
}

sub _initialize {
    my ($self) = @_;

    my $apreq_module = APACHE2 ? 'Apache2::Request' : 'Apache::Request';
    if ($self->args_method eq 'mod_perl') {
        unless (defined $apreq_module->VERSION) {
            warn "Loading $apreq_module at runtime.  You could " .
                 "increase shared memory between Apache processes by ".
                 "preloading it in your httpd.conf or handler.pl file\n";
            eval "require $apreq_module";
        }
    } else {
        unless (defined CGI->VERSION) {
            warn "Loading CGI at runtime.  You could increase shared ".
                 "memory between Apache processes by preloading it in ".
                 "your httpd.conf or handler.pl file\n";

            require CGI;
        }
    }

    # Add an HTML::Mason menu item to the /perl-status page.
    my $apstat_module = APACHE2 ? 'Apache2::Status' : 'Apache::Status';
    if (defined $apstat_module->VERSION) {
        # A closure, carries a reference to $self
        my $statsub = sub {
            my ($r,$q) = @_; # request and CGI objects
            return [] if !defined($r);

            if ($r->path_info and $r->path_info =~ /expire_code_cache=(.*)/) {
                $self->interp->delete_from_code_cache($1);
            }

            return ["<center><h2>" . $self->apache_status_title . "</h2></center>" ,
                    $self->status_as_html(apache_req => $r),
                    $self->interp->status_as_html(ah => $self, apache_req => $r)];
        };
        local $^W = 0; # to avoid subroutine redefined warnings
        $apstat_module->menu_item($status_name, $self->apache_status_title, $statsub);
    }

    my $interp = $self->interp;

    #
    # Allow global $r in components
    #
    # This is somewhat redundant with code in new, but seems to be
    # needed since the user may simply create their own interp.
    #
    $interp->compiler->add_allowed_globals('$r')
        if $interp->compiler->can('add_allowed_globals');
}

# Generate HTML that describes ApacheHandler's current status.
# This is used in things like Apache::Status reports.

sub status_as_html {
    my ($self, %p) = @_;

    # Should I be scared about this?  =)

    my $comp_source = <<'EOF';
<h3>ApacheHandler properties:</h3>
<blockquote>
 <tt>
<table width="75%">
<%perl>
foreach my $property (sort keys %$ah) {
    my $val = $ah->{$property};
    my $default = ( defined $val && defined $valid{$property}{default} && $val eq $valid{$property}{default} ) || ( ! defined $val && exists $valid{$property}{default} && ! defined $valid{$property}{default} );

    my $display = $val;
    if (ref $val) {
        $display = '<font color="darkred">';
        # only object can ->can, others die
        my $is_object = eval { $val->can('anything'); 1 };
        if ($is_object) {
            $display .= ref $val . ' object';
        } else {
            if (UNIVERSAL::isa($val, 'ARRAY')) {
                $display .= 'ARRAY reference - [ ';
                $display .= join ', ', @$val;
                $display .= '] ';
            } elsif (UNIVERSAL::isa($val, 'HASH')) {
                $display .= 'HASH reference - { ';
                my @pairs;
                while (my ($k, $v) = each %$val) {
                   push @pairs, "$k => $v";
                }
                $display .= join ', ', @pairs;
                $display .= ' }';
            } else {
                $display = ref $val . ' reference';
            }
        }
        $display .= '</font>';
    }

    defined $display && $display =~ s,([\x00-\x1F]),'<font color="purple">control-' . chr( ord('A') + ord($1) - 1 ) . '</font>',eg; # does this work for non-ASCII?
</%perl>
 <tr valign="top" cellspacing="10">
  <td>
    <% $property | h %>
  </td>
  <td>
   <% defined $display ? $display : '<i>undef</i>' %>
   <% $default ? '<font color=green>(default)</font>' : '' %>
  </td>
 </tr>
% }
</table>
  </tt>
</blockquote>

<%args>
 $ah       # The ApacheHandler we'll elucidate
 %valid    # Contains default values for member data
</%args>
EOF

    my $interp = $self->interp;
    my $comp = $interp->make_component(comp_source => $comp_source);
    my $out;

    $self->interp->make_request
        ( comp => $comp,
          args => [ah => $self, valid => $interp->allowed_params],
          ah => $self,
          apache_req => $p{apache_req},
          out_method => \$out,
        )->exec;

    return $out;
}

sub handle_request
{
    my ($self, $r) = @_;

    my $req = $self->prepare_request($r);
    return $req unless ref($req);

    return $req->exec;
}

sub prepare_request
{
    my $self = shift;

    my $r = $self->_apache_request_object(@_);

    my $interp = $self->interp;

    my $fs_type = $self->_request_fs_type($r);

    return DECLINED if $fs_type eq 'dir' && $self->decline_dirs;

    #
    # Compute the component path via the resolver. Return NOT_FOUND on failure.
    #
    my $comp_path = $interp->resolver->apache_request_to_comp_path($r, $interp->comp_root_array);
    unless ($comp_path) {
        #
        # Append path_info if filename does not represent an existing file
        # (mainly for dhandlers).
        #
        my $pathname = $r->filename;
        $pathname .= $r->path_info unless $fs_type eq 'file';

        warn "[Mason] Cannot resolve file to component: " .
             "$pathname (is file outside component root?)";
        return $self->return_not_found($r);
    }

    my ($args, undef, $cgi_object) = $self->request_args($r);

    #
    # Set up interpreter global variables.
    #
    $interp->set_global( r => $r );

    # If someone is using a custom request class that doesn't accept
    # 'ah' and 'apache_req' that's their problem.
    #
    my $m = eval {
        $interp->make_request( comp => $comp_path,
                               args => [%$args],
                               ah => $self,
                               apache_req => $r,
                             );
    };

    if (my $err = $@) {
        # We rethrow everything but TopLevelNotFound, Abort, and Decline errors.
        
        if ( isa_mason_exception($@, 'TopLevelNotFound') ) {
            $r->log_error("[Mason] File does not exist: ", $r->filename . ($r->path_info || ""));
            return $self->return_not_found($r);
        }
        my $retval = ( isa_mason_exception($err, 'Abort')   ? $err->aborted_value  :
                       isa_mason_exception($err, 'Decline') ? $err->declined_value :
                       rethrow_exception $err );
        $retval = OK if defined $retval && $retval eq HTTP_OK;
        unless ($retval) {
            unless (APACHE2) {
                unless ($r->notes('mason-sent-headers')) {
                    $r->send_http_header();
                }
            }
        }
        return $retval;
    }

    $self->_set_mason_req_out_method($m, $r) unless $self->{has_custom_out_method};

    $m->cgi_object($cgi_object) if $m->can('cgi_object') && $cgi_object;

    return $m;
}

my $do_filter = sub { $_[0]->filter_register };
my $no_filter = sub { $_[0] };
sub _apache_request_object
{
    my $self = shift;

    # We need to be careful to never assign a new apache (subclass)
    # object to $r or we will leak memory, at least with mp1.
    my $new_r = APACHE2 ? $_[0] : HTML::Mason::Apache::Request->new( $_[0] );

    my $r_sub;
    if ( lc $_[0]->dir_config('Filter') eq 'on' )
    {
        die "To use Apache::Filter with Mason you must have at least version 1.021 of Apache::Filter\n"
            unless Apache::Filter->VERSION >= 1.021;

        $r_sub = $do_filter;
    }
    else
    {
        $r_sub = $no_filter;
    }

    my $apreq_instance =
          APACHE2
        ? sub { Apache2::Request->new( $_[0] ) }
        : sub { $_[0] };

    return
        $r_sub->( $self->args_method eq 'mod_perl' ?
                  $apreq_instance->( $new_r ) :
                  $new_r
                );
}

sub _request_fs_type
{
    my ($self, $r) = @_;

    #
    # If filename is a directory, then either decline or simply reset
    # the content type, depending on the value of decline_dirs.
    #
    # ** We should be able to use $r->finfo here, but finfo is broken
    # in some versions of mod_perl (e.g. see Shane Adams message on
    # mod_perl list on 9/10/00)
    #
    my $is_dir = -d $r->filename;

    return $is_dir ? 'dir' : -f _ ? 'file' : 'other';
}

sub request_args
{
    my ($self, $r) = @_;

    #
    # Get arguments from Apache::Request or CGI.
    #
    my ($args, $cgi_object);
    if ($self->args_method eq 'mod_perl') {
        $args = $self->_mod_perl_args($r);
    } else {
        $cgi_object = CGI->new;
        $args = $self->_cgi_args($r, $cgi_object);
    }

    # we return $r solely for backwards compatibility
    return ($args, $r, $cgi_object);
}

#
# Get $args hashref via CGI package
#
sub _cgi_args
{
    my ($self, $r, $q) = @_;

    # For optimization, don't bother creating a CGI object if request
    # is a GET with no query string
    return {} if $r->method eq 'GET' && !scalar($r->args);

    return HTML::Mason::Utils::cgi_request_args($q, $r->method);
}

#
# Get $args hashref via Apache::Request package.
#
sub _mod_perl_args
{
    my ($self, $apr) = @_;

    my %args;
    foreach my $key ( $apr->param ) {
        my @values = $apr->param($key);
        $args{$key} = @values == 1 ? $values[0] : \@values;
    }

    return \%args;
}

sub _set_mason_req_out_method
{
    my ($self, $m, $r) = @_;

    my $final_output_method = ($r->method eq 'HEAD' ?
                               sub {} :
                               $r->can('print'));

    # Craft the request's out method to handle http headers, content
    # length, and HEAD requests.
    my $out_method;
    if (APACHE2) {

        # mod_perl-2 does not need to call $r->send_http_headers
        $out_method = sub {
            $r->$final_output_method( grep { defined } @_ );
            $r->rflush;
        };

    } else {

        my $sent_headers = 0;
        $out_method = sub {

            # Send headers if they have not been sent by us or by user.
            # We use instance here because if we store $m we get a
            # circular reference and a big memory leak.
            if (!$sent_headers and HTML::Mason::Request->instance->auto_send_headers) {
                unless ($r->notes('mason-sent-headers')) {
                    $r->send_http_header();
                }
                $sent_headers = 1;
            }

            # Call $r->print (using the real Apache method, not our
            # overriden method).
            $r->$final_output_method( grep {defined} @_ );
            $r->rflush;
        };

    }

    $m->out_method($out_method);
}

# Utility function to prepare $r before returning NOT_FOUND.
sub return_not_found
{
    my ($self, $r) = @_;

    if ($r->method eq 'POST') {
        $r->method('GET');
        $r->headers_in->unset('Content-length');
    }
    return NOT_FOUND;
}

#
# PerlHandler HTML::Mason::ApacheHandler
#
BEGIN
{
    # A method handler is prototyped differently in mod_perl 1.x than in 2.x
    my $handler_code = sprintf <<'EOF', APACHE2 ? ': method' : '($$)';
sub handler %s
{
    my ($package, $r) = @_;

    my $ah;
    $ah ||= $package->make_ah($r);

    return $ah->handle_request($r);
}
EOF
    eval $handler_code;
    rethrow_exception $@;
}

1;

__END__

=head1 NAME

HTML::Mason::ApacheHandler - Mason/mod_perl interface

=head1 SYNOPSIS

    use HTML::Mason::ApacheHandler;

    my $ah = HTML::Mason::ApacheHandler->new (..name/value params..);
    ...
    sub handler {
        my $r = shift;
        $ah->handle_request($r);
    }

=head1 DESCRIPTION

The ApacheHandler object links Mason to mod_perl (version 1 or 2),
running components in response to HTTP requests. It is controlled
primarily through parameters to the new() constructor.

=head1 PARAMETERS TO THE new() CONSTRUCTOR

=over

=item apache_status_title

Title that you want this ApacheHandler to appear as under
Apache::Status.  Default is "HTML::Mason status".  This is useful if
you create more than one ApacheHandler object and want them all
visible via Apache::Status.

=item args_method

Method to use for unpacking GET and POST arguments. The valid options
are 'CGI' and 'mod_perl'; these indicate that a C<CGI.pm> or
C<Apache::Request> object (respectively) will be created for the
purposes of argument handling.

'mod_perl' is the default under mod_perl-1 and requires that you have 
installed the C<Apache::Request> package.  Under mod_perl-2, the default
is 'CGI' because C<Apache2::Request> is still in development.

If args_method is 'mod_perl', the C<$r> global is upgraded to an
Apache::Request object. This object inherits all Apache methods and
adds a few of its own, dealing with parameters and file uploads.  See
C<Apache::Request> for more information.

If the args_method is 'CGI', the Mason request object (C<$m>) will have a
method called C<cgi_object> available.  This method returns the CGI
object used for argument processing.

While Mason will load C<Apache::Request> or C<CGI> as needed at runtime, it
is recommended that you preload the relevant module either in your
F<httpd.conf> or F<handler.pl> file, as this will save some memory.

=item decline_dirs

True or false, default is true. Indicates whether Mason should decline
directory requests, leaving Apache to serve up a directory index or a
C<FORBIDDEN> error as appropriate. See the L<allowing directory requests|HTML::Mason::Admin/allowing directory requests> section of the administrator's manual
for more information about handling directories with Mason.

=item interp

The interpreter object to associate with this compiler. By default a
new object of the specified L<interp_class|HTML::Mason::Params/interp_class> will be created.

=item interp_class

The class to use when creating a interpreter. Defaults to
L<HTML::Mason::Interp|HTML::Mason::Interp>.

=back

=head1 ACCESSOR METHODS

All of the above properties, except interp_class, have standard accessor
methods of the same name: no arguments retrieves the value, and one
argument sets it, except for args_method, which is not settable.  For
example:

    my $ah = HTML::Mason::ApacheHandler->new;
    my $decline_dirs = $ah->decline_dirs;
    $ah->decline_dirs(1);

=head1 OTHER METHODS

The ApacheHandler object has a few other publically accessible methods
that may be of interest to end users.

=over 4

=item handle_request ($r)

This method takes an Apache or Apache::Request object representing a
request and translates that request into a form Mason can understand.
Its return value is an Apache status code.

Passing an Apache::Request object is useful if you want to set
Apache::Request parameters, such as POST_MAX or DISABLE_UPLOADS.

=item prepare_request ($r)

This method takes an Apache object representing a request and returns
a new Mason request object or an Apache status code.  If it is a
request object you can manipulate that object as you like, and then
call the request object's C<exec> method to have it generate output.

If this method returns an Apache status code, that means that it could
not create a Mason request object.

This method is useful if you would like to have a chance to decline a
request based on properties of the Mason request object or a component
object.  For example:

    my $req = $ah->prepare_request($r);
    # $req must be an Apache status code if it's not an object
    return $req unless ref($req);

    return DECLINED
        unless $req->request_comp->source_file =~ /\.html$/;

    $req->exec;

=item request_args ($r)

Given an Apache request object, this method returns a three item list.
The first item is a hash reference containing the arguments passed by
the client's request.

The second is an Apache request object.  This is returned for
backwards compatibility from when this method was responsible for
turning a plain Apache object into an Apache::Request object.

The third item may be a CGI.pm object or C<undef>, depending on the
value of the L<args_method|HTML::Mason::Params/args_method> parameter.

=back

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>,
L<HTML::Mason::Admin|HTML::Mason::Admin>,
L<HTML::Mason::Interp|HTML::Mason::Interp>

=cut
