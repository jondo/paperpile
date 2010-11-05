-- Copyright 2009, 2010 Paperpile
--
-- This file is part of Paperpile
--
-- Paperpile is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.

-- Paperpile is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Affero General Public License for more details.  You should have
-- received a copy of the GNU Affero General Public License along with
-- Paperpile.  If not, see http://www.gnu.org/licenses.

CREATE TABLE Settings(
 key      TEXT UNIQUE, 
 value    TEXT
);

CREATE TABLE Publications(
  guid               TEXT UNIQUE,
  sha1               TEXT UNIQUE,
  pdf                TEXT,
  pdf_name           TEXT,
  attachments        TEXT,
  trashed            INTEGER,
  created            TIMESTAMP,
  last_read          TIMESTAMP,
  times_read         INTEGER,
  annote             TEXT,
  labels               TEXT,
  labels_tmp           TEXT,
  folders            TEXT
  -- additional fields are added dynamically in init_db in Build.pm
);

CREATE VIRTUAL TABLE Fulltext using fts3(guid,text,abstract,notes,title,key,author,year,journal, keyword,folderid,labelid);

CREATE TABLE Collections (
  guid          TEXT UNIQUE,
  name          TEXT,
  type          TEXT,
  parent        TEXT,
  sort_order    INTEGER,
  hidden        INTEGER,
  style         TEXT   
);

CREATE INDEX collections_guid_index ON Collections ('guid');

CREATE TABLE Collection_Publication (
  collection_guid     Text,
  publication_guid    Text,
  PRIMARY KEY (collection_guid, publication_guid)
);

CREATE TABLE Attachments (
  guid         TEXT,
  publication  TEXT,
  is_pdf       INTEGER,
  name         TEXT,
  local_file   TEXT,
  size         INTEGER,
  md5          TEXT
);

CREATE TABLE Changelog (
 counter   INTEGER PRIMARY KEY AUTOINCREMENT,
 guid      TEXT,
 type      TEXT    
);

CREATE TRIGGER insert_log INSERT ON Publications 
BEGIN
  INSERT INTO Changelog (guid,type) VALUES (new.guid,'INSERT');
END;

CREATE TRIGGER delete_log DELETE ON Publications 
BEGIN
  INSERT INTO Changelog (guid,type) VALUES (old.guid,'DELETE');
END;

CREATE TRIGGER update_log UPDATE ON Publications 
BEGIN
  INSERT INTO Changelog (guid,type) VALUES (old.guid,'UPDATE');
END;



