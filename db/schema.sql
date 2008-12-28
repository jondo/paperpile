CREATE TABLE publication(
rowid              INTEGER PRIMARY KEY AUTOINCREMENT,
sha1               TEXT UNIQUE,
pubtype            TEXT,
key                TEXT,
title              TEXT,
title2             TEXT,
title3             TEXT,
authors_flat       TEXT,
editors_flat       TEXT,
authors_series     TEXT,
journal_id         TEXT,
journal_flat       TEXT,
volume             TEXT,
issue              TEXT,
pages              TEXT,
publisher          TEXT,
city               TEXT,
address            TEXT,
date               TEXT,
year               INTEGER,
month              TEXT,
day                INTEGER,
issn               TEXT,
pmid               INTEGER,
doi                TEXT,
url                TEXT,
abstract           TEXT,
notes              TEXT,
tags_flat          TEXT,
pdf                TEXT,
text               TEXT,
created            TIMESTAMP,
last_read          TIMESTAMP
);

CREATE TABLE author (
id                  TEXT PRIMARY KEY,
last_name           TEXT,
initials            TEXT,
first_name          TEXT,
suffix              TEXT
);

CREATE TABLE journal (
id              TEXT PRIMARY KEY,
name            TEXT,
short           TEXT,
issn            TEXT,
url             TEXT,
icon            TEXT,
is_user_journal INTEGER
);

CREATE TABLE author_publication (
author_id         INTEGER,
publication_id    INTEGER,
PRIMARY KEY (author_id, publication_id)
);

CREATE VIRTUAL TABLE fulltext using fts3(title,abstract,notes,authors);
