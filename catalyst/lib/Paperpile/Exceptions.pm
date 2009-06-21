package Paperpile::Exceptions;

use Exception::Class ( PaperpileError,
  FileError => {
    isa    => 'PaperpileError',
    fields => 'file'
  },
  FileReadError       => { isa => 'FileError' },
  LibraryMissingError => { isa => 'FileReadError' },
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
  CrawlerError => {
    isa    => 'PaperpileError',
    fields => 'url',
  },
  CrawlerUnknownSiteError => { isa => 'CrawlerError' },
  CrawlerScrapeError      => { isa => 'CrawlerError' },

);

return 1;
