package MooseX::Role::WithOverloading::Meta::Role::Application::FixOverloadedRefs;
our $VERSION = '0.05';

use Moose::Role;
use namespace::autoclean;

if ($] < 5.008009) {
    after apply => sub {
        reset_amagic($_[2]);
    };
}


1;

__END__

=pod

=head1 NAME

MooseX::Role::WithOverloading::Meta::Role::Application::FixOverloadedRefs

=head1 VERSION

version 0.05

=begin Pod::Coverage

reset_amagic

=end Pod::Coverage



=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut 


