#!/usr/bin/perl -w

# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.


use CPAN;
use Config;

# Small wrapper to ensure the right perl is called

my $platform='';
my $arch_string=$Config{archname};

if ( $arch_string =~ /linux/i ) {
  $platform = ($arch_string =~ /64/) ? 'linux64' : 'linux32';
}

if ($arch_string =~ /darwin/){
  $platform = 'osx';
}

`unset PERL5LIB`;
# add '.' to @INC to allow access to Bundle::Paperpile.pm
system ("../catalyst/perl5/$platform/bin/paperperl -MCPAN -e 'push \@INC, \".\";shell;'");

