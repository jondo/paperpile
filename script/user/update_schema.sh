#!/bin/bash
cd /home/wash/play/PaperPile/db
rm default.db
sqlite3 default.db < schema.sql
/home/wash/play/PaperPile/script/paperpile_create.pl model DB DBIC::Schema PaperPile::Schema create=static dbi:SQLite:/home/wash/play/PaperPile/db/default.db
