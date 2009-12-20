#!/usr/bin/perl -w

use CPAN;
use Config;

# Small wrapper to ensure the right perl is called

my $platform='';
my $arch_string=$Config{archname};

if ( $arch_string =~ /linux/i ) {
  $platform = ($arch_string =~ /64/) ? 'linux64' : 'linux32';
}

`unset PERL5LIB`;

# add '.' to @INC to allow access to Bundle::Paperpile.pm
system ("../catalyst/perl5/$platform/bin/perl -MCPAN -e 'push \@INC, \".\";shell;'");

