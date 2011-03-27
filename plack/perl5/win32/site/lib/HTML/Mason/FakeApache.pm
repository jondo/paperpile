use strict;
use warnings;

# We need to define an Apache package or we might get strange errors
# like "Can't locate package Apache for
# @HTML::Mason::FakeApache::ISA".  We do the BEGIN/eval thing so that
# the CPAN indexer doesn't pick it up, which would be ugly.
BEGIN { eval "package Apache" }

package HTML::Mason::FakeApache;
@HTML::Mason::FakeApache::ISA = qw(Apache);
# Analogous to Apache request object $r (but not an actual Apache subclass)
# In the future we'll probably want to switch this to Apache::Fake or similar

use HTML::Mason::MethodMaker(read_write => [qw(query)]);

sub new {
    my $class = shift;
    my %p = @_;
    return bless {
                  query           => $p{cgi} || CGI->new,
                  headers_out     => HTML::Mason::FakeTable->new,
                  err_headers_out => HTML::Mason::FakeTable->new,
                  pnotes          => {},
                 }, $class;
}

# CGI request are _always_ main, and there is never a previous or a next
# internal request.
sub main {}
sub prev {}
sub next {}
sub is_main {1}
sub is_initial_req {1}

# What to do with this?
# sub allowed {}

sub method {
    $_[0]->query->request_method;
}

# There mut be a mapping for this.
# sub method_number {}

# Can CGI.pm tell us this?
# sub bytes_sent {0}

# The request line sent by the client." Poached from Apache::Emulator.
sub the_request {
    my $self = shift;
    $self->{the_request} ||= join ' ', $self->method,
      ( $self->{query}->query_string
        ? $self->uri . '?' . $self->{query}->query_string
        : $self->uri ),
      $self->{query}->server_protocol;
}

# Is CGI ever a proxy request?
# sub proxy_req {}

sub header_only { $_[0]->method eq 'HEAD' }

sub protocol { $ENV{SERVER_PROTOCOL} || 'HTTP/1.0' }

sub hostname { $_[0]->{query}->server_name }

# CGI says "use this when using virtual hosts".  It falls back to
# CGI->server_port.
sub get_server_port { $_[0]->{query}->virtual_port }

# Fake it by just giving the current time.
sub request_time { time }

sub uri {
    my $self = shift;

    $self->{uri} ||= $self->{query}->script_name . $self->path_info || '';
}

# Is this available in CGI?
# sub filename {}

# "The $r->location method will return the path of the
# <Location> section from which the current "Perl*Handler"
# is being called." This is irrelevant, I think.
# sub location {}

sub path_info { $_[0]->{query}->path_info }

sub args {
    my $self = shift;
    if (@_) {
        # Assign args here.
    }
    return $self->{query}->Vars unless wantarray;
    # Do more here to return key => arg values.
}

sub headers_in {
    my $self = shift;

    # Create the headers table if necessary. Decided how to build it based on
    # information here:
    # http://cgi-spec.golux.com/draft-coar-cgi-v11-03-clean.html#6.1
    #
    # Try to get as much info as possible from CGI.pm, which has
    # workarounds for things like the IIS PATH_INFO bug.
    #
    $self->{headers_in} ||= HTML::Mason::FakeTable->new
      ( 'Authorization'       => $self->{query}->auth_type, # No credentials though.
        'Content-Length'      => $ENV{CONTENT_LENGTH},
        'Content-Type'        =>
        ( $self->{query}->can('content_type') ?
          $self->{query}->content_type :
          $ENV{CONTENT_TYPE}
        ),
        # Convert HTTP environment variables back into their header names.
        map {
            my $k = ucfirst lc;
            $k =~ s/_(.)/-\u$1/g;
            ( $k => $self->{query}->http($_) )
        } grep { s/^HTTP_// } keys %ENV
      );


    # Give 'em the hash list of the hash table.
    return wantarray ? %{$self->{headers_in}} : $self->{headers_in};
}

sub header_in {
    my ($self, $header) = (shift, shift);
    my $h = $self->headers_in;
    return @_ ? $h->set($header, shift) : $h->get($header);
}


#           The $r->content method will return the entity body
#           read from the client, but only if the request content
#           type is "application/x-www-form-urlencoded".  When
#           called in a scalar context, the entire string is
#           returned.  When called in a list context, a list of
#           parsed key => value pairs are returned.  *NOTE*: you
#           can only ask for this once, as the entire body is read
#           from the client.
# Not sure what to do with this one.
# sub content {}

# I think this may be irrelevant under CGI.
# sub read {}

# Use LWP?
sub get_remote_host {}
sub get_remote_logname {}

sub http_header {
    my $self = shift;
    my $h = $self->headers_out;
    my $e = $self->err_headers_out;
    my $method = exists $h->{Location} || exists $e->{Location} ?
      'redirect' : 'header';
    return $self->query->$method(tied(%$h)->cgi_headers,
                                 tied(%$e)->cgi_headers);
}

sub send_http_header {
    my $self = shift;

    return if $self->http_header_sent;

    print STDOUT $self->http_header;

    $self->{http_header_sent} = 1;
}

sub http_header_sent { shift->{http_header_sent} }

# How do we know this under CGI?
# sub get_basic_auth_pw {}
# sub note_basic_auth_failure {}

# I think that this just has to be empty.
sub handler {}

sub notes {
    my ($self, $key) = (shift, shift);
    $self->{notes} ||= HTML::Mason::FakeTable->new;
    return wantarray ? %{$self->{notes}} : $self->{notes}
      unless defined $key;
    return $self->{notes}{$key} = "$_[0]" if @_;
    return $self->{notes}{$key};
}

sub pnotes {
    my ($self, $key) = (shift, shift);
    return wantarray ? %{$self->{pnotes}} : $self->{pnotes}
      unless defined $key;
    return $self->{pnotes}{$key} = $_[0] if @_;
    return $self->{pnotes}{$key};
}

sub subprocess_env {
    my ($self, $key) = (shift, shift);
    unless (defined $key) {
        $self->{subprocess_env} = HTML::Mason::FakeTable->new(%ENV);
        return wantarray ? %{$self->{subprocess_env}} :
          $self->{subprocess_env};

    }
    $self->{subprocess_env} ||= HTML::Mason::FakeTable->new(%ENV);
    return $self->{subprocess_env}{$key} = "$_[0]" if @_;
    return $self->{subprocess_env}{$key};
}

sub content_type {
    shift->header_out('Content-Type', @_);
}

sub content_encoding {
    shift->header_out('Content-Encoding', @_);
}

sub content_languages {
    my ($self, $langs) = @_;
    return unless $langs;
    my $h = shift->headers_out;
    for my $l (@$langs) {
        $h->add('Content-Language', $l);
    }
}

sub status {
    shift->header_out('Status', @_);
}

sub status_line {
    # What to do here? Should it be managed differently than status?
    my $self = shift;
    if (@_) {
        my $status = shift =~ /^(\d+)/;
        return $self->header_out('Status', $status);
    }
    return $self->header_out('Status');
}

sub headers_out {
    my $self = shift;
    return wantarray ? %{$self->{headers_out}} : $self->{headers_out};
}

sub header_out {
    my ($self, $header) = (shift, shift);
    my $h = $self->headers_out;
    return @_ ? $h->set($header, shift) : $h->get($header);
}

sub err_headers_out {
    my $self = shift;
    return wantarray ? %{$self->{err_headers_out}} : $self->{err_headers_out};
}

sub err_header_out {
    my ($self, $err_header) = (shift, shift);
    my $h = $self->err_headers_out;
    return @_ ? $h->set($err_header, shift) : $h->get($err_header);
}

sub no_cache {
    my $self = shift;
    $self->header_out(Pragma => 'no-cache');
    $self->header_out('Cache-Control' => 'no-cache');
}

sub print {
    shift;
    print @_;
}

sub send_fd {
    my ($self, $fd) = @_;
    local $_;

    print STDOUT while defined ($_ = <$fd>);
}

# Should this perhaps throw an exception?
# sub internal_redirect {}
# sub internal_redirect_handler {}

# Do something with ErrorDocument?
# sub custom_response {}

# I think we've made this essentially the same thing.
BEGIN {
    local $^W;
    *send_cgi_header = \&send_http_header;
}

# Does CGI support logging?
# sub log_reason {}
# sub log_error {}
sub warn {
    shift;
    print STDERR @_, "\n";
}

sub params {
    my $self = shift;
    return HTML::Mason::Utils::cgi_request_args($self->query,
                                                $self->query->request_method);
}

1;

###########################################################
package HTML::Mason::FakeTable;
# Analogous to Apache::Table.
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = {};
    tie %{$self}, 'HTML::Mason::FakeTableHash';
    %$self = @_ if @_;
    return bless $self, ref $class || $class;
}

sub set {
    my ($self, $header, $value) = @_;
    defined $value ? $self->{$header} = $value : delete $self->{$header};
}

sub unset {
    my $self = shift;
    delete $self->{shift()};
}

sub add {
    tied(%{shift()})->add(@_);
}

sub clear {
    %{shift()} = ();
}

sub get {
    tied(%{shift()})->get(@_);
}

sub merge {
    my ($self, $key, $value) = @_;
    if (defined $self->{$key}) {
        $self->{$key} .= ',' . $value;
    } else {
        $self->{$key} = "$value";
    }
}

sub do {
    my ($self, $code) = @_;
    while (my ($k, $val) = each %$self) {
        for my $v (ref $val ? @$val : $val) {
            return unless $code->($k => $v);
        }
    }
}

###########################################################
package HTML::Mason::FakeTableHash;
# Used by HTML::Mason::FakeTable.
use strict;
use warnings;

sub TIEHASH {
    my $class = shift;
    return bless {}, ref $class || $class;
}

sub _canonical_key {
    my $key = lc shift;
    # CGI really wants a - before each header
    return substr( $key, 0, 1 ) eq '-' ? $key : "-$key";
}

sub STORE {
    my ($self, $key, $value) = @_;
    $self->{_canonical_key $key} = [ $key => ref $value ? "$value" : $value ];
}

sub add {
    my ($self, $key) = (shift, shift);
    return unless defined $_[0];
    my $value = ref $_[0] ? "$_[0]" : $_[0];
    my $ckey = _canonical_key $key;
    if (exists $self->{$ckey}) {
        if (ref $self->{$ckey}[1]) {
            push @{$self->{$ckey}[1]}, $value;
        } else {
            $self->{$ckey}[1] = [ $self->{$ckey}[1], $value ];
        }
    } else {
        $self->{$ckey} = [ $key => $value ];
    }
}

sub DELETE {
    my ($self, $key) = @_;
    my $ret = delete $self->{_canonical_key $key};
    return $ret->[1];
}

sub FETCH {
    my ($self, $key) = @_;
    # Grab the values first so that we don't autovivicate the key.
    my $val = $self->{_canonical_key $key} or return;
    if (my $ref = ref $val->[1]) {
        return unless $val->[1][0];
        # Return the first value only.
        return $val->[1][0];
    }
    return $val->[1];
}

sub get {
    my ($self, $key) = @_;
    my $ckey = _canonical_key $key;
    return unless exists $self->{$ckey};
    return $self->{$ckey}[1] unless ref $self->{$ckey}[1];
    return wantarray ? @{$self->{$ckey}[1]} : $self->{$ckey}[1][0];
}

sub CLEAR {
    %{shift()} = ();
}

sub EXISTS {
    my ($self, $key)= @_;
    return exists $self->{_canonical_key $key};
}

sub FIRSTKEY {
    my $self = shift;
    # Reset perl's iterator.
    keys %$self;
    # Get the first key via perl's iterator.
    my $first_key = each %$self;
    return undef unless defined $first_key;
    return $self->{$first_key}[0];
}

sub NEXTKEY {
    my ($self, $nextkey) = @_;
    # Get the next key via perl's iterator.
    my $next_key = each %$self;
    return undef unless defined $next_key;
    return $self->{$next_key}[0];
}

sub cgi_headers {
    my $self = shift;
    map { _map_header_key_to_cgi_key($_) => $self->{$_}[1] } keys %$self;
}

sub _map_header_key_to_cgi_key {
    return $_[0] eq '-set-cookie' ? '-cookies' : $_[0];
}

1;

__END__

=head1 NAME

HTML::Mason::FakeApache - An Apache object emulator for use with Mason

=head1 SYNOPSIS

See L<HTML::Mason::CGIHandler|HTML::Mason::CGIHandler>.

=head1 DESCRIPTION

This class's API is documented in L<HTML::Mason::CGIHandler|HTML::Mason::CGIHandler>.

=cut
