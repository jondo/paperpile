
use strict;
use warnings;



use ExtUtils::MakeMaker 6.11;



my %WriteMakefileArgs = (
                       'test' => {
                                   'TESTS' => 't/*.t'
                                 },
                       'NAME' => 'BibTeX::Parser',
                       'DISTNAME' => 'BibTeX-Parser',
                       'AUTHOR' => 'Gerhard Gossen <gerhard.gossen@googlemail.com>',
                       'ABSTRACT' => 'A pure perl BibTeX parser',
                       'EXE_FILES' => [],
                       'VERSION' => '0.4',
                       'LICENSE' => 'perl',
                       'PREREQ_PM' => {
                                        'Test::More' => '0',
                                        'IO::File' => '0',
                                        'IO::String' => '0',
                                        'ExtUtils::MakeMaker' => '6.11',
                                        'File::Spec' => '0'
                                      }
                     );


delete $WriteMakefileArgs{LICENSE}
  unless eval { ExtUtils::MakeMaker->VERSION(6.31) };

WriteMakefile(%WriteMakefileArgs);



