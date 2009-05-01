CREATE TABLE settings(
 key      TEXT, 
 value    TEXT
);

CREATE TABLE Journals (
  short          TEXT UNIQUE,
  long           TEXT,
  issn           TEXT,
  url            TEXT,
  icon           TEXT
);

CREATE VIRTUAL TABLE Journals_lookup using fts3(long,short);
