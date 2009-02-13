#!/usr/bin/perl -w

chdir '../../db';
unlink 'app.db';
unlink 'user.db';
my @out=`sqlite3 app.db < app.sql`;
print @out;
@out=`sqlite3 user.db < user.sql`;
print @out;
