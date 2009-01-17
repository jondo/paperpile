CREATE TABLE publications(
  sha1               TEXT UNIQUE,
  pdf                TEXT,
  pdftext            TEXT,
  created            TIMESTAMP,
  last_read          TIMESTAMP,
  times_read         INTEGER
);

CREATE TABLE fields(
  field             TEXT,
  text              TEXT
);

CREATE TABLE authors (
  key                 TEXT UNIQUE,
  first               TEXT,
  von                 TEXT,
  last                TEXT,
  jr                  TEXT
);

CREATE TABLE journals (
  key            TEXT UNIQUE,
  name           TEXT,
  issn           TEXT,
  url            TEXT,
  icon           TEXT
);

CREATE TABLE author_publication (
  author_id         INTEGER,
  publication_id    INTEGER,
  PRIMARY KEY (author_id, publication_id)
);

-- CREATE VIRTUAL TABLE fulltext using fts3(title,abstract,notes,authors);
