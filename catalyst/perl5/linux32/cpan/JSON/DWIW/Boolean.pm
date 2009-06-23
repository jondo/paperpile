# Creation date: 2007-05-10 20:29:02
# Authors: don
#
# Copyright (c) 2007 Don Owens <don@regexguy.com>.  All rights reserved.
#
# This is free software; you can redistribute it and/or modify it under
# the Perl Artistic license.  You should have received a copy of the
# Artistic license with this distribution, in the file named
# "Artistic".  You may also obtain a copy from
# http://regexguy.com/license/Artistic
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.

=pod

=head1 NAME

 JSON::DWIW::Boolean - Return a true or false value when
                       evaluated in boolean context -- to be used
                       with JSON::DWIW->encode() to explicitly
                       specify a boolean value.`

=head1 SYNOPSIS

 use JSON::DWIW;
 my $val1 = JSON::DWIW->true;
 my $val2 = JSON::DWIW->false;

     or

 use JSON::DWIW::Boolean;
 my $val1 = JSON::DWIW::Boolean->new(1); # true value
 my $val2 = JSON::DWIW::Boolean->new(0); # false value

=head1 DESCRIPTION

 This module is not intended to be used directly.  It is intended
 to be used as part of JSON::DWIW to specify that a true or false
 value should be output when converting to JSON, since Perl does
 not have explicit values for true and false.

 Overloading is used, so if a JSON::DWIW::Boolean object is
 evaluated in boolean context, it will evaluate to 1 or 0,
 depending on whether the object was initialized to true or false.

=cut

use strict;
use warnings;

use 5.006_00;

package JSON::DWIW::Boolean;

use overload
    bool => sub { my $self = shift; my $val = $$self; return $val ? 1 : 0; },
    '0+' => sub { my $self = shift; my $val = $$self; return $val ? 1 : 0; };
    

our $VERSION = sprintf("%d.%02d",(q$Revision: 1.4 $ =~ /\d+/g));


=pod

=head1 METHODS

=head2 new($val)

 Return an object initialized with $val as its boolean value.

=cut

sub new {
    my $proto = shift;
    my $val = shift;

    my $obj = $val;
    
    my $self = bless \$obj, ref($proto) || $proto;
    
    return $self;
}

=pod

=head2 true()

 Class method that returns a new object initialized to a true value.

=cut

sub true {
    my $proto = shift;
    return $proto->new(1);
}

=pod

=head2 false()

 Class method that returns a new object initialized to a false value.

=cut

sub false {
    my $proto = shift;
    return $proto->new(0);
}

sub as_bool {
    my $self = shift;
    my $val = $$self;

    if ($val) {
        return 1;
    }
    return;
}


=pod

=head1 EXAMPLES


=head1 DEPENDENCIES


=head1 AUTHOR

Don Owens <don@regexguy.com>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 Don Owens <don@regexguy.com>.  All rights reserved.

This is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  See perlartistic.

This program is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
PURPOSE.

=head1 SEE ALSO


=head1 VERSION

 0.01

=cut

1;

# Local Variables: #
# mode: perl #
# tab-width: 4 #
# indent-tabs-mode: nil #
# cperl-indent-level: 4 #
# perl-indent-level: 4 #
# End: #
# vim:set ai si et sta ts=4 sw=4 sts=4:
