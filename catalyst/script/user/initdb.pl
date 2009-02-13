#!/usr/bin/perl -w

chdir '../../db';
unlink 'default.db';
my @out=`sqlite3 default.db < schema.sql`;

print @out;
