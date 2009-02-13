CREATE TABLE Publications(
  sha1               TEXT UNIQUE,
  pdf                TEXT,
  pdftext            TEXT,
  created            TIMESTAMP,
  last_read          TIMESTAMP,
  times_read         INTEGER
);

CREATE TABLE Fields(
  field             TEXT,
  text              TEXT
);

CREATE TABLE Authors (
  key                 TEXT UNIQUE,
  first               TEXT,
  von                 TEXT,
  last                TEXT,
  jr                  TEXT
);

CREATE TABLE Journals (
  key            TEXT UNIQUE,
  name           TEXT,
  issn           TEXT,
  url            TEXT,
  icon           TEXT
);

CREATE TABLE Tags (
  tag            TEXT UNIQUE
);

CREATE TABLE Tag_Publication (
  tag_id         INTEGER,
  publication_id    INTEGER,
  PRIMARY KEY (tag_id, publication_id)
);

CREATE TABLE Folders (
  folder            TEXT UNIQUE
);

CREATE TABLE Folder_Publication (
  folder_id         INTEGER,
  publication_id    INTEGER,
  PRIMARY KEY (folder_id, publication_id)
);







CREATE TABLE Author_Publication (
  author_id         INTEGER,
  publication_id    INTEGER,
  PRIMARY KEY (author_id, publication_id)
);

