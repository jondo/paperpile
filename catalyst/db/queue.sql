CREATE TABLE Settings(
 key      TEXT, 
 value    TEXT
);

CREATE TABLE queue(
  jobid              TEXT UNIQUE,
  sha1               TEXT,
  status             TEXT,
  type               TEXT,
  error              INTEGER,
  duration           INTEGER
);