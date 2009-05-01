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