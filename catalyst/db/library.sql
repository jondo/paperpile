-- Copyright 2009, 2010 Paperpile
--
-- This file is part of Paperpile
--
-- Paperpile is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- Paperpile is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.  You should have received a
-- copy of the GNU General Public License along with Paperpile.  If
-- not, see http://www.gnu.org/licenses.

CREATE TABLE Settings(
 key      TEXT UNIQUE, 
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
