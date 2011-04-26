
# Copyright 2009-2011 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.

package Paperpile::Job::Win32;

use Win32;
use Win32::Process;

sub run {

  my $id = shift;

  my $paperperl = Paperpile->path_to( 'perl5', 'win32', 'bin', 'paperperl.exe' );
  my $worker = Paperpile->path_to( 'script', 'worker.pl' );

  my $process;
  Win32::Process::Create( $process, $paperperl, "$paperperl $worker " . $id,
    0, Win32::DETACHED_PROCESS, "." )
    || die( Win32::FormatMessage( Win32::GetLastError() ) );

}

1;
