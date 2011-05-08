# Copyright 2009-2011 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.

package Paperpile::PdfExtract;

use Mouse;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Data::Dumper;
use Paperpile::Formats::XMP;

use Paperpile::PdfExtract::LandesBioScience;
use Paperpile::PdfExtract::ScienceMag;
use Paperpile::PdfExtract::NPG;
use Paperpile::PdfExtract::JSTOR;
use Paperpile::PdfExtract::Biopolymers;

has 'file'            => ( is => 'rw', isa => 'Str' );
has 'pub'             => ( is => 'rw', isa => 'Paperpile::Library::Publication' );
has '_COMMONWORDS'    => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );
has '_BADTYPES'       => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );
has '_ADDRESS'        => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );
has '_BADWORDS'       => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );
has '_NUMBERS'        => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );
has '_BADAUTHORWORDS' => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );

sub BUILD {
  my $self = shift;

  my @tmp = (
    "ABOUT",    "AFTER",     "AGAIN",   "ALL",      "ALONG",     "ALSO",
    "ANOTHER",  "ANY",       "ARE",     "AROUND",   "AWAY",      "BACK",
    "BECAUSE",  "BEEN",      "BEFORE",  "BELOW",    "BETWEEN",   "BOTH",
    "BUT",      "CAME",      "CAN",     "COME",     "COULD",     "DAY",
    "DID",      "DIFFERENT", "DO",      "DOES",     "DOWN",      "EACH",
    "END",      "EVEN",      "EVERY",   "FEW",      "FIND",      "FIRST",
    "FOR",      "FOUND",     "FROM",    "GET",      "GIVE",      "GO",
    "GOOD",     "GREAT",     "HAD",     "HAS",      "HAVE",      "HELP",
    "HER",      "HERE",      "HIM",     "HIS",      "HOME",      "HOW",
    "INTO",     "ITS",       "JUST",    "KNOW",     "LARGE",     "LAST",
    "LEFT",     "LIKE",      "LINE",    "LITTLE",   "LOOK",      "MADE",
    "MAKE",     "MAN",       "MANY",    "MAY",      "MEN",       "MIGHT",
    "MORE",     "MOST",      "MUST",    "NAME",     "NEVER",     "NEW",
    "NEXT",     "NOT",       "NOW",     "NUMBER",   "OFF",       "OLD",
    "ONE",      "ONLY",      "OTHER",   "OUR",      "OUT",       "OVER",
    "OWN",      "PART",      "PEOPLE",  "PLACE",    "PUT",       "READ",
    "RIGHT",    "SAID",      "SAME",    "SAW",      "SAY",       "SEE",
    "SHOULD",   "SHOW",      "SMALL",   "SOME",     "SOMETHING", "SOUND",
    "STILL",    "SUCH",      "TAKE",    "TELL",     "THAN",      "THAT",
    "THEM",     "THEN",      "THERE",   "THESE",    "THEY",      "THING",
    "THINK",    "THIS",      "THOSE",   "THOUGHT",  "THREE",     "THROUGH",
    "TIME",     "TOGETHER",  "TOO",     "TWO",      "UNDER",     "USE",
    "VERY",     "WANT",      "WATER",   "WAY",      "WELL",      "WENT",
    "WERE",     "WHAT",      "WHEN",    "WHERE",    "WHICH",     "WHILE",
    "WHO",      "WHY",       "WILL",    "WITH",     "WORD",      "WORK",
    "WORLD",    "WOULD",     "WRITE",   "YEAR",     "WAS",       "ABLE",
    "ABOVE",    "ACROSS",    "ADD",     "AGAINST",  "AGO",       "ALMOST",
    "AMONG",    "ANIMAL",    "ANSWER",  "BECAME",   "BECOME",    "BEGAN",
    "BEHIND",   "BEING",     "BETTER",  "BLACK",    "BEST",      "CALL",
    "CANNOT",   "CERTAIN",   "CHANGE",  "CHILDREN", "CLOSE",     "COLD",
    "COURSE",   "CUT",       "DONE",    "DRAW",     "DURING",    "EARLY",
    "EARTH",    "EAT",       "ENOUGH",  "EVER",     "EXAMPLE",   "FAR",
    "FIVE",     "FOOD",      "FORM",    "FOUR",     "FRONT",     "GAVE",
    "GIVEN",    "GOT",       "GROUND",  "GROUP",    "GROW",      "HALF",
    "HARD",     "HEARD",     "HIGH",    "HOWEVER",  "IDEA",      "IMPORTANT",
    "INSIDE",   "KEEP",      "KIND",    "KNEW",     "KNOWN",     "LATER",
    "LEARN",    "LET",       "LETTER",  "LIFE",     "LIGHT",     "LIVE",
    "LIVING",   "MAKING",    "MEAN",    "MEANS",    "MONEY",     "MOVE",
    "NEAR",     "NOTHING",   "ONCE",    "OPEN",     "ORDER",     "PAGE",
    "PAPER",    "PARTS",     "PERHAPS", "PICTURE",  "POINT",     "READY",
    "RED",      "REMEMBER",  "REST",    "RUN",      "SECOND",    "SEEN",
    "SENTENCE", "SEVERAL",   "SHORT",   "SHOWN",    "SINCE",     "SIX",
    "SLIDE",    "SOMETIME",  "SOON",    "SPACE",    "SURE",      "TABLE",
    "THOUGH",   "TODAY",     "TOLD",    "TOOK",     "TOP",       "TOWARD",
    "TRY",      "TURN",      "UNTIL",   "UPON",     "USING",     "USUALLY",
    "WHOLE",    "WITHOUT",   "YET",     "YOUNG",    "DNA",       "RNA",
    "SEQUENCE", "STRUCTURE", "PROTEIN", "NUCLEIC",  "HUMAN",     "GENOME",
    "MEASURE",  "ASSAY",     "MANY"
  );

  my @tmp2 = (
    'articles?$',                      'paper$',
    'review$',                         '^ResearchPaper',
    '^REVIEWS$',                       '^ResearchNote$',
    '^(research)?report$',             '^(Short)?Communication$',
    '^originalresearch$',              'originalarticle',
    '^Letters$',                       '^.?ExtendedAbstract.?$',
    '^(short)?(scientific)?reports?$', '^ORIGINALINVESTIGATION$',
    'discoverynotes',                  '^SURVEYANDSUMMARY$',
    'APPLICATIONSNOTE',                'Chapter\d+',
    '^CORRESPONDENCE$',                '^SPECIALTOPIC',
    'Briefreport',                     'DISCOVERYNOTE$',
    'letters?to',                      'BRIEFCOMMUNICATIONS',
    '^Commentary$',                    'MeetingReview',
    'TechnicalReport',                 'ARTICLEINPRESS',
    '^ResearchLetter$',                '^Perspectivesin',
    '^MicroCommentary$',               '^Casestudy',
    '^SPECIALFEATURE$',                '^RESEARCHARTICLES$',
    '^ClinicalNote$'

  );

  my @tmp3 = (
    'Universi[t|d]',           'College',
    'school\s(?:of|in)',       'D[aeiou]part[aeiou]?ment',
    'Dept\.',                  'Institut',
    'Lehrstuhl',               'Chair\sfor',
    'Faculty',                 'Facultad',
    'Center',                  'Centre',
    'Laboratory',              'Laboratoire\sde',
    'Laboratories',            'division\sof',
    'Science\sDivision',       'Research\sOrganisation',
    '(?![a-z])section\sof',    '(?![a-z])section\son',
    'address',                 'P\.?\s?O\.?\s?Box',
    'General\sHospital',       'Hospital\sof',
    'Polytechnique',           'Molecular\sStructure\sSection',
    'Ltd\.',                   'U\.S\.A\.',
    'Howard\sHughes\sMedical', 'The\s\S+\sBuilding',
    'Ecole',                   'Direction\sScientifique',
    'USA$',                    'Michigan',
    'Servicio',                '\d+,\sAve\.',
    'Escola'
  );

  my @tmp4 = (
    'doi',           'vol\.\d+',               'keywords',        'openaccess$',
    'ScienceDirect', 'Blackwell',              'journalhomepage', 'e-?mail',
    'journal',       'ISSN',                   'http:\/\/',       '\.html',
    'Copyright',     'BioMedCentral',          'BMC',             'corresponding',
    'author',        'Abbreviations',          '@',               'Hindawi',
    'Pages\d+',      '\.{5,}',                 'NucleicAcidsResearch',
    'Printedin',     'Receivedforpublication', 'Received:',       'Accepted:',
    'Tel:', 'Fax:', 'VOLUME\d+', 'Studentof', 'Wiley-?VCH', 'Revisedversion'

  );

  my @tmp5 = (
    '\d{4,}',
    '\d\d\/\d\d\/\d\d',
    '\d\d+-\d\d+',
    '\[\d+-\d+\]',
    '\[\d+\]',
    '^\d+$',
    '(January|February|March|April|May|June|July|August|September|October|November|December)\s*\d+\s*,\s*\d{4}',
    '(January|February|March|April|May|June|July|August|September|October|November|December)\s*\d{4}',
    '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s*\d+\s*,\s*\d{4}'
  );

  my @tmp6 = (
    'this',     'that',     'here',     'where',    'study',     'about',
    'what',     'which',    'from',     'are',      'some',      'few',
    'there',    'above',    'below',    'under',    'Fig\.\s\d', 'false',
    'value',    'negative', 'positive', 'Sequence', 'Structure', 'Space',
    'Topology', 'History',  'Publications'
  );

  my $COMMONWORDS = {};
  foreach my $e (@tmp) {
    $COMMONWORDS->{$e} = 1;
  }

  $self->_COMMONWORDS($COMMONWORDS);
  $self->_BADTYPES( \@tmp2 );
  $self->_ADDRESS( \@tmp3 );
  $self->_BADWORDS( \@tmp4 );
  $self->_NUMBERS( \@tmp5 );
  $self->_BADAUTHORWORDS( \@tmp6 );
}

sub parsePDF {

  my $self = shift;

  my $verbose = 0;

  my ( $title, $authors, $doi, $arxivid );

  # Read XMP data if present in PDF file
  my $xmp_parser = Paperpile::Formats::XMP->new();
  $xmp_parser->file( $self->file );
  my $xmp_pub = $xmp_parser->read();

  # immediate return if we get a more or less complete entry
  if ( $xmp_pub->title and $xmp_pub->authors and $xmp_pub->doi ) {
    return $xmp_pub;
  }

  # call extpdf
  my $arguments = {
    'command' => 'WORDLIST',
    'page'    => 0,
    'inFile'  => $self->file
  };
  my $output = Paperpile::Utils->extpdf($arguments);

  #print  Dumper($output),"\n";

  # extpdf output is grouped into lines and features
  # are calculated for each line
  my $metadata = $self->parse_extpdf_info( $output, $arguments );
  my ( $lines, $words_rotated ) = $self->parse_extpdf_output($output);

  # usually extpdf gives the lines in the order one would read it,
  # but there are some weird cases where it is totally wrong
  # sort lines here
  $lines = _sort_lines( $lines, $metadata );

  # search for a DOI
  $doi = _search_for_DOI($lines);

  # search for an ArXiv ID
  $arxivid = _search_for_arXivid( $lines, $words_rotated );

  # check if it seems that this page is a cover page
  my $has_cover_page = _check_for_cover_page($lines);
  if ( $has_cover_page == 1 and $metadata->{numPages} > 1 ) {
    $arguments->{'page'} = 1;
    $output = Paperpile::Utils->extpdf($arguments);
    $metadata = $self->parse_extpdf_info( $output, $arguments );
    ( $lines, $words_rotated ) = $self->parse_extpdf_output($output);
    $lines = _sort_lines( $lines, $metadata );
    $doi = _search_for_DOI($lines) if ( !defined $doi );
    $arxivid = _search_for_arXivid( $lines, $words_rotated ) if ( !defined $arxivid );
  }

  if ( $verbose == 1 ) {
    print STDERR "******************* LINES *********************\n";
    foreach my $i ( 0 .. $#{$lines} ) {
      print STDERR "L$i: ", _sprintf_line_or_group( $lines->[$i] );
    }
  }

  # call text parser
  ( $title, $authors, my $driver ) = _parse_text( $lines, $words_rotated, $verbose );

  # there can be more than one artilce on the page, in those cases
  # we do not know if we got hte correct DOI
  $doi = undef if ( $driver eq 'ScienceMag' and $has_cover_page == 0 );

  # if text parsing did not return values, we take
  # the metadata values if there are any
  $title   = $metadata->{title} if ( !$title   and $metadata->{title} );
  $doi     = $metadata->{doi}   if ( !$doi     and $metadata->{doi} );
  $arxivid = $metadata->{arxiv} if ( !$arxivid and $metadata->{arxivid} );

  $title   = $xmp_pub->title   if ( !$title   and $xmp_pub->title );
  $authors = $xmp_pub->authors if ( !$authors and $xmp_pub->authors );
  $doi     = $xmp_pub->doi     if ( !$doi     and $xmp_pub->doi );
  $arxivid = $xmp_pub->arxiv   if ( !$arxivid and $xmp_pub->arxivid );

  # We can now create the publication object and return it
  my $pub = Paperpile::Library::Publication->new( pubtype => 'MISC' );
  $pub->title($title)     if $title;
  $pub->authors($authors) if $authors;
  $pub->arxivid($arxivid) if $arxivid;
  $pub->doi($doi)         if $doi;

  return $pub;
}

sub _sort_lines {
  my $lines    = $_[0];
  my $metadata = $_[1];

  my ( $onecolumn, $twocolumns ) = ( 1, 0 );
  my ( $width, $height ) = split( /\s+/, $metadata->{size} );

  # count all xMin values to see if we have a two column or
  # one column layout
  my %hash = ();
  $hash{ $_->{xMin} }++ foreach @{$lines};
  foreach my $key ( sort { $a <=> $b } keys %hash ) {
    if ( $key > $width / 2 - 10 and $hash{$key} / $#{$lines} > 0.1 ) {
      $twocolumns = 1;
      $onecolumn  = 0;
    }
  }

  if ( $onecolumn == 1 ) {
    my @tmp = sort { $a->{yMin} <=> $b->{yMin} } @{$lines};
    $lines = \@tmp;
  }
  if ( $twocolumns == 1 ) {

    # for a two column layout, we split the lines into two
    # arrays accoring to the column and sort each column
    # individually
    my @col1 = ();
    my @col2 = ();
    foreach my $line ( @{$lines} ) {
      if ( $line->{xMin} <= $width / 2 - 10 ) {
        push @col1, $line;
      } else {
        push @col2, $line;
      }
    }

    @col1 = sort { $a->{yMin} <=> $b->{yMin} } @col1;
    @col2 = sort { $a->{yMin} <=> $b->{yMin} } @col2;
    $lines = [];
    push @{$lines}, $_ foreach @col1;
    push @{$lines}, $_ foreach @col2;
  }

  return $lines;
}

sub _parse_text {
  my $lines         = $_[0];
  my $words_rotated = $_[1];
  my $verbose       = $_[2];
  my $driver        = 'plain';

  my ( $title, $authors );

  my $most_abundant_fs = _most_abundant_fontsize($lines);

  # specific parsers that operate on lines
  ( $title, $authors ) = Paperpile::PdfExtract::JSTOR->parse($lines);

  if ( !defined $title ) {
    ( $title, $authors ) = Paperpile::PdfExtract::Biopolymers->parse($lines);
    $driver = 'Biopolymers' if ( defined $title );
  }

  if ( !defined $title ) {
    ( $title, $authors ) = Paperpile::PdfExtract::LandesBioScience->parse($lines);
    $driver = 'LandesBioScience' if ( defined $title );
  }

  if ( !defined $title ) {
    ( $title, $authors ) = Paperpile::PdfExtract::ScienceMag->parse($lines);
    $driver = 'ScienceMag' if ( defined $title );
  }

  if ( !defined $title ) {
    ( $title, $authors ) = Paperpile::PdfExtract::NPG->parse( $lines, $words_rotated );
    $driver = 'NPG' if ( defined $title );
  }

  # group lines
  if ( not defined $title or not defined $authors ) {
    my $groups = _build_groups( $lines, $most_abundant_fs, $verbose );

    if ( $verbose == 1 ) {
      print STDERR "******************* GROUPS *********************\n";
      foreach my $i ( 0 .. $#{$groups} ) {
        print STDERR "G$i: ", _sprintf_line_or_group( $groups->[$i] );
      }
    }

    # specific parsers that operate on grouped lines
    if ( not defined $title or not defined $authors ) {
      ( $title, $authors ) = _strategy_one( $groups, $most_abundant_fs, $verbose );
    }
    if ( not defined $title or not defined $authors ) {
      ( $title, $authors ) = _strategy_two( $groups, $most_abundant_fs, $verbose );
    }
  }

  if ( defined $title and defined $authors ) {
    $title =~ s/,\s*$//;
    $title =~ s/\.$//;
    $title =~ s/^\s*,\s*//;
    $title =~ s/^(Research\sarticles?)//i;
    $title =~ s/^(Short\sarticle)//i;
    $title =~ s/^(Report)//i;
    $title =~ s/^Articles?//i;
    $title =~ s/^(Review\s)//i;
    $title =~ s/^([A-Z]*\sMinireview)//i;
    $title =~ s/^Micro\s?Review//i;
    $title =~ s/^RAPID\s?COMMUNICATION//i;
    $title =~ s/^SURVEY\sAND\sSUMMARY\s//i;
    $title =~ s/^(Letter:?)//i;
    $title =~ s/^Commentary//i;
    $title =~ s/^\s*//;
    $title =~ s/\x{605}/ /g;
    $title =~ s/\x{35E}/ /g;
    $title =~ s/\s+/ /g;

    #$title =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg;

    $authors = _clean_and_format_authors($authors);
  }

  return ( $title, $authors, $driver );
}

sub _clean_and_format_authors {
  my $string = $_[0];

  $string =~ s/^Commentary//i;
  $string =~ s/\?/ , /g;
  $string =~ s/~/ /g;
  $string =~ s/\{//g;
  $string =~ s/\+//g;
  $string =~ s/;/ , /g;
  $string =~ s/,+/ , /g;
  $string =~ s/,\s*$//;
  $string =~ s/\x{2C7}//g;          # Unicode Character 'CARON'
  $string =~ s/\x{A8}//g;
  $string =~ s/\x{2D8}//g;          # Unicode Character 'BREVE'
  $string =~ s/\d//g;
  $string =~ s/\$//g;
  $string =~ s/'//g;
  $string =~ s/^\s*,//;
  $string =~ s/\s+/ /g;
  $string =~ s/, Ph\.?\s?D\.?//g;
  $string =~ s/,\sM\.?D\.?//g;
  $string =~ s/\./. /g;
  $string =~ s/\sand,/ and /g;
  $string =~ s/,\sand\s/ and /g;
  $string =~ s/` //g;
  $string =~ s/\s?\x{B4}//g;
  $string =~ s/^(by\s)//gi;
  $string =~ s/\s+/ /g;
  $string =~ s/(.*)(\{.*)/$1/;
  while ( $string =~ m/(.*)(,\sJr\.?)(.*)/i ) {
    $string = "$1 Jr. $3";
  }
  while ( $string =~ m/\G(.*[A-Z][a-z]+)([A-Z].*)/g ) {
    my $part1 = $1;
    my $part2 = $2;
    if ( $part1 !~ m/Ma?c$/ ) {
      $string = "$part1 $part2";
    }
  }

  my @tmp = ();
  my @splitted = split( /(?:\sand\s|\s&\s|,|:)/i, $string );

  # some preprocessing
  foreach my $idx ( 0 .. $#splitted ) {
    $splitted[$idx] =~ s/(\s[^[:ascii:]]\s)//g;
    $splitted[$idx] =~ s/\s+$//;
    $splitted[$idx] =~ s/^\s+//;
    $splitted[$idx] =~ s/-\s+/-/g;
  }

  my $times_reversed = 0;
  my $all            = 0;
  foreach my $idx ( 0 .. $#splitted ) {
    my $i = $splitted[$idx];
    next if ( length($i) < 3 );
    $all++;
    if ( $i !~ m/[a-z]/ ) {
      if ( $i =~ m/^(\S+)\s([A-Z]{1,2})$/ ) {
        if ( $i !~ m/(XU|LI|LU)/ ) {
          $times_reversed++;
        }
      }
    } else {
      if ( $i =~ m/^(\S+)\s([^a-z]\.?)$/ ) {
        $times_reversed++;
      }
      if ( $i =~ m/^(\S+)\s([^a-z]\.?\s?[^a-z]\.?)$/ ) {
        $times_reversed++;
      }
    }
  }
  $times_reversed = ( $all > 0 ) ? $times_reversed / $all : 0;

  foreach my $idx ( 0 .. $#splitted ) {
    my $i = $splitted[$idx];
    next if ( length($i) < 3 );

    if ( $times_reversed > 0.9 ) {
      if ( $i !~ m/[a-z]/ ) {
        if ( $i =~ m/^(\S+)\s([A-Z]{1,2})$/ ) {
          $i = "$2 $1";
        }
      } else {
        if ( $i =~ m/^(\S+)\s([^a-z]\.?)$/ ) {
          $i = "$2 $1";
        }
        if ( $i =~ m/^(\S+)\s([^a-z]\.?\s?[^a-z]\.?)$/ ) {
          $i = "$2 $1";
        }
      }
    }

    #print "\t|$i| --> ";
    # if we just have one word
    if ( $i =~ m/^\S+$/ ) {

      # let's see if the author was not split correctly
      # and join entires if necessary
      if ( defined $splitted[ $idx + 1 ] ) {

        # if the next one seems to be just a single word
        if ( $splitted[ $idx + 1 ] =~ m/^\S+$/ ) {

          $splitted[ $idx + 1 ] = $splitted[$idx] . ' ' . $splitted[ $idx + 1 ];
          next;
        }

        # if the next one is an initial followed by a singel word
        if ( $splitted[ $idx + 1 ] =~ m/^[A-Z]\.?\s\S+$/ ) {

          $splitted[ $idx + 1 ] = $splitted[$idx] . ' ' . $splitted[ $idx + 1 ];
          next;
        }
      }
    }

    #$i =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg;
    next if ( $i =~ m/^\./ );

    #print "\t|$i|\n";

    push @tmp, Paperpile::Library::Author->new()->parse_freestyle($i)->bibtex();
  }

  return join( ' and ', @tmp );
}

sub _clean_candidates {
  my $cand_ti = $_[0];
  my $cand_au = $_[1];

  $cand_ti->{'content'} =~ s/#PPRJOIN#//g;
  while ( $cand_au->{'content'} =~ m/(.*)(#PPRJOIN#)(.*)/ ) {

    my $part1 = $1;
    my $part2 = $3;

    # if part2 seems to start with two words
    # we set a comma instead of the JOIN MARK
    if ( $part1 =~ m/-\s*$/ ) {
      $part1 =~ s/\s*$//;
      $part2 =~ s/^\s*//;
      $cand_au->{'content'} = "$part1$part2";
    } elsif ( $part2 =~ m/^[^,\s]{2,}\s[^,]+/ ) {
      $cand_au->{'content'} = "$part1,$part2";
    } else {
      $cand_au->{'content'} = "$part1$part2";
    }
  }

  my $uc_au    = ( $cand_au->{content} =~ tr/[A-Z]// );
  my $uc_ti    = ( $cand_ti->{content} =~ tr/[A-Z]// );
  my $chars_au = ( $cand_au->{content} =~ tr/[A-Za-z]// );
  my $chars_ti = ( $cand_ti->{content} =~ tr/[A-Za-z]// );
  $cand_au->{'uc'} = ( $chars_au > 0 ) ? $uc_au / $chars_au : 0;
  $cand_ti->{'uc'} = ( $chars_ti > 0 ) ? $uc_ti / $chars_ti : 0;

  if ( $cand_au->{'uc'} > 0.9 ) {
    $cand_au->{'content'} =~ s/^B\s?Y\s//;
  }
}

# First, we search for an address line. Usually authors are
# just above that line, and then comes the title
# This is the most promising strategy and gives confident
# results
sub _strategy_one {
  my $groups           = $_[0];
  my $most_abundant_fs = $_[1];
  my $verbose          = $_[2];

  my ( $title, $authors );

  # collect the index of all address lines
  my @address_lines = ();
  my $fs_address    = 0;
  foreach my $i ( 0 .. $#{$groups} ) {
    my $t = $groups->[$i]->{address_count};
    $t += $groups->[$i]->{starts_with_superscript};
    if ( $t > 0 ) {
      push @address_lines, $i;
      $fs_address = $groups->[$i]->{fs};
    }
  }

  # for each address line we now search for lines that
  # do not have bad words and see if the have characteristics
  # of a title/author pair
  foreach my $j (@address_lines) {

    # find the previous lines that do not have bad words
    my @n      = ();
    my $max_fs = 0;
    for ( my $i = $j - 1 ; $i >= 0 ; $i-- ) {
      next if ( length( $groups->[$i]->{content} ) < 2 );

      # do not consider lines that consist of only one
      # word and have a length below 11
      next if ( $groups->[$i]->{content} !~ m/\s/
        and length( $groups->[$i]->{content} ) < 11 );

      # skip really long lines
      next if ( $groups->[$i]->{nr_words} >= 100
        and $groups->[$i]->{nr_bad_author_words} > 1 );
      my $cur = $groups->[$i];
      my $tmp = $cur->{address_count};
      $tmp += $cur->{nr_bad_words};

      # reduce bad count if we see something like a year
      $tmp-- if ( $cur->{content} =~ m/(1[1-9]|20|21)\d\d/ );
      if ( $tmp == 0 ) {
        $max_fs = $cur->{fs} if ( $cur->{fs} > $max_fs );

        # let's see if there is already an entry in @n
        # that has the same yMin coordinates
        # if so, we rather append then adding a new entry
        my $h = -1;
        foreach my $k ( 0 .. $#n ) {
          $h = $k if ( $n[$k]->{yMin} == $groups->[$i]->{yMin} );
        }
        if ( $h == -1 ) {
          push @n, _deep_copy($cur);
        } else {
          my $t = $cur->{content} . ' , ' . $n[$h]->{content};
          $n[$h]->{content} = $t;
        }
      }
    }

    # if we did not find at leats two lines, me move to the
    # next address lione
    next if ( $#n <= 0 );

    if ( $verbose == 1 ) {
      foreach my $i ( 0 .. $#n ) {
        print STDERR "S1|$i: ", _sprintf_line_or_group( $n[$i] );
      }
    }

    my ( $cand_au, $cand_ti ) = ( undef, undef );

    if ( $#n == 1 ) {

      # if just two lines are left, we choose authors and title based
      # on the font size
      ( $cand_ti, $cand_au ) = ( $n[0]->{fs} > $n[1]->{fs} ) ? ( $n[0], $n[1] ) : ( $n[1], $n[0] );
      ( $cand_ti, $cand_au ) = ( undef, undef )
        if ( $cand_au->{nr_bad_author_words} > 0 );

    } elsif ( $#n < 5 ) {

      # let's see if we remove lines with the same fontsize that
      # was observed for address lines, only two lines are left then
      my @c = ();
      foreach my $i ( 0 .. $#n ) {
        push @c, $i if ( $n[$i]->{fs} != $fs_address
          and $n[$i]->{fs} >= $most_abundant_fs );
      }
      if ( $#c == 1 ) {
        ( $cand_ti, $cand_au ) =
            ( $n[ $c[0] ]->{fs} > $n[ $c[1] ]->{fs} )
          ? ( $n[ $c[0] ], $n[ $c[1] ] )
          : ( $n[ $c[1] ], $n[ $c[0] ] );
        if ( $cand_au->{nr_bad_author_words} > 0 ) {
          ( $cand_au, $cand_ti ) = ( undef, undef );
        }
      }
      print STDERR "Au/Ti selection 1 failed.\n" if ( !$cand_ti and $verbose );

      # let's see if we remove lines with a smaller fontsize than
      # the most abundant fs, only two lines are left
      if ( not defined $cand_ti ) {
        @c = ();
        foreach my $i ( 0 .. $#n ) {
          push @c, $i if ( $n[$i]->{fs} < $most_abundant_fs );
        }
        if ( $#c == 1 ) {
          ( $cand_ti, $cand_au ) =
              ( $n[ $c[0] ]->{fs} > $n[ $c[1] ]->{fs} )
            ? ( $n[ $c[0] ], $n[ $c[1] ] )
            : ( $n[ $c[1] ], $n[ $c[0] ] );
          if ( $cand_au->{nr_bad_author_words} > 0 ) {
            ( $cand_au, $cand_ti ) = ( undef, undef );
          }
        }
        print STDERR "Au/Ti selection 2 failed.\n" if ( !$cand_ti and $verbose );
      }

      if ( not defined $cand_ti ) {
        @c = ();

        # first search for the largets fs, and see if this makes sense
        foreach my $i ( 0 .. $#n ) {
          push @c, $i if ( $n[$i]->{fs} == $max_fs );
        }
        if ( $#c == 0 ) {
          if ( $c[0] - 1 >= 0 and $n[ $c[0] - 1 ]->{nr_bad_author_words} == 0 ) {
            $cand_ti = $n[ $c[0] ];
            $cand_au = $n[ $c[0] - 1 ];
          }
        }

        # compare it to a second strategy
        # let's see if we have some indication that the first
        # line is the authors line
        if ( $n[0]->{nr_bad_author_words} == 0 ) {
          my $score = $n[0]->{nr_superscripts};
          foreach my $word ( split( /\s+/, $n[0]->{content} ) ) {
            $score++ if ( $word =~ m/,/ );
            $score++ if ( $word =~ m/^and$/i );
            $score++ if ( $word =~ m/&/ );
          }
          my $score_cur_au = 0;
          if ( $cand_au->{content} ) {
            $score_cur_au += $cand_au->{nr_superscripts};
            foreach my $word ( split( /\s+/, $cand_au->{content} ) ) {
              $score++ if ( $word =~ m/,/ );
              $score++ if ( $word =~ m/^and$/i );
              $score++ if ( $word =~ m/&/ );
            }
          }
          if ( $score > $score_cur_au ) {
            if (  $n[0]->{fs} < $n[1]->{fs}
              and $n[1]->{nr_superscripts} == 0 ) {
              $cand_ti = $n[1];
              $cand_au = $n[0];
            }
          }
        }
      }
      print STDERR "Au/Ti selection 3 failed.\n" if ( !$cand_ti and $verbose );
    }

    return ( undef, undef ) if ( not defined $cand_au or not defined $cand_ti );

    return ( undef, undef ) if ( $cand_au->{nr_common_words} > 1 );

    _clean_candidates( $cand_ti, $cand_au );

    if ( $verbose == 1 ) {
      print STDERR "S1|cand_ti:$cand_ti->{content}\nS1|cand_au:$cand_au->{content}\n";
    }

    # font size of title is larger than that of the authors
    # and 1.2 times larger than the most abundant font size
    if (  $cand_ti->{fs} > $cand_au->{fs}
      and $cand_ti->{fs} / $most_abundant_fs >= 1.2 ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag > 0 );
    }

    # authors and title have the same font size, but at least
    # both are larger than the most abundant font size
    if (  $cand_ti->{fs} == $cand_au->{fs}
      and $cand_ti->{fs} > $most_abundant_fs ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag == 1 );

      # the title is bold, while authors are not
      if ( $cand_ti->{bold} == 1 and $cand_au->{bold} == 0 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }
    }
    if (  $cand_ti->{fs} == $cand_au->{fs}
      and $cand_au->{nr_bad_author_words} == 0 ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag > 0 );
    }
  }

  return ( $title, $authors );

}

# Now we have a look at those lines that do not have "bad
# words" and see if there are some characteristics
sub _strategy_two {
  my $groups           = $_[0];
  my $most_abundant_fs = $_[1];
  my $verbose          = $_[2];

  my ( $title, $authors );

  # build a set of lines that do not have bad words
  my @n                       = ();
  my $line_with_max_font_size = -1;
  my $max_font_size           = 0;
  foreach my $i ( 0 .. $#{$groups} ) {
    next if ( length( $groups->[$i]->{content} ) < 2 );
    my $nr_letters = ( $groups->[$i]->{content} =~ tr/[A-Za-z]// );
    next if ( $nr_letters <= 3 );
    next if ( $groups->[$i]->{content} !~ m/\s/ );
    next if ( $groups->[$i]->{nr_words} >= 100
      and $groups->[$i]->{nr_bad_author_words} > 1 );
    my $cur = $groups->[$i];
    my $tmp = $cur->{address_count};
    $tmp += $cur->{nr_bad_words};
    $tmp-- if ( $cur->{content} =~ m/(1[1-9]|20|21)\d\d/ );

    if ( $tmp == 0 ) {
      my $h = -1;
      foreach my $k ( 0 .. $#n ) {
        $h = $k if ( $n[$k]->{yMin} == $groups->[$i]->{yMin} );
      }
      if ( $h == -1 ) {
        push @n, _deep_copy($cur);
        if ( $n[$#n]->{fs} > $max_font_size ) {
          $max_font_size           = $n[$#n]->{fs};
          $line_with_max_font_size = $#n;
        }
      } else {
        my $t =
          ( $cur->{xMin} < $n[$h]->{xMin} )
          ? $cur->{content} . ' , ' . $n[$h]->{content}
          : $n[$h]->{content} . ' , ' . $cur->{content};
        $n[$h]->{content} = $t;
        if ( $n[$h]->{fs} > $max_font_size ) {
          $max_font_size           = $n[$h]->{fs};
          $line_with_max_font_size = $h;
        }
      }
    }
  }

  return ( undef, undef ) if ( $#n <= 0 );

  if ( $verbose == 1 ) {
    foreach my $i ( 0 .. $#n ) {
      print STDERR "S2|$i: ", _sprintf_line_or_group( $n[$i] );
    }
  }

  my ( $cand_au, $cand_ti ) = ( undef, undef );

  if ( $#n == 1 ) {
    if (  $n[0]->{nr_bad_author_words} == 0
      and $n[0]->{fs} < $n[1]->{fs} ) {
      $cand_au = $n[0];
      $cand_ti = $n[1];
    } elsif ( $n[1]->{nr_bad_author_words} == 0 ) {
      $cand_au = $n[1];
      $cand_ti = $n[0];
    } else {
      return ( undef, undef );
    }

    return ( undef, undef ) if ( $cand_au->{nr_common_words} > 1 );

    _clean_candidates( $cand_ti, $cand_au );

    if ( $verbose == 1 ) {
      print STDERR "S2A|cand_ti:$cand_ti->{content}\nS2A|cand_au:$cand_au->{content}\n";
    }

    if ( $cand_ti->{fs} > $cand_au->{fs} ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag > 0 );
    }

    if ( $cand_ti->{fs} == $cand_au->{fs} ) {

      # at least the title is bold
      if ( $cand_ti->{bold} == 1 and $cand_au->{bold} == 0 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }

      # at least title is really larger than the rest
      if ( $cand_ti->{fs} / $most_abundant_fs > 1.3 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }

      # if title seems to be all upper case and authors not
      if ( $cand_ti->{uc} > 0.9 and $cand_au->{uc} < 0.5 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }
    }

  } else {

    if ( $line_with_max_font_size + 1 <= $#n ) {
      if ( $n[ $line_with_max_font_size + 1 ]->{nr_bad_author_words} == 0 ) {
        $cand_au = $n[ $line_with_max_font_size + 1 ];
        $cand_ti = $n[$line_with_max_font_size];
      } else {
        if ( $line_with_max_font_size - 1 >= 0 ) {
          if ( $n[ $line_with_max_font_size - 1 ]->{nr_bad_author_words} +
            $n[ $line_with_max_font_size - 1 ]->{nr_common_words} == 0 ) {
            $cand_au = $n[ $line_with_max_font_size - 1 ];
            $cand_ti = $n[$line_with_max_font_size];
          }
        }
      }
    } elsif ( $line_with_max_font_size - 1 >= 0 ) {
      if ( $n[ $line_with_max_font_size - 1 ]->{nr_bad_author_words} == 0 ) {
        $cand_au = $n[ $line_with_max_font_size - 1 ];
        $cand_ti = $n[$line_with_max_font_size];
      }
    }

    return ( undef, undef ) if ( !defined $cand_au or !defined $cand_ti );
    return ( undef, undef ) if ( $cand_au->{nr_common_words} > 1 );

    _clean_candidates( $cand_ti, $cand_au );

    if ( $verbose == 1 ) {
      print STDERR "S2B|cand_ti:$cand_ti->{content}\nS2B|cand_au:$cand_au->{content}\n";
    }

    if ( $cand_ti->{fs} > $cand_au->{fs} ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag > 0 );
    }
    if ( $cand_ti->{fs} == $cand_au->{fs} ) {

      # at least the title is bold
      if ( $cand_ti->{bold} == 1 and $cand_au->{bold} == 0 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }

      # at least title is really larger than the rest
      if ( $cand_ti->{fs} / $most_abundant_fs > 1.3 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }
    }

  }

  return ( $title, $authors );

}

# _evaluate_pair takes the title and authors lines and compares
# the two lines if the show specific characteristics
sub _evaluate_pair {
  my $cand_ti = $_[0];
  my $cand_au = $_[1];

  if ( $cand_au->{nr_superscripts} > $cand_ti->{nr_superscripts} ) {
    return ( $cand_ti->{content}, $cand_au->{content}, 1 );
  }

  # author lines usually have a higher comma to words ratio than
  # the title does
  my $commas_title   = ( $cand_ti->{content} =~ tr/[,&]// );
  my $commas_authors = ( $cand_au->{content} =~ tr/[,&]// );
  my $words_title    = ( $cand_ti->{content} =~ tr/ // );
  my $words_authors  = ( $cand_au->{content} =~ tr/ // );
  if ( $words_title > 0 and $words_authors > 0 ) {
    if ( $commas_authors / $words_authors > $commas_title / $words_title ) {
      return ( $cand_ti->{content}, $cand_au->{content}, 2 );
    }
  }

  # authors might be separated by 'and'
  my @temp_authors = split( /(?:\sand\s|\s&\s)/i, $cand_au->{content} );
  my $okay = 0;
  foreach my $entry (@temp_authors) {
    my $spaces = ( $entry =~ tr/ // );
    $okay++ if ( $spaces <= 3 and $spaces > 0 );
  }
  if ( $okay == $#temp_authors + 1 ) {
    return ( $cand_ti->{content}, $cand_au->{content}, 3 );
  }

  # there may be just a single author
  my $spaces = ( $cand_au->{content} =~ tr/ // );
  if ( $spaces <= 3 ) {
    return ( $cand_ti->{content}, $cand_au->{content}, 4 );
  }

  # return undef if nothing matched
  return ( undef, undef, 0 );
}

sub _build_groups {
  my $lines            = $_[0];
  my $most_abundant_fs = $_[1];
  my $verbose          = $_[2];

  my $y_abstract_or_intro = _get_abstract_or_intro_pos($lines);
  my $last_line_diff      = 0;
  my $last_line_lc        = 0;
  my $last_line_uc        = 0;
  my $last_line_index     = 0;
  my @groups              = ();
  push @groups, new_line_or_group();

  foreach my $i ( 0 .. $#{$lines} ) {

    # skip the entry if we are past the Abstract or Introduction
    next if ( $lines->[$i]->{'yMin'} >= $y_abstract_or_intro );

    # consider only lines with a minimal length of 2 chars
    next if ( length( $lines->[$i]->{'content'} ) <= 1 );
    next if ( $lines->[$i]->{'content'} =~ m/^\d+,\d+$/ );

    # current and previous lines
    my $c = $lines->[$i];
    my $p = $lines->[$last_line_index];

    # calculate some features for the current and previous line
    my $diff        = abs( $p->{yMin} - $c->{yMin} );
    my $same_fs     = ( $c->{fs} == $p->{fs} ) ? 1 : 0;
    my $same_bold   = ( $c->{bold} == $p->{bold} ) ? 1 : 0;
    my $same_italic = ( $c->{italic} == $p->{italic} ) ? 1 : 0;
    my $lc          = ( $c->{content} =~ tr/[a-z]// );
    my $uc          = ( $c->{content} =~ tr/[A-Z]// );
    my $letters     = ( $c->{content} =~ tr/[a-zA-Z]// );
    $letters = 1 if ( $letters == 0 );    # pseudo to avoid diff by 0
    $uc      = $uc / $letters;
    $lc      = $lc / $letters;

    # if sng (start_new_group) is assigned a value of 1 or higher
    # a new group is started
    my $sng = 1;

    $sng = 2 if ( $c->{nr_bad_words} > 0 );
    $sng = 0 if ( $same_fs == 1 and $same_bold == 1 );
    $sng = 3 if ( $c->{starts_with_superscript} == 1 );
    $sng = 4 if ( $c->{address_count} >= 1 );

    # sometimes titles span two lines and have a foot note
    # we only start a new line if we see more than two superscripts
    # and the previous line did not have one
    $sng = 5 if ( $c->{nr_superscripts} > 1 and $p->{nr_superscripts} == 0 );

    # we might not join author lines correctly: corrrect here
    if (  $sng == 5
      and $c->{nr_bad_author_words} == 0
      and $p->{nr_bad_author_words} == 0
      and $same_fs == 1
      and $same_bold == 1
      and $same_italic == 1 ) {
      $sng = 0;
    }
    $sng = 8 if ( $c->{content} =~ m/^\d+$/ );
    $sng = 9 if ( $p->{content} =~ m/Volume\s\d+/
      and $c->{nr_bad_words} == 0 );

    # difference to previous line is really hughe
    $sng = 10 if ( $diff > 50 );
    $sng = 11 if ( $diff > ( $c->{fs} + $p->{fs} ) * 1.33 );

    $sng = 14 if ( $uc < 0.15             and $last_line_uc > 0.95 );
    $sng = 15 if ( $c->{nr_bad_words} > 1 and $p->{nr_bad_words} == 0 );

    $sng = 17 if ( $c->{nr_bad_words} == 0
      and $p->{nr_bad_words} > 0
      and $p->{content} !~ m/\s/ );

    # don't join lines that have a different font
    $sng = 18 if ( $c->{font} ne $p->{font} );
    $sng = 19 if ( $p->{content} eq '' );

    if ( $sng == 0 ) {
      if ( $c->{content} !~ m/(1[1-9]|20|21)\d\d/ ) {
        $sng = 7 if ( $c->{nr_bad_words} > 0 and $p->{nr_bad_words} == 0 );
      }

      # do not join something with a URL
      if ( $p->{content} =~ m/^www\.\S+\.[a-z]{2,3}/i ) {
        $sng = 12;
      }
      if ( $p->{content} =~ m/^[\(\[\{].*[\)\]\}]$/i ) {
        $sng = 13;
      }
    }

    print STDERR "SNG:$sng --> $c->{content} $uc $lc $diff\n" if ( $verbose == 1 );

    if ( $sng >= 1 ) {
      push @groups, new_line_or_group();
      update_line_or_group( $c, $groups[$#groups] );

    } else {
      update_line_or_group( $c, $groups[$#groups] );
    }
    $last_line_lc    = $lc;
    $last_line_uc    = $uc;
    $last_line_index = $i;
  }

  return \@groups;
}

sub MarkBadWords {
  my $self       = shift;
  my $tmp_line   = $_[0];
  my $tmp_line2  = $_[1];
  my $bad        = 0;
  my $bad_author = 0;
  $tmp_line =~ s/\s//g;

  $bad++ if ( $tmp_line =~ m/^\(.+\)$/ );
  $bad++ if ( $tmp_line =~ m/^\{/ );

  # lines that describe the type of paper
  # original article, mini review, ...
  foreach my $type ( @{ $self->_BADTYPES } ) {
    $bad++ if ( $tmp_line =~ m/$type/i );

    #print "$bad $type $tmp_line\n";
  }

  # years and numbers
  foreach my $number ( @{ $self->_NUMBERS } ) {
    $bad++ if ( $tmp_line =~ m/$number/i );

    #print "$bad $number $tmp_line\n";
  }

  # words that are not supposed to appear in title or authors
  foreach my $word ( @{ $self->_BADWORDS } ) {
    $bad++ if ( $tmp_line =~ m/$word/i );

    #print "$bad $word $tmp_line\n";
  }

  # words that are not supposed to appear in author lines
  foreach my $word ( @{ $self->_BADAUTHORWORDS } ) {
    $bad_author++ if ( $tmp_line2 =~ m/(\s|\.|,)$word(\s|\.|,)/i );
  }
  foreach my $word ( @{ $self->_BADAUTHORWORDS } ) {
    $bad_author++ if ( $tmp_line2 =~ m/^$word(\s|\.|,)/i );
  }
  foreach my $word ( @{ $self->_BADAUTHORWORDS } ) {
    $bad_author++ if ( $tmp_line2 =~ m/(\s|\.|,)$word$/i );
  }

  return ( $bad, $bad_author );
}

sub _get_abstract_or_intro_pos {
  my $lines = $_[0];

  my ( $y_a, $y_i ) = ( 10000, 10000 );

  foreach my $i ( 0 .. $#{$lines} ) {
    my $t = $lines->[$i]->{'condensed_content'};
    my $y = $lines->[$i]->{'yMin'};

    $y_a = $y if ( $t =~ m/Abstract$/i );
    $y_a = $y if ( $t =~ m/^Abstract/i );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Introduction$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Results$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Background$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^Background:/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Methods$/i and $y < $y_i and $y > 100 and $i > 3 );
    $y_i = $y if ( $t =~ m/^(\d\.?)?MaterialsandMethods$/i and $y < $y_i and $y > 100 );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Summary$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^Addresses$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^KEYWORDS:/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^SUMMARY/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^SYNOPSIS$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^Contents$/i and $y < $y_i );
  }

  return ( $y_a < $y_i ) ? $y_a : $y_i;
}

sub _most_abundant_fontsize {
  my $lines = $_[0];

  # determine most abundant fontsize
  my %tmp = ();
  $tmp{ $_->{fs} }++ foreach @{$lines};

  my ( $most_abundant_fs, $max ) = ( 0, 0 );

  for my $fs ( keys %tmp ) {
    if ( $tmp{$fs} > $max ) {
      $most_abundant_fs = $fs;
      $max              = $tmp{$fs};
    }
  }

  return $most_abundant_fs;
}

sub _check_for_cover_page {
  my $lines = $_[0];

  # some publishers like 'Cold Spring Harbor Laboratory Press' or
  # 'Oxford Journals' have a kind of cover page.

  my @phrases = (
    'top right corner of the article',
    'This article cites \d+ articles',
    'rsbl\.royalsocietypublishing\.org',
    'PLEASE SCROLL DOWN FOR ARTICLE',
    'Reprints of this article can be ordered at',
    '\d+ article\(s\) on the ISI Web of Science',
    'Receive free email alerts when new articles cite this article',
    'Please scroll down to see the full text article',
    'This Provisional PDF corresponds to the article as it appeared',
    'This reprint is provided for personal and noncommercial use'
  );

  foreach my $i ( 0 .. $#{$lines} ) {
    foreach my $phrase (@phrases) {
      return 1 if ( $lines->[$i]->{'content'} =~ m/$phrase/i );
    }
  }

  return 0;
}

sub parse_extpdf_info {
  my $self      = shift;
  my $output    = $_[0];
  my $arguments = $_[1];

  my %md = (
    'title'    => undef,
    'authors'  => undef,
    'doi'      => undef,
    'arxivid'  => undef,
    'numPages' => 1,
    'size'     => undef
  );

  return \%md if ( not defined $output->{'info'} );
  my $tmp = $output->{'info'};

  if ( $tmp->{'page'} =~ m/^ARRAY/ ) {
    if ( defined $tmp->{'page'}->[ $arguments->{page} ]->{'size'} ) {
      $md{size} = $tmp->{'page'}->[ $arguments->{page} ]->{'size'};
    }
  } elsif ( $tmp->{'page'} =~ m/^HASH/ ) {
    $md{size} = $tmp->{'page'}->{'size'};
  }

  $md{numPages} = $tmp->{'numPages'} if ( defined $tmp->{'numPages'} );

  if ( defined $tmp->{'Title'} ) {
    $md{title} = $tmp->{'Title'};

    if ( $md{title} =~ m/^doi:(10\.\d{4}\S+)/ ) {
      $md{doi}   = $1;
      $md{title} = '';
    }
    if ( $md{title} =~ m/^(10\.\d{4}\S+)/ ) {
      $md{doi}   = $1;
      $md{title} = '';
    }
    if ( $md{title} =~ m/^arXiv:\s?(\S+)/i ) {
      $md{arxivid} = $1;
      $md{title}   = '';
    }

    my $flag = 1;
    $flag = 0 if ( $md{title} =~ m/(\.doc|\.tex|\.dvi|\.e?ps|\.pdf)/ );
    $flag = 0 if ( $md{title} =~ m/(\.rtf|\.qxd|\.fm)$/ );
    $flag = 0 if ( $md{title} =~ m/^\s*$/ );
    $flag = 0 if ( $md{title} =~ m/^Microsoft/ );
    $flag = 0 if ( $md{title} =~ m/^gk[a-z]\d+/i );
    $flag = 0 if ( $md{title} =~ m/\d/ and $md{title} !~ m/\s/ );
    $flag = 0 if ( $md{title} =~ m/^PII:/ );
    $flag = 0 if ( $md{title} =~ m/^\d+\s/ );
    $flag = 0 if ( $md{title} =~ m/\d+\s*\.+\s*\d+$/ );
    $flag = 0 if ( $md{title} =~ m/Vol\.?\s\d+/i );
    $md{title} =~ s/\s+/ /g;
    $md{title} =~ s/^\s+//g;
    $md{title} =~ s/\s+$//g;
    my $count_spaces = ( $md{title} =~ tr/ // );
    $md{title} = undef if ( $count_spaces < 3 );
    $md{title} = undef if ( $flag == 0 );
  }

  return \%md;
}

sub parse_extpdf_output {
  my $self   = shift;
  my $output = $_[0];

  return ( [], [] ) if ( not defined $output->{'word'} );

  my @words = @{ $output->{'word'} };

  return ( [], [] ) if ( $#words <= 1 );

  foreach my $i ( 0 .. $#words ) {
    ( my $xMin, my $yMin, my $xMax, my $yMax ) = split( /\s+/, $words[$i]->{'bbox'} );
    $words[$i]->{xMin} = sprintf( "%.0f", $xMin );
    $words[$i]->{xMax} = sprintf( "%.0f", $xMax );

    # for yMin and yMax we assume that the word is vertically centered
    if ( ( $yMax - $yMin ) > $words[$i]->{size} + 0.5 ) {
      $words[$i]->{yMin} =
        sprintf( "%.0f", $yMax - ( $yMax - $yMin - $words[$i]->{size} ) / 2 - $words[$i]->{size} );
      $words[$i]->{yMax} = sprintf( "%.0f", $yMax - ( $yMax - $yMin - $words[$i]->{size} ) / 2 );
    } else {
      $words[$i]->{yMin} = sprintf( "%.0f", $yMin );
      $words[$i]->{yMax} = sprintf( "%.0f", $yMax );
    }
    if ( defined $words[$i]->{font} ) {
      if ( $words[$i]->{font} =~ m/Bold/i ) {
        $words[$i]->{bold} = 1;
      }
    }
    $words[$i]->{font} = 'NA' if ( not defined $words[$i]->{font} );
    $words[$i]->{font} =~ s/^[A-Z]+\+//;
    $words[$i]->{font} =~ s/(-|,)[A-Z]+$//i;
  }

  # in a first step we want to group words into lines
  my @lines         = ();
  my @words_rotated = ();

  # kick-off @lines with the first non-rotated word
  my $start = 0;
  foreach my $i ( 0 .. $#words ) {
    if ( $words[$i]->{'rotation'} ) {
      push @words_rotated, $words[$i];
      next;
    } else {
      push @lines, new_line_or_group();
      update_line_or_group( $words[$i], $lines[$#lines] );
      $start = $i + 1;
      last;
    }
  }

  foreach my $i ( $start .. $#words ) {

    # let's have a look if we should append to the last entry.
    # @lines stores the yMin and yMax values that have
    # the broadest span; if a word has its yMin or yMax values
    # within that span it will be added to the current line
    # bounding box usually seems to be greater than the font size
    # if bounding boxes overlap, a new line is only started if
    # less than 25/30% of the word are covered by the last bounding box

    my $inrange = 0;
    my $span_i  = $words[$i]->{'yMax'} - $words[$i]->{'yMin'};
    if ( $words[$i]->{'rotation'} ) {
      push @words_rotated, $words[$i];
      next;
    }

    my $last_yMin = $lines[$#lines]->{'yMin'};
    my $last_yMax = $lines[$#lines]->{'yMax'};

    # get xMIn of the last line
    my $line_xMin = 10e6;
    foreach my $j ( 0 .. $#{ $lines[$#lines]->{'words'} } ) {
      my $other = $lines[$#lines]->{'words'}->[$j];
      $line_xMin = $other->{xMin} if ( $other->{xMin} < $line_xMin );
    }

    if (  $last_yMin <= $words[$i]->{'yMin'}
      and $words[$i]->{'yMax'} <= $last_yMax ) {
      $inrange = 1;
    } elsif ( $last_yMin <= $words[$i]->{'yMax'}
      and $words[$i]->{'yMax'} <= $last_yMax ) {
      my $span = $words[$i]->{'yMax'} - $last_yMin;
      $inrange = 1 if ( $span / $span_i > 0.25 );
    } elsif ( $last_yMin <= $words[$i]->{'yMin'}
      and $words[$i]->{'yMin'} <= $last_yMax ) {
      my $span = $last_yMax - $words[$i]->{'yMin'};
      $inrange = 1 if ( $span / $span_i > 0.3 );
    } elsif ( $words[$i]->{'yMin'} <= $last_yMin
      and $last_yMax <= $words[$i]->{'yMax'} ) {
      my $span = ( $words[$i]->{'yMax'} - $words[$i]->{'yMin'} ) - ( $last_yMax - $last_yMin );
      $inrange = 1 if ( $span <= 10 );
    }

#print "$inrange line:$last_yMin-$last_yMax $words[$i]->{'yMin'}-$words[$i]->{'yMax'} $words[$i]->{'content'} $line_xMin  $words[$i]->{'xMin'}\n";
    if ( $inrange == 1 and $words[$i]->{xMin} <= $line_xMin and $line_xMin < 50 ) {
      $inrange = 0;
    }

    push @lines, new_line_or_group() if ( $inrange == 0 );
    update_line_or_group( $words[$i], $lines[$#lines] );
  }

  my @filtered_lines = ();
  foreach my $line (@lines) {
    $self->calculate_line_features( $line, 1 );
    push @filtered_lines, $line if ( $line->{fs} > 3 );
  }

  return ( \@filtered_lines, \@words_rotated );
}

sub _search_for_arXivid {
  my $lines         = $_[0];
  my $words_rotated = $_[1];

  my $arxivid;
  foreach my $i ( 0 .. $#{$lines} ) {
    if ( $lines->[$i]->{'content'} =~ m/arxiv:\s?(\S+)/i ) {
      $arxivid = $1;
    }
  }
  foreach my $i ( 0 .. $#{$words_rotated} ) {
    if ( $words_rotated->[$i]->{'content'} ) {
      if ( $words_rotated->[$i]->{'content'} =~ m/arxiv:\s?(\S+)/i ) {
        $arxivid = $1;
      }
    }
  }

  return $arxivid;
}

sub _search_for_DOI {
  my $lines = $_[0];

  my $doi = '';
  foreach my $i ( 0 .. $#{$lines} ) {
    my $tmp = $lines->[$i]->{'content'};
    if ( $tmp =~ m/(10\.\d{4})/i ) {
      $doi = _ParseDOI($tmp);
    }

    # the DOI may be split into two lines
    if ( $doi eq '' and $i < $#{$lines} ) {
      my $next_line;
      foreach my $j ( $i + 1 .. $#{$lines} ) {
        if ( abs( $lines->[$j]->{'xMin'} - $lines->[$i]->{'xMin'} ) < 5
          and $lines->[$j]->{'yMin'} > $lines->[$i]->{'yMin'} ) {
          $next_line = $j;
          last;
        }
      }

      if ( defined $next_line ) {
        $tmp = $lines->[$i]->{'content'} . $lines->[$next_line]->{'content'};
        $doi = _ParseDOI($tmp);
      }
    }

    # if the DOI seems to be too short
    if ( $doi ne '' and length($doi) <= 10 ) {
      if ( $tmp =~ m/($doi)\s+(\S+)/i ) {
        $doi = _ParseDOI( $1 . $2 );
      }
    }

    last if ( $doi ne '' and length($doi) > 10 );
  }

  $doi = undef if ( $doi eq '' );

  return $doi;
}

sub _ParseDOI {
  my $line = $_[0];
  my $doi  = $line;

  # there might be a strange minus sign (unicode &#8211; --> \x{2013}
  $doi =~ s/\s\x{2013}\s/-/g;

  if ( $doi =~ m/\D?(10\.\d{4})/ ) {
    $doi =~ s/(.*)(10\.\d{4})(\/?\s*)(\S+)(.*)/$2\/$4/;
    $doi =~ s/\(*\)*//g;
  } else {
    $doi = '';
  }

  # clean DOI
  $doi =~ s/,//g;
  $doi =~ s/\.$//;
  $doi =~ s/;$//;
  $doi =~ s/\x{35E}//g;
  $doi =~ s/\x{354}//g;
  $doi =~ s/([^\|]+)(\|.*)/$1/;

  # check for minimal length
  if ( $doi =~ m/(10\.\d{4}\/)(.*)/ ) {
    $doi = '' if ( length($2) < 5 );
  }

  #$doi =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg;
  $doi =~ s/[^[:ascii:]]$//g;

  return $doi;
}

sub calculate_line_features {
  my $self      = shift;
  my $in        = $_[0];
  my $sort_flag = ( defined $_[1] ) ? $_[1] : 0;

  if ( $sort_flag == 1 ) {
    my @tmpa = sort { $a->{xMin} <=> $b->{xMin} } @{ $in->{'words'} };
    $in->{'words'} = \@tmpa;
  }

  # it might be necessary to redo appending at this stage
  # because the input was not correctly sorted
  foreach my $i ( 1 .. $#{ $in->{'words'} } ) {
    my $d = abs( $in->{words}->[$i]->{xMin} - $in->{words}->[ $i - 1 ]->{xMax} );

    #print "$d $in->{words}->[$i]->{content}\n";
    if ( $d <= 1 and $in->{words}->[ $i - 1 ]->{size} == $in->{words}->[$i]->{size} ) {
      if (  $in->{words}->[ $i - 1 ]->{content} =~ m/^[A-Z]+$/
        and $in->{words}->[$i]->{content} =~ m/^[A-Z]+.,?$/ ) {
        $in->{words}->[ $i - 1 ]->{content} .= $in->{words}->[$i]->{content};
        $in->{words}->[$i]->{content} = '';
      }
    }
  }

  # recalculate yMin
  my %seen_yMin = ();
  my %fonts     = ();
  foreach my $word ( @{ $in->{'words'} } ) {
    $seen_yMin{ $word->{yMin} } += length( $word->{content} );
    $fonts{ $word->{font} }++ if ( $word->{font} );
  }
  my @sorted_yMin = ( sort { $seen_yMin{$b} <=> $seen_yMin{$a} } keys %seen_yMin );
  $in->{yMin} = $sorted_yMin[0];
  my @sorted_fonts = ( sort { $fonts{$b} <=> $fonts{$a} } keys %fonts );
  $in->{font} = $sorted_fonts[0];

  foreach my $word ( @{ $in->{'words'} } ) {
    $in->{'bold_count'}++   if ( $word->{'bold'} );
    $in->{'italic_count'}++ if ( $word->{'italic'} );

    # do not let superscripts determine the major font size
    $in->{'fs_freqs'}->{ $word->{'size'} }++ if ( abs( $in->{yMin} - $word->{yMin} ) <= 1 );
    $in->{'nr_words'}++ if ( $word->{'content'} ne '' );
    $in->{'xMin'} = $word->{'xMin'} if ( $word->{'xMin'} < $in->{'xMin'} );
    $in->{'xMax'} = $word->{'xMax'} if ( $word->{'xMax'} > $in->{'xMax'} );
  }

  # set at least 1, otherwise we will get divisions by zero
  $in->{'nr_words'} = 1 if ( $in->{'nr_words'} == 0 );

  # determine the major font size for the line
  for my $key ( keys %{ $in->{fs_freqs} } ) {
    $in->{'fs'} = $key if ( $in->{fs_freqs}->{$key} / $in->{nr_words} > 0.5 );
  }

  # if we have not set a font size for the line yet,
  # we take the largest one
  if ( not defined $in->{'fs'} ) {
    $in->{'fs'} = 0;
    for my $key ( keys %{ $in->{fs_freqs} } ) {
      $in->{'fs'} = $key if ( $key > $in->{'fs'} );
    }
  }

  if ( $in->{nr_words} > 0 ) {
    $in->{bold}   = 1 if ( $in->{bold_count} / $in->{nr_words} >= 0.5 );
    $in->{italic} = 1 if ( $in->{italic_count} / $in->{nr_words} >= 0.9 );
  }

  # parse for superscripts
  my $i           = -1;
  my @tmp_content = ();

  # special chars that mark authors
  my $special_chars = "\x{A0}|\x{A7}|\x{204E}|\x{2021}|";
  $special_chars .= "\x{2020}|\x{B9}|\x{B2}|\\*|\x{B6}|\x{288}|\x{2217}";
  my $nr_common_words = 0;
  foreach my $word ( @{ $in->{'words'} } ) {
    $i++;
    next if ( $word->{'content'} eq '' );
    $nr_common_words++ if ( defined $self->_COMMONWORDS->{ uc( $word->{'content'} ) } );
    push @tmp_content, $word->{'content'};

    #print "$word->{'content'}\n";
    if ( $word->{'size'} < $in->{'fs'} ) {

      while ( $word->{'content'} =~ m/(.*)($special_chars)(.*)/ ) {
        $word->{'content'} = $1 . ',' . $3;
      }

      # do not make SMALL CAPS superscripts
      next if ( $word->{content} =~ m/^[A-Z\-]{3,}[^A-Za-z]{0,2}$/ );
      next if ( $word->{content} =~ m/^[A-Z][a-z]{3,}/ );
      next if ( $word->{content} =~ m/^10\.\d{4}/ );
      next if ( length( $word->{content} ) > 10 );
      $word->{'content'} = ',';

      #print "\t$word->{content}\n";
      $in->{'nr_superscripts'}++;
      $in->{'starts_with_superscript'} = 1 if ( $i == 0 );
      next;
    }

    my $starts_regular = ( $word->{'content'} =~ m/^[A-Z]/i ) ? 1 : 0;
    while ( $word->{'content'} =~ m/(.*)($special_chars)(.*)/ ) {
      $word->{'content'} = $1 . ',' . $3;
      $in->{'nr_superscripts'}++;
      $in->{'starts_with_superscript'} = 1 if ( $i == 0 and $starts_regular == 0 );
    }
  }
  $in->{'nr_common_words'} = $nr_common_words;

  # build the line content
  my @content = ();
  foreach my $i ( 0 .. $#{ $in->{'words'} } ) {

    # if words are in the same line, but separated by
    # a hughe region, we addd a comma
    my $c = $in->{'words'}->[$i];

    if ( $i > 0 ) {
      my $d = $c->{xMin} - $in->{'words'}->[ $i - 1 ]->{xMax};

      #print "$c->{'content'} $d\n";
      $c->{'content'} = ', ' . $c->{'content'} if ( $d >= 20 );
    }

    # do not add e-mail addresses
    next if ( $c->{'content'} =~ m/\S+@\S+/ );

    push @content, $c->{'content'};
  }

  $in->{'content_all'} = join( " ", @tmp_content );
  $in->{'content'}     = join( " ", @content );

  # clean content
  if ( $in->{'content'} =~ m/(.{10,})(\s[\.\-_]{5,}.*)/ ) {
    $in->{'content'} = $1;
  }
  $in->{'content_all'} =~ s/(.*\s)(\S+\s?@\s?\S+)(.*)/$1$3/g;
  $in->{'content'}     =~ s/(.*\s)(\S+\s?@\s?\S+)(.*)/$1$3/g;

  # repair common OCR errors and other stuff
  my %OCRerrors = (
    '\x{FB00}'            => 'ff',
    '\x{FB01}'            => 'fi',
    '\x{FB02}'            => 'fl',
    '\x{FB03}'            => 'ffi',
    '\x{A8}\so'           => "\x{F6}",
    '\x{A8}\sa'           => "\x{E4}",
    '\x{A8}\su'           => "\x{FC}",
    'o\s\x{A8}'           => "\x{F6}",
    'a\s\x{A8}'           => "\x{E4}",
    'u\s\x{A8}'           => "\x{FC}",
    '\x{131}'             => 'i',        # Unicode Character 'LATIN SMALL LETTER DOTLESS I'
    '\x{2013}'            => '-',        # Unicode Character 'EN DASH'
    '\x{2014}'            => ' - ',      # Unicode Character 'EM DASH'
    '\x{2018}'            => "'",        # Unicode Character 'LEFT SINGLE QUOTATION MARK'
    '\x{2019}'            => "'",        # Unicode Character 'RIGHT SINGLE QUOTATION MARK'
    '\x{2032}'            => "'",        # Unicode Character 'PRIME'
    '\x{2039}'            => '',
    '\x{C6}'              => ',',        # Unicode Character 'LATIN CAPITAL LETTER AE'
    '\x{B7}'              => ',',        # Unicode Character 'MIDDLE DOT'
    '\x{B4}'              => '',         # Unicode Character 'ACUTE ACCENT'
    '\x{60}'              => '',         # Unicode Character 'GRAVE ACCENT'
    '\x{2DA}'             => '',         # Unicode Character 'RING ABOVE'
    '\x{2C6}'             => '',         # Unicode Character 'MODIFIER LETTER CIRCUMFLEX ACCENT'
    '\x{2DC}'             => '',         # Unicode Character 'SMALL TILDE'
    '[\x{1C00}-\x{1C7F}]' => ''

  );

  while ( my ( $key, $value ) = each(%OCRerrors) ) {
    $in->{'content'} =~ s/$key/$value/g;
  }

  my %cannot_be_mapped_to_unicode = (
    '\x{A1}' => '',                      # Unicode Character 'INVERTED EXCLAMATION MARK'
    '\x{C3}' => '',
    '\x{A8}' => ''                       # Unicode Character 'DIAERESIS'
  );
  while ( my ( $key, $value ) = each(%cannot_be_mapped_to_unicode) ) {
    $in->{'content'} =~ s/$key/$value/g;
  }

  # some cleaning
  $in->{'content'} =~ s/\s+,/,/g;
  $in->{'content'} =~ s/,+/,/g;
  $in->{'condensed_content'} = $in->{'content'};
  $in->{'condensed_content'} =~ s/\s+//g;

  # screen for address words
  foreach my $word ( @{ $self->_ADDRESS } ) {
    $in->{'address_count'}++ if ( $in->{'content'} =~ m/$word/i );
  }

  # count bad words
  ( $in->{'nr_bad_words'}, $in->{'nr_bad_author_words'} ) =
    $self->MarkBadWords( $in->{'content_all'}, $in->{'content'} );
}

sub update_line_or_group {
  my $in      = $_[0];
  my $hashref = $_[1];

  # check if we add a word or a line
  if ( defined $in->{condensed_content} ) {

    $hashref->{nr_words}            += $in->{nr_words};
    $hashref->{bold_count}          += $in->{bold_count};
    $hashref->{italic_count}        += $in->{italic_count};
    $hashref->{nr_superscripts}     += $in->{nr_superscripts};
    $hashref->{address_count}       += $in->{address_count};
    $hashref->{nr_bad_words}        += $in->{nr_bad_words};
    $hashref->{nr_common_words}     += $in->{nr_common_words};
    $hashref->{nr_bad_author_words} += $in->{nr_bad_author_words};
    $hashref->{fs} = $in->{fs};
    $hashref->{content} .= ' #PPRJOIN#' . $in->{content};
    $hashref->{condensed_content} .= $in->{condensed_content};
    $hashref->{bold}   = $in->{bold}   if ( $in->{bold} == 1 );
    $hashref->{italic} = $in->{italic} if ( $in->{italic} == 1 );
    $hashref->{starts_with_superscript} = $in->{starts_with_superscript}
      if ( $in->{starts_with_superscript} == 1 );
    $hashref->{yMin} = $in->{yMin} if ( $in->{yMin} > $hashref->{yMin} );
    $hashref->{xMin} = $in->{xMin} if ( $in->{xMin} < $hashref->{xMin} );
    $hashref->{content} =~ s/^\s#PPRJOIN#//;

  } else {

    return if ( not defined $in->{'content'} );
    return if ( $in->{content} =~ m/^\x{A3}$/ );
    return if ( $in->{content} =~ m/^\x{A8}$/ );
    return if ( $in->{content} =~ m/^\x{B4}$/ );
    return if ( $in->{content} =~ m/^\x{C1}$/ );
    return if ( $in->{content} =~ m/^\x{CF}$/ );
    return if ( $in->{content} =~ m/^\x{E1}$/ );
    return if ( $in->{content} =~ m/^\x{E4}$/ );
    return if ( $in->{content} =~ m/^\x{E5}$/ );
    return if ( $in->{content} =~ m/^\x{E6}$/ );
    return if ( $in->{content} =~ m/^\x{E7}$/ );
    return if ( $in->{content} =~ m/^\x{E8}$/ );
    return if ( $in->{content} =~ m/^\x{F6}$/ );
    return if ( $in->{content} =~ m/^\x{F8}$/ );
    return if ( $in->{content} =~ m/^\x{FC}$/ );

    return if ( $in->{size} < 3 );

    my $span_w = $in->{'yMax'} - $in->{'yMin'};
    my $span_l = $hashref->{'yMax'} - $hashref->{'yMin'};
    if ( $span_w > $span_l ) {
      $hashref->{'yMax'} = $in->{'yMax'};
      $hashref->{'yMin'} = $in->{'yMin'};
    }

    # no further checks required if it is the first one
    if ( $#{ $hashref->{'words'} } == -1 ) {
      push @{ $hashref->{'words'} }, $in;
      return;
    }

    # append instead of add, if very close by
    my $lastone = $hashref->{'words'}->[ $#{ $hashref->{'words'} } ];
    my $d_abs   = abs( $in->{xMin} - $lastone->{xMax} );
    my $d       = $in->{xMin} - $lastone->{xMax};
    if (  $d_abs <= 1
      and $lastone->{size} == $in->{size} ) {
      $lastone->{xMax} = $in->{xMax};
      my $spacer = ( $in->{content} =~ m/^[A-Z][a-z]+/ ) ? ' ' : '';
      $lastone->{content} .= $spacer . $in->{content};
      return;
    }

    if ( $d < 0 and $d > -10 and $lastone->{size} == $in->{size} ) {
      if ( $lastone->{content} =~ m/\W$/ ) {
        $lastone->{xMax} = $in->{xMax};
        my $spacer = ( $in->{content} =~ m/^[A-Z][a-z]+/ ) ? ' ' : '';
        $lastone->{content} .= $spacer . $in->{content};
        return;
      }
    }

    # append if we see small caps
    if (  $d_abs == 0
      and $lastone->{content} !~ m/[a-z]/
      and $lastone->{content} =~ m/[A-Z]/
      and $in->{content} !~ m/[a-z]/
      and $in->{content} =~ m/[A-Z]/ ) {
      $lastone->{xMax} = $in->{xMax};
      $lastone->{content} .= $in->{content};
      return;
    }

    # we often see problems with umlaute
    # they are often encoded by two chars at the same position
    # we only add a word if it does not overlap
    # with any other word seen so far
    my $flag      = 1;
    my $overlaper = -1;
    foreach my $j ( 0 .. $#{ $hashref->{'words'} } ) {
      my $other = $hashref->{'words'}->[$j];
      if ( $other->{xMin} < $in->{xMin} and $in->{xMin} < $other->{xMax} ) {
        $flag      = 0;
        $overlaper = $j;
      }
      if ( $other->{xMin} < $in->{xMax} and $in->{xMax} < $other->{xMax} ) {
        $flag      = 0;
        $overlaper = $j;
      }
    }
    $flag = 1 if ( $in->{'content'} =~ m/10\.\d{4}/ );
    if ( $flag == 1 ) {
      push @{ $hashref->{'words'} }, $in;
    } else {

      # let's check if would should skip or replace
      # we keep the longer one
      if (  length( $hashref->{'words'}->[$overlaper]->{content} ) < 2
        and length( $in->{'content'} ) >= 2 ) {
        $hashref->{'words'}->[$overlaper] = $in;
      }
    }
    return;
  }

  return;
}

sub new_line_or_group {

  my $hashref = {
    'words'                   => [],
    'nr_words'                => 0,
    'yMin'                    => 0,
    'yMax'                    => 0,
    'xMin'                    => 10e6,
    'xMax'                    => 0,
    'fs_freqs'                => {},
    'bold_count'              => 0,
    'italic_count'            => 0,
    'bold'                    => 0,
    'italic'                  => 0,
    'nr_superscripts'         => 0,
    'starts_with_superscript' => 0,
    'fs'                      => undef,
    'content'                 => '',
    'condensed_content'       => '',
    'content_all'             => '',
    'address_count'           => 0,
    'nr_bad_words'            => 0,
    'nr_bad_author_words'     => 0,
    'nr_common_words'         => 0,
    'font'                    => ''
  };

  return $hashref;
}

# some helper functions
sub _deep_copy {
  my $in  = $_[0];
  my $out = new_line_or_group();

  foreach my $key ( keys %{$in} ) {
    if ( $key eq 'words' ) {
      foreach my $entry ( @{ $in->{$key} } ) {
        my $new_word = {};
        foreach my $key2 ( keys %{$entry} ) {
          $new_word->{$key2} = $entry->{$key2};
        }
        push @{ $out->{$key} }, $new_word;
      }
    } elsif ( $key eq 'fs_freqs' ) {
      foreach my $key2 ( %{ $in->{$key} } ) {
        $out->{$key}->{key2} = $in->{$key}->{key2};
      }
    } else {
      $out->{$key} = $in->{$key};
    }
  }

  return $out;
}

sub _sprintf_line_or_group {
  my $in = $_[0];

  my $s = "yMin:$in->{yMin} ";
  $s .= "x:$in->{xMin}-$in->{xMax} ";
  $s .= "fs:$in->{fs} ";
  $s .= "bad:$in->{nr_bad_words} ";
  $s .= "bad_au:$in->{nr_bad_author_words} ";
  $s .= "bold:$in->{bold} ";
  $s .= "sup:$in->{nr_superscripts} ";
  $s .= "address:$in->{address_count} ";
  $s .= "font:$in->{font} ";
  $s .= "common:$in->{nr_common_words}\n";
  $s .= "\t$in->{content}\n";

  return $s;
}

1;
