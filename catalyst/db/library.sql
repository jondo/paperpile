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
  guid               TEXT UNIQUE,
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

CREATE VIRTUAL TABLE Fulltext using fts3(text,abstract,notes,title,key,author,year,journal, keyword,folderid,labelid);

CREATE TABLE Collections (
  guid          TEXT UNIQUE,
  name          TEXT,
  type          TEXT,
  parent        TEXT,
  sort_order    INTEGER,
  style         TEXT   
);

CREATE TABLE Collection_Publication (
  collection_guid     Text,
  publication_guid    Text,
  PRIMARY KEY (collection_guid, publication_guid)
);

CREATE TABLE Attachments (
  file_name         TEXT,
  publication_id    INTEGER
);
