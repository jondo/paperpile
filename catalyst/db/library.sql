CREATE TABLE Settings(
 key      TEXT, 
 value    TEXT
);

CREATE TABLE Publications(
  sha1               TEXT UNIQUE,
  pdf                TEXT,
  pdf_url            TEXT,
  pdftext            TEXT,
  pdf_size           INTEGER,
  trashed            INTEGER,
  created            TIMESTAMP,
  last_read          TIMESTAMP,
  times_read         INTEGER,
  attachments        INTEGER,
  annote             TEXT,
  tags               TEXT,
  folders            TEXT
);

CREATE VIRTUAL TABLE Fulltext_full using fts3(text,abstract,notes,title,key,author,label,labelid,keyword,folder,year,journal);

CREATE VIRTUAL TABLE Fulltext_citation using fts3(abstract,notes,title,key,author,label,labelid,keyword,folder,year,journal);

CREATE TABLE Fields(
  field             TEXT,
  text              TEXT
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

CREATE TABLE Attachments (
  file_name         TEXT,
  publication_id    INTEGER
);
