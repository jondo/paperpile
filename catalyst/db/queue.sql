CREATE TABLE Settings(
 key      TEXT, 
 value    TEXT
);

CREATE TABLE queue(
  jobid              TEXT UNIQUE,
  status             TEXT,
  error              INTEGER,
  duration           INTEGER
);