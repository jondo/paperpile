
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

package Paperpile::Exceptions;

use Exception::Class ( PaperpileError,
  UserCancel => { isa => 'PaperpileError' },
  FileError  => {
    isa    => 'PaperpileError',
    fields => 'file'
  },
  FileSyncError => {
    isa    => 'PaperpileError',
    fields => 'file'
  },
  FileSyncConflictError  => { isa => 'FileSyncError' },
  FileReadError          => { isa => 'FileError' },
  PaperRootNotEmptyError => { isa => 'FileError' },
  LibraryMissingError    => { isa => 'FileReadError' },
  DatabaseVersionError   => { isa => 'FileReadError' },
  FileWriteError         => { isa => 'FileError' },
  FileFormatError        => { isa => 'FileError' },
  DuplicateError         => { isa => 'PaperpileError' },
  NetError               => { isa => 'PaperpileError' },
  NetGetError            => {
    isa    => 'NetError',
    fields => 'code',
  },
  NetFormatError => {
    isa    => 'NetError',
    fields => 'content',
  },
  NetMatchError => { isa => 'NetError', },
  CrawlerError  => {
    isa    => 'PaperpileError',
    fields => 'url',
  },
  CrawlerUnknownSiteError => { isa => 'CrawlerError' },
  CrawlerScrapeError      => { isa => 'CrawlerError' },
  ExtractionError         => { isa => 'PaperpileError', },
  ExtpdfError             => { isa => 'PaperpileError', },

);

return 1;
