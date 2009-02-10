use Data::Dumper;

use Test::More qw/no_plan/;

BEGIN { use_ok('Bibutils') };

is(Bibutils::MODSIN,100,"Testing constants");

# Test file 'test.bib' contains 30 entries in bibtex format

my $bu=Bibutils->new(in_file => 't/test.bib',
                     out_file => 't/new.bib',
                     in_format => Bibutils::BIBTEXIN,
                     out_format => Bibutils::BIBTEXOUT,
                    );

## Reading file
ok ($bu->read,'Reading file');

## Getting data
my $data=$bu->get_data;
is (scalar @$data, 30, 'Getting data from file.');

my @content=split(/\n/,$bu->as_string);

is ($content[0],'@Article{article-minimal,','Stringify data');

## Error codes
$bu->in_file('DOES NOT EXIST');
$bu->read;
is ($bu->error, Bibutils::ERR_CANTOPEN, 'Getting error codes.');

## Writing data to file
$bu->in_file('t/test.bib');
$bu->read;
$bu->write;
ok (-e 't/new.bib', 'Writing data to file.');

$new_bu=Bibutils->new(out_file => 't/new.bib',
                      out_format => Bibutils::BIBTEXOUT,
                     );

## Setting data manually
$new_bu->set_data($data);
$new_data=$new_bu->get_data;
is_deeply($new_data,$data,"Setting data.");

unlink('t/new.bib');


#print STDERR Dumper($data);
#print("----->", $bu->error);
#$bu->write;






