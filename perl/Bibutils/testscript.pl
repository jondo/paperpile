#!/usr/bin/perl -w

use strict;
use ExtUtils::testlib;
use Bibutils;
use Data::Dumper;

my $bu=Bibutils->new(in_file => '/home/wash/test.mods',
                     out_file => '/home/wash/test.bib',
                     in_format => Bibutils::MODSIN,
                     out_format => Bibutils::MODSOUT,
                    );

#print("----->", $bu->error);

$bu->read;
#$bu->write;

my $data=$bu->get_data();
$bu->cleanup;

$bu->set_data($data);

$bu->write;




