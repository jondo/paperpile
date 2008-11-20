CREATE TABLE publication(
id                 TEXT PRIMARY KEY,
pubtype            TEXT,
title              TEXT,
title2             TEXT,
title3             TEXT,
authors_flat       TEXT,
editors_flat       TEXT,
authors_series     TEXT,
journal_short      TEXT,
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
fulltext           TEXT
);

CREATE TABLE author (
id                  TEXT PRIMARY KEY,
last_name           TEXT,
initials            TEXT,
first_name          TEXT,
suffix              TEXT
);

CREATE TABLE journal (
id           TEXT PRIMARY KEY,
name         TEXT,
short        TEXT,
issn         TEXT,
url          TEXT,
icon         TEXT
);

CREATE TABLE author_publication (
author_id         INTEGER,
publication_id    INTEGER,
PRIMARY KEY (author_id, publication_id)
);

