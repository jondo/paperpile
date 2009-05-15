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

CREATE TABLE Tags (
  tag            TEXT UNIQUE,
  style          TEXT
);

CREATE TABLE Tag_Publication (
  tag_id         INTEGER,
  publication_id    INTEGER,
  PRIMARY KEY (tag_id, publication_id)
);

CREATE TABLE Folders (
  folder_id           TEXT UNIQUE
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

CREATE TABLE Attachments (
  file_name         TEXT,
  publication_id    INTEGER
);
