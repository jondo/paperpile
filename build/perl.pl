#!/usr/bin/perl -w

use Config;

# Small wrapper to ensure the right perl is called

my $platform='';
my $arch_string=$Config{archname};

if ( $arch_string =~ /linux/i ) {
  $platform = ($arch_string =~ /64/) ? 'linux64' : 'linux32';
}

$ENV{PERL5LIB}=undef;

$ENV{BUILD_PLATFORM}=$platform;

exec("../catalyst/perl5/$platform/bin/perl " . join(" ",@ARGV));

