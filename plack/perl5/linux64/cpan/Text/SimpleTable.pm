package Text::SimpleTable;

use strict;

our $VERSION = '0.05';

our $TOP_LEFT      = '.-';
our $TOP_BORDER    = '-';
our $TOP_SEPARATOR = '-+-';
our $TOP_RIGHT     = '-.';

our $MIDDLE_LEFT      = '+-';
our $MIDDLE_BORDER    = '-';
our $MIDDLE_SEPARATOR = '-+-';
our $MIDDLE_RIGHT     = '-+';

our $LEFT_BORDER  = '| ';
our $SEPARATOR    = ' | ';
our $RIGHT_BORDER = ' |';

our $BOTTOM_LEFT      = "'-";
our $BOTTOM_SEPARATOR = "-+-";
our $BOTTOM_BORDER    = '-';
our $BOTTOM_RIGHT     = "-'";

our $WRAP = '-';

=head1 NAME

Text::SimpleTable - Simple Eyecandy ASCII Tables

=head1 SYNOPSIS

    use Text::SimpleTable;

    my $t1 = Text::SimpleTable->new( 5, 10 );
    $t1->row( 'foobarbaz', 'yadayadayada' );
    print $t1->draw;

    .-------+------------.
    | foob- | yadayaday- |
    | arbaz | ada        |
    '-------+------------'


    my $t2 = Text::SimpleTable->new( [ 5, 'Foo' ], [ 10, 'Bar' ] );
    $t2->row( 'foobarbaz', 'yadayadayada' );
    $t2->row( 'barbarbarbarbar', 'yada' );
    print $t2->draw;

    .-------+------------.
    | Foo   | Bar        |
    +-------+------------+
    | foob- | yadayaday- |
    | arbaz | ada        |
    | barb- | yada       |
    | arba- |            |
    | rbar- |            |
    | bar   |            |
    '-------+------------'


=head1 DESCRIPTION

Simple eyecandy ASCII tables, as seen in L<Catalyst>.

=head1 METHODS

=over 4

=cut

sub new {
    my ( $class, @args ) = @_;
    $class = ref $class || $class;
    my $self  = bless {}, $class;
    my $cache = [];
    my $max   = 0;
    for my $arg (@args) {
        my $width;
        my $name;
        if ( ref $arg ) {
            $width = $arg->[0];
            $name  = $arg->[1];
        }
        else { $width = $arg }
        my $title = $name ? $self->_wrap( $name, $width ) : [];
        my $col = [ $width, [], $title ];
        $max = @{ $col->[2] } if $max < @{ $col->[2] };
        push @$cache, $col;
    }
    for my $col (@$cache) {
        push @{ $col->[2] }, '' while @{ $col->[2] } < $max;
    }
    $self->{columns} = $cache;
    return $self;
}

=item $table->row( @texts )

=cut

sub row {
    my ( $self, @texts ) = @_;
    my $size = @{ $self->{columns} } - 1;
    return $self if $size < 0;
    for ( 1 .. $size ) {
        last if $size <= @texts;
        push @texts, '';
    }
    my $cache = [];
    my $max   = 0;
    for my $i ( 0 .. $size ) {
        my $text   = shift @texts;
        my $column = $self->{columns}->[$i];
        my $width  = $column->[0];
        my $pieces = $self->_wrap( $text, $width );
        push @{ $cache->[$i] }, @$pieces;
        $max = @$pieces if @$pieces > $max;
    }
    for my $col ( @{$cache} ) { push @{$col}, '' while @{$col} < $max }
    for my $i ( 0 .. $size ) {
        my $column = $self->{columns}->[$i];
        my $store  = $column->[1];
        push @{$store}, @{ $cache->[$i] };
    }
    return $self;
}

=item $table->draw

=cut

sub draw {
    my $self = shift;
    return unless $self->{columns};
    my $rows    = @{ $self->{columns}->[0]->[1] } - 1;
    my $columns = @{ $self->{columns} } - 1;
    my $output  = '';

    # Top border
    for my $j ( 0 .. $columns ) {
        my $column = $self->{columns}->[$j];
        my $width  = $column->[0];
        my $text   = $TOP_BORDER x $width;
        if ( ( $j == 0 ) && ( $columns == 0 ) ) {
            $text = "$TOP_LEFT$text$TOP_RIGHT";
        }
        elsif ( $j == 0 )        { $text = "$TOP_LEFT$text$TOP_SEPARATOR" }
        elsif ( $j == $columns ) { $text = "$text$TOP_RIGHT" }
        else { $text = "$text$TOP_SEPARATOR" }
        $output .= $text;
    }
    $output .= "\n";

    my $title = 0;
    for my $column ( @{ $self->{columns} } ) {
        $title = @{ $column->[2] } if $title < @{ $column->[2] };
    }
    if ($title) {

        # Titles
        for my $i ( 0 .. $title - 1 ) {

            for my $j ( 0 .. $columns ) {
                my $column = $self->{columns}->[$j];
                my $width  = $column->[0];
                my $text   = $column->[2]->[$i] || '';
                $text = sprintf "%-${width}s", $text;
                if ( ( $j == 0 ) && ( $columns == 0 ) ) {
                    $text = "$LEFT_BORDER$text$RIGHT_BORDER";
                }
                elsif ( $j == 0 ) { $text = "$LEFT_BORDER$text$SEPARATOR" }
                elsif ( $j == $columns ) { $text = "$text$RIGHT_BORDER" }
                else { $text = "$text$SEPARATOR" }
                $output .= $text;
            }
            $output .= "\n";
        }

        # Title separator
        for my $j ( 0 .. $columns ) {
            my $column = $self->{columns}->[$j];
            my $width  = $column->[0];
            my $text   = $MIDDLE_BORDER x $width;
            if ( ( $j == 0 ) && ( $columns == 0 ) ) {
                $text = "$MIDDLE_LEFT$text$MIDDLE_RIGHT";
            }
            elsif ( $j == 0 ) { $text = "$MIDDLE_LEFT$text$MIDDLE_SEPARATOR" }
            elsif ( $j == $columns ) { $text = "$text$MIDDLE_RIGHT" }
            else { $text = "$text$MIDDLE_SEPARATOR" }
            $output .= $text;
        }
        $output .= "\n";

    }

    # Rows
    for my $i ( 0 .. $rows ) {

        for my $j ( 0 .. $columns ) {
            my $column = $self->{columns}->[$j];
            my $width  = $column->[0];
            my $text
                = ( defined $column->[1]->[$i] ) ? $column->[1]->[$i] : '';
            $text = sprintf "%-${width}s", $text;
            if ( ( $j == 0 ) && ( $columns == 0 ) ) {
                $text = "$LEFT_BORDER$text$RIGHT_BORDER";
            }
            elsif ( $j == 0 )        { $text = "$LEFT_BORDER$text$SEPARATOR" }
            elsif ( $j == $columns ) { $text = "$text$RIGHT_BORDER" }
            else { $text = "$text$SEPARATOR" }
            $output .= $text;
        }
        $output .= "\n";
    }

    # Bottom border
    for my $j ( 0 .. $columns ) {
        my $column = $self->{columns}->[$j];
        my $width  = $column->[0];
        my $text   = $BOTTOM_BORDER x $width;
        if ( ( $j == 0 ) && ( $columns == 0 ) ) {
            $text = "$BOTTOM_LEFT$text$BOTTOM_RIGHT";
        }
        elsif ( $j == 0 ) { $text = "$BOTTOM_LEFT$text$BOTTOM_SEPARATOR" }
        elsif ( $j == $columns ) { $text = "$text$BOTTOM_RIGHT" }
        else { $text = "$text$BOTTOM_SEPARATOR" }
        $output .= $text;
    }
    $output .= "\n";

    return $output;
}

sub _wrap {
    my ( $self, $text, $width ) = @_;
    my @cache;
    my @parts = split "\n", $text;
    for my $part (@parts) {
        while ( length $part > $width ) {
            my $subtext;
            $subtext = substr $part, 0, $width - length($WRAP), '';
            push @cache, "$subtext$WRAP";
        }
        push @cache, $part if defined $part;
    }
    return \@cache;
}

=back

=head1 SEE ALSO

L<Catalyst>

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
