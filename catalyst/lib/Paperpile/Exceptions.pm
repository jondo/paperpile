package Paperpile::Exceptions;

use Exception::Class ( PaperpileError,
  UserCancel => { isa => 'PaperpileError' },
  FileError => {
    isa    => 'PaperpileError',
    fields => 'file'
  },
  FileReadError       => { isa => 'FileError' },
  LibraryMissingError => { isa => 'FileReadError' },
  DatabaseVersionError => { isa => 'FileReadError' },
  FileWriteError      => { isa => 'FileError' },
  FileFormatError     => { isa => 'FileError' },
  NetError            => { isa => 'PaperpileError' },
  NetGetError         => {
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
  ExtractionError  => {
    isa    => 'PaperpileError',
  },



);

return 1;
