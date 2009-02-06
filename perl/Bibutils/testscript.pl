#!/usr/bin/perl -w

use strict;
use ExtUtils::testlib;
use Bibutils;

my $bu=Bibutils->new(in_file => '/home/wash/test.mods',
                     out_file => '/home/wash/test.bib',
                     in_format => Bibutils::MODSIN,
                     out_format => Bibutils::MODSOUT,
                    );

#print("----->", $bu->error);

$bu->read;
$bu->write;

