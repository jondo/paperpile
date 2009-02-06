use Data::Dumper;

use Test::More tests => 3;
BEGIN { use_ok('Bibutils') };

is(Bibutils::MODSIN,100,"Testing constants");

is(Bibutils::hello(),1,"Hello world");

my $bu=Bibutils->new(file_in => '/home/wash/test.mods',
                     file_out => '/home/wash/test.bib',
                     format_in => 'BIBL_MODSIN',
                     format_out => 'BIBL_MODSOUT',
                    );

