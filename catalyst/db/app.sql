CREATE TABLE Journals (
  short          TEXT UNIQUE,
  long           TEXT,
  issn           TEXT,
  essn           TEXT,
  source         TEXT,
  url            TEXT,
  icon           TEXT,
  reviewed       INTEGER

);


CREATE VIRTUAL TABLE Journals_lookup using fts3(long,short);
