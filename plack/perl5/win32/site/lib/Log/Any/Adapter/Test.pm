package Log::Any::Adapter::Test;
use Data::Dumper;
use Log::Any;
use Test::Builder;
use strict;
use warnings;
use base qw(Log::Any::Adapter::Core);

my $tb = Test::Builder->new();
my @msgs;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}

# All detection methods return true
#
foreach my $method ( Log::Any->detection_methods() ) {
    _make_method( $method, sub { 1 } );
}

# All logging methods push onto msgs array
#
foreach my $method ( Log::Any->logging_methods() ) {
    _make_method(
        $method,
        sub {
            my ( $self, $msg ) = @_;
            push(
                @msgs,
                {
                    message  => $msg,
                    level    => $method,
                    category => $self->{category}
                }
            );
        }
    );
}

# Testing methods below
#

sub msgs {
    my $self = shift;

    return \@msgs;
}

sub clear {
    my ($self) = @_;

    @msgs = ();
}

sub contains_ok {
    my ( $self, $regex, $test_name ) = @_;

    $test_name ||= "log contains '$regex'";
    my $found =
      _first_index( sub { $_->{message} =~ /$regex/ }, @{ $self->msgs } );
    if ( $found != -1 ) {
        splice( @{ $self->msgs }, $found, 1 );
        $tb->ok( 1, $test_name );
    }
    else {
        $tb->ok( 0, $test_name );
        $tb->diag( "could not find message matching $regex; log contains: "
              . _dump_one_line( $self->msgs ) );
    }
}

sub does_not_contain_ok {
    my ( $self, $regex, $test_name ) = @_;

    $test_name ||= "log does not contain '$regex'";
    my $found =
      first_index( sub { $_->{message} =~ /$regex/ }, @{ $self->msgs } );
    if ( $found != -1 ) {
        $tb->ok( 0, $test_name );
        $tb->diag( "found message matching $regex: " . $self->msgs->[$found] );
    }
    else {
        $tb->ok( 1, $test_name );
    }
}

sub empty_ok {
    my ( $self, $test_name ) = @_;

    $test_name ||= "log is empty";
    if ( !@{ $self->msgs } ) {
        $tb->ok( 1, $test_name );
    }
    else {
        $tb->ok( 0, $test_name );
        $tb->diag(
            "log is not empty; contains " . _dump_one_line( $self->msgs ) );
        $self->clear();
    }
}

sub contains_only_ok {
    my ( $self, $regex, $test_name ) = @_;

    $test_name ||= "log contains only '$regex'";
    my $count = scalar( @{ $self->msgs } );
    if ( $count == 1 ) {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        $self->contains_ok( $regex, $test_name );
    }
    else {
        $tb->ok( 0, $test_name );
        $tb->diag(
            "log contains $count messages: " . _dump_one_line( $self->msgs ) );
    }
}

sub _dump_one_line {
    my ($value) = @_;

    return Data::Dumper->new( [$value] )->Indent(0)->Sortkeys(1)->Quotekeys(0)
      ->Terse(1)->Dump();
}

sub _make_method {
    my ( $method, $code, $pkg ) = @_;

    $pkg ||= caller();
    no strict 'refs';
    *{ $pkg . "::$method" } = $code;
}

sub _first_index {
    my $f = shift;
    for my $i ( 0 .. $#_ ) {
        local *_ = \$_[$i];
        return $i if $f->();
    }
    return -1;
}

1;
