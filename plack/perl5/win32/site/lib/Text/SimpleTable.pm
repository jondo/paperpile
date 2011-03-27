# Copyright (C) 2005-2010, Sebastian Riedel.

package Text::SimpleTable;

use strict;
use warnings;

our $VERSION = '2.03';

# Top
our $TOP_LEFT      = '.-';
our $TOP_BORDER    = '-';
our $TOP_SEPARATOR = '-+-';
our $TOP_RIGHT     = '-.';

# Middle
our $MIDDLE_LEFT      = '+-';
our $MIDDLE_BORDER    = '-';
our $MIDDLE_SEPARATOR = '-+-';
our $MIDDLE_RIGHT     = '-+';

# Left
our $LEFT_BORDER  = '| ';
our $SEPARATOR    = ' | ';
our $RIGHT_BORDER = ' |';

# Bottom
our $BOTTOM_LEFT      = "'-";
our $BOTTOM_SEPARATOR = "-+-";
our $BOTTOM_BORDER    = '-';
our $BOTTOM_RIGHT     = "-'";

# Wrapper
our $WRAP = '-';

sub new {
    my ($class, @args) = @_;

    # Instantiate
    $class = ref $class || $class;
    my $self = bless {}, $class;

    # Columns and titles
    my $cache = [];
    my $max   = 0;
    for my $arg (@args) {
        my $width;
        my $name;

        if (ref $arg) {
            $width = $arg->[0];
            $name  = $arg->[1];
        }
        else { $width = $arg }

        # Fix size
        $width = 2 if $width < 2;

        # Wrap
        my $title = $name ? $self->_wrap($name, $width) : [];

        # Column
        my $col = [$width, [], $title];
        $max = @{$col->[2]} if $max < @{$col->[2]};
        push @$cache, $col;
    }

    # Padding
    for my $col (@$cache) {
        push @{$col->[2]}, '' while @{$col->[2]} < $max;
    }
    $self->{columns} = $cache;

    return $self;
}

# The implementation is not very elegant, but gets the job done very well
sub draw {
    my $self = shift;

    # Shortcut
    return unless $self->{columns};

    my $rows    = @{$self->{columns}->[0]->[1]} - 1;
    my $columns = @{$self->{columns}} - 1;
    my $output  = '';

    # Top border
    for my $j (0 .. $columns) {

        my $column = $self->{columns}->[$j];
        my $width  = $column->[0];
        my $text   = $TOP_BORDER x $width;

        if (($j == 0) && ($columns == 0)) {
            $text = "$TOP_LEFT$text$TOP_RIGHT";
        }
        elsif ($j == 0)        { $text = "$TOP_LEFT$text$TOP_SEPARATOR" }
        elsif ($j == $columns) { $text = "$text$TOP_RIGHT" }
        else                   { $text = "$text$TOP_SEPARATOR" }

        $output .= $text;
    }
    $output .= "\n";

    my $title = 0;
    for my $column (@{$self->{columns}}) {
        $title = @{$column->[2]} if $title < @{$column->[2]};
    }

    if ($title) {

        # Titles
        for my $i (0 .. $title - 1) {

            for my $j (0 .. $columns) {

                my $column = $self->{columns}->[$j];
                my $width  = $column->[0];
                my $text   = $column->[2]->[$i] || '';

                $text = sprintf "%-${width}s", $text;

                if (($j == 0) && ($columns == 0)) {
                    $text = "$LEFT_BORDER$text$RIGHT_BORDER";
                }
                elsif ($j == 0) { $text = "$LEFT_BORDER$text$SEPARATOR" }
                elsif ($j == $columns) { $text = "$text$RIGHT_BORDER" }
                else                   { $text = "$text$SEPARATOR" }

                $output .= $text;
            }

            $output .= "\n";
        }

        # Title separator
        $output .= $self->_draw_hr;

    }

    # Rows
    for my $i (0 .. $rows) {

        # Check for hr
        if (!grep { defined $self->{columns}->[$_]->[1]->[$i] } 0 .. $columns)
        {
            $output .= $self->_draw_hr;
            next;
        }

        for my $j (0 .. $columns) {

            my $column = $self->{columns}->[$j];
            my $width  = $column->[0];
            my $text = (defined $column->[1]->[$i]) ? $column->[1]->[$i] : '';

            $text = sprintf "%-${width}s", $text;

            if (($j == 0) && ($columns == 0)) {
                $text = "$LEFT_BORDER$text$RIGHT_BORDER";
            }
            elsif ($j == 0)        { $text = "$LEFT_BORDER$text$SEPARATOR" }
            elsif ($j == $columns) { $text = "$text$RIGHT_BORDER" }
            else                   { $text = "$text$SEPARATOR" }

            $output .= $text;
        }

        $output .= "\n";
    }

    # Bottom border
    for my $j (0 .. $columns) {

        my $column = $self->{columns}->[$j];
        my $width  = $column->[0];
        my $text   = $BOTTOM_BORDER x $width;

        if (($j == 0) && ($columns == 0)) {
            $text = "$BOTTOM_LEFT$text$BOTTOM_RIGHT";
        }
        elsif ($j == 0) { $text = "$BOTTOM_LEFT$text$BOTTOM_SEPARATOR" }
        elsif ($j == $columns) { $text = "$text$BOTTOM_RIGHT" }
        else                   { $text = "$text$BOTTOM_SEPARATOR" }

        $output .= $text;
    }

    $output .= "\n";

    return $output;
}

sub hr {
    my $self = shift;

    for (0 .. @{$self->{columns}} - 1) {
        push @{$self->{columns}->[$_]->[1]}, undef;
    }

    return $self;
}

sub row {
    my ($self, @texts) = @_;
    my $size = @{$self->{columns}} - 1;

    # Shortcut
    return $self if $size < 0;

    for (1 .. $size) {
        last if $size <= @texts;
        push @texts, '';
    }

    my $cache = [];
    my $max   = 0;

    for my $i (0 .. $size) {

        my $text   = shift @texts;
        my $column = $self->{columns}->[$i];
        my $width  = $column->[0];
        my $pieces = $self->_wrap($text, $width);

        push @{$cache->[$i]}, @$pieces;
        $max = @$pieces if @$pieces > $max;
    }

    for my $col (@{$cache}) { push @{$col}, '' while @{$col} < $max }

    for my $i (0 .. $size) {
        my $column = $self->{columns}->[$i];
        my $store  = $column->[1];
        push @{$store}, @{$cache->[$i]};
    }

    return $self;
}

sub _draw_hr {
    my $self    = shift;
    my $columns = @{$self->{columns}} - 1;
    my $output  = '';

    for my $j (0 .. $columns) {

        my $column = $self->{columns}->[$j];
        my $width  = $column->[0];
        my $text   = $MIDDLE_BORDER x $width;

        if (($j == 0) && ($columns == 0)) {
            $text = "$MIDDLE_LEFT$text$MIDDLE_RIGHT";
        }
        elsif ($j == 0) { $text = "$MIDDLE_LEFT$text$MIDDLE_SEPARATOR" }
        elsif ($j == $columns) { $text = "$text$MIDDLE_RIGHT" }
        else                   { $text = "$text$MIDDLE_SEPARATOR" }
        $output .= $text;
    }

    $output .= "\n";

    return $output;
}

# Wrap text
sub _wrap {
    my ($self, $text, $width) = @_;

    my @cache;
    my @parts = split "\n", $text;

    for my $part (@parts) {

        while (length $part > $width) {
            my $subtext;
            $subtext = substr $part, 0, $width - length($WRAP), '';
            push @cache, "$subtext$WRAP";
        }

        push @cache, $part if defined $part;
    }

    return \@cache;
}

1;
__END__

=head1 NAME

Text::SimpleTable - Simple Eyecandy ASCII Tables

=head1 SYNOPSIS

    use Text::SimpleTable;

    my $t1 = Text::SimpleTable->new(5, 10);
    $t1->row('foobarbaz', 'yadayadayada');
    print $t1->draw;

    .-------+------------.
    | foob- | yadayaday- |
    | arbaz | ada        |
    '-------+------------'

    my $t2 = Text::SimpleTable->new([5, 'Foo'], [10, 'Bar']);
    $t2->row('foobarbaz', 'yadayadayada');
    $t2->row('barbarbarbarbar', 'yada');
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

    my $t3 = Text::SimpleTable->new([5, 'Foo'], [10, 'Bar']);
    $t3->row('foobarbaz', 'yadayadayada');
    $t3->hr;
    $t3->row('barbarbarbarbar', 'yada');
    print $t3->draw;

    .-------+------------.
    | Foo   | Bar        |
    +-------+------------+
    | foob- | yadayaday- |
    | arbaz | ada        |
    +-------+------------+
    | barb- | yada       |
    | arba- |            |
    | rbar- |            |
    | bar   |            |
    '-------+------------'

=head1 DESCRIPTION

Simple eyecandy ASCII tables.

=head1 METHODS

L<Text::SimpleTable> implements the following methods.

=head2 C<new>

    my $t = Text::SimpleTable->new(5, 10);
    my $t = Text::SimpleTable->new([5, 'Col1', 10, 'Col2']);

=head2 C<draw>

    my $ascii = $t->draw;

=head2 C<hr>

    $t = $t->hr;

=head2 C<row>

    $t = $t->row('col1 data', 'col2 data');

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>.

=head1 MAINTAINER

Marcus Ramberg C<mramberg@cpan.org>.

=head1 CREDITS

In alphabetical order:

Brian Cassidy

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2010, Sebastian Riedel.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
