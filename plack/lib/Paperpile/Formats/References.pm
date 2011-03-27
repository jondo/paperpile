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

package Paperpile::Formats::References;
use Mouse;
use Encode;
use utf8;
use XML::Simple;
use Data::Dumper;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;

has '_PATTERNS' => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );
has '_RULES'    => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );
has '_REGEXPS'  => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );
has '_RULES_INPROCEEDINGS' => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );
has '_RULES_BOOK'          => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );
has '_RULES_INBOOK'        => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );
has '_RULES_INCOLLECTION'  => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );
has '_RULES_ARTICLE'       => ( is => 'rw', isa => 'ArrayRef', default => sub { return [] } );

sub BUILD {
  my ( $self, $args ) = @_;

  my $rules_file;
  my $data_file;

  # check if files are provided
  if ( $args ) {
    if ( $args->{rules_file} ) {
      if ( ! -e $args->{rules_file} ) {
	print STDERR "No valid citations-rules.xml file provided.\n";
      } else {
	$rules_file = $args->{rules_file};
      }
    } else {
      print STDERR "No valid citations-rules.xml file provided.\n";
    }
    if ( $args->{data_file} ) {
      if ( ! -e $args->{data_file} ) {
	print STDERR "No valid citations-data.xml file provided.\n";
      } else {
	$data_file = $args->{data_file};
      }
    } else {
      print STDERR "No valid citations-data.xml file provided.\n";
    }
  } else {
    print STDERR "No valid citations-rules.xml and citations-data.xml files provided.\n";
  }

  # Read regexp rules form $rules_file

  my $RULES_INPROCEEDINGS = [];
  my $RULES_BOOK          = [];
  my $RULES_INBOOK        = [];
  my $RULES_INCOLLECTION  = [];
  my $RULES_ARTICLE       = [];

  my %RULES = ( 'ARTICLE_NOTITLE' => '_ANY_ , _AN1_ _VO_ , _IS_ (_Y1_) .?', );

  if ( $rules_file ) {
    open( XMLRULES, "<$rules_file" ) or die("Could not open rules file ");

    my $content = '';
    $content .= $_ foreach (<XMLRULES>);
    my $parsedXML = XMLin( $content, ForceArray => ['entry'], KeyAttr => { namedRegex => 'type' } );

    foreach my $entry ( @{ $parsedXML->{'entry'} } ) {

      if ( $entry->{type} eq 'BOOK' ) {
	my $counter = 0;
	foreach my $rule ( @{ $entry->{rule} } ) {
	  $counter++;
	  $counter = sprintf( "%02d", $counter );
	  $RULES{"BOOK$counter"} = $rule . ' .?';
	  push @{$RULES_BOOK}, "BOOK$counter";
	  # Make INBOK entries
	  $RULES{"INBOOK$counter\_COPIED"} = $rule . ' %4 _PP_ _PA_ .?';
	  push @{$RULES_INBOOK}, "INBOOK$counter\_COPIED";
	}
      }
      if ( $entry->{type} eq 'INCOLLECTION' ) {
	my $counter = 0;
	foreach my $rule ( @{ $entry->{rule} } ) {
	  $counter++;
	  $counter = sprintf( "%02d", $counter );
	  $RULES{"INCOLLECTION$counter"} = $rule . ' .?';
	  push @{$RULES_INCOLLECTION}, "INCOLLECTION$counter";
	  if ( $rule =~ m/(.*)(_Y\d_.*)/ ) {
	    $RULES{"INCOLLECTION$counter\_MO"} = "$1 _MO_ $2 .?";
	    push @{$RULES_INCOLLECTION}, "INCOLLECTION$counter\_MO";
	  }
	}
      }
      if ( $entry->{type} eq 'INPROCEEDINGS' ) {
	my $counter = 0;
	foreach my $rule ( @{ $entry->{rule} } ) {
	  $counter++;
	  $counter = sprintf( "%02d", $counter );
	  $RULES{"INPROCEEDINGS$counter"} = $rule . ' .?';
	  push @{$RULES_INPROCEEDINGS}, "INPROCEEDINGS$counter";
	  if ( $rule =~ m/(.*)(_Y\d_.*)/ ) {
	    $RULES{"INPROCEEDINGS$counter\_MO"} = "$1 _MO_ $2 .?";
	    push @{$RULES_INPROCEEDINGS}, "INPROCEEDINGS$counter\_MO";
	  }
	}
      }
      if ( $entry->{type} eq 'ARTICLE' ) {
	my $counter = 0;
	foreach my $rule ( @{ $entry->{rule} } ) {
	  $counter++;
	  $counter = sprintf( "%02d", $counter );
	  $RULES{"ARTICLE$counter"} = $rule . ' .?';
	  push @{$RULES_ARTICLE}, "ARTICLE$counter";
	  if ( $rule =~ m/(.*)(_Y\d_.*)/ ) {
	    $RULES{"ARTICLE$counter\_MO"} = "$1 _MO_ $2 .?";
	    push @{$RULES_ARTICLE}, "ARTICLE$counter\_MO";
	  }
	}
      }
    }
  }

  # read in regular expressions
  my @months     = (
    '[Jj]an(?:uary)?',          '[Ff]eb(?:ruary)?',
    '[Mm]ar(?:ch)?',            '[Aa]pr(?:il)?',
    '[Mm]ay',                   '[Jj]un(?:e)?',
    '[Jj]ul(?:y)?',             '[Aa]ug(?:ust)?',
    '[Ss]ep(?:tember|tembre)?', '[Oo]ct(?:ober|obre)?',
    '(?:[Nn]ov|[Dd]ec)(?:ember|embre)?'
  );

  my @publishers = ();
  my @series     = ();
  my @inpress    = ();
  if ( $data_file ) {
    open( DATAXML, "<$data_file" ) or die("Could not open data file ");

    my $content = '';
    $content .= $_ foreach (<DATAXML>);
    my $parsedXML = XMLin( $content, ForceArray => ['entry'], KeyAttr => { namedRegex => 'name' } );

    foreach my $entry ( @{ $parsedXML->{'entry'} } ) {
      if ( $entry->{name} eq 'Publishers' ) {
	@publishers = @{ $entry->{item} };
      }
      if ( $entry->{name} eq 'Series' ) {
	@series = @{ $entry->{item} };
      }
      if ( $entry->{name} eq 'InPress' ) {
	@inpress = @{ $entry->{item} };
      }
    }
  }

  my @city = (
    'NY',
    '[A-Z][a-z]+,\s([A-Z]{2}|USA\.?)',                         # One-Word City with State or Country
    '(?:[A-Z][a-z]+|St\.)\s[A-Z][a-z]+,\s([A-Z]{2}|USA\.?)',   # Two-Word City with State or Country
    '(?:[A-Z][a-z]+|St\.)\s[A-Z][a-z]+',                       # Two-Word City
    '[A-Z][a-z]+',                                             # One-Word City
    '(?:[A-Z][a-z]+|St\.)\s[A-Z][a-z]+,\s[A-Z][a-z]+\s[A-Z][a-z]+'
    ,    # Two-Word City, with two-word state or country
    '(?:[A-Z][a-z]+|St\.)\s[A-Z][a-z]+,\s[A-Z][a-z]+'
    ,                                            # Two-Word City, with one-word state or country
    '[A-Z][a-z]+,\s[A-Z][a-z]+',                 # One-Word City, with one-word state or country
    '[A-Z][a-z]+,\s[A-Z][a-z]+\s[A-Z][a-z]+',    # One-Word City, with two-word state or country
    'Cold Spring Harbor, New York|Cold Spring Harbor, NY|Cold Spring Harbor(?!,\sN)',
  );

  # mapping of patterns to regular expressions
  my %PATTERNS = (
    '_ANY_' => '(.*)',
    '_AN1_' => '(.*[^\d])',
    '_JO_'  => '(([A-Z]|[a-z]|\s|\.|&|:|\(|\)){2,}(\([A-Z][a-z]+\))?)',
    '_VO_'  => '(\d+|\d+[A-Z]|\d+[a-z])',
    '_IS_' =>
      '(\d+|\d+-\d+|\S+\sissue|\d+[A-Z]|\d+[a-z]|[Ss]uppl\.?\s\d+|\d+\/\d+|[Nn]o\.\s\d+|[Ss]uppl\.?)',
    '_PA_' =>
      '([DERSWdersw]?\d+\s*-\s*[DERSWdersw]?\d+|[DERSWdersw]?\d+|[Ii]{1,2}\d+\s*-\s*[Ii]{0,2}\d+)',
    '_Y1_'   => '(\d{4}[a-z]?)',
    '_Y0_'   => '(\(\d{4}[a-z]?\)|\d{4}(?![a-z]?\))|\d{4}[a-z](?!\)))',
    '_IP_'   => '(' . join( '|', @inpress ) . ')',
    '_MO_'   => '(' . join( '|', @months ) . ')',
    '_PU_'   => '(' . join( '|', @publishers ) . ')',
    '_SR_'   => '(' . join( '|', @series ) . ')',
    '_SE_'   => '([^:,\.]+)',
    '_AD_'   => '(' . join( '|', @city ) . ')',
    '_EE_'   => '(.*)',
    '_AU_'   => '(.*)',
    '_AU1_'  => '(\D*)',
    '_BT_'   => '(.*)',
    '_PR_'   => '(([Ii]n:?\s)?[^,]*([Pp]roceedings|[Pp]roc\.|[Cc]onference|[Ss]ymposium)[^,]*)',
    '_PP_'   => '(pages|pp\.?|pgs\.?|(?<!p)p\.)',
    '%0'     => '[\.,]+',
    '%1'     => '[\.\?,]+',
    '%2'     => '[\.\?,:]+',
    '%3'     => '[\.\?,:;]+',
    '%4'     => '[\.\?,:;\s]+',
    '%I'     => '[\.\?,:;\s]+[Ii]n:?\s',
    '%P'     => '[\.\?,:;\s]+(?:pages|pp\.?|pgs\.?|(?<!p)p\.)',
    '%E'     => '(?:[Ee]ditors?|[Ee]ds\.?|[Ee]dited\sby)',
    '%V'     => '[\.\?,:;\s]+(?:[Vv]olume|[Vv]ol\.|[Vv]olume\sof|[Vv]ol\.\sof)'
  );

  # build the regular expressions here
  $self->_REGEXPS( build_regexp( \%RULES, \%PATTERNS ) );
  $self->_RULES( \%RULES );
  $self->_PATTERNS( \%PATTERNS );
  $self->_RULES_INPROCEEDINGS($RULES_INPROCEEDINGS);
  $self->_RULES_BOOK($RULES_BOOK);
  $self->_RULES_INBOOK($RULES_INBOOK);
  $self->_RULES_INCOLLECTION($RULES_INCOLLECTION);
  $self->_RULES_ARTICLE($RULES_ARTICLE);

}


sub parseReferences {
  my $self          = shift;
  my $strings       = $_[0];
  my $output        = [];
  my $allstrategies = 0;
  my $debug         = 0;

  # preprocessing of reference strings
  for my $i ( 0 .. $#{$strings} ) {
    $strings->[$i] = clean( $strings->[$i] );
  }

  # stores the number how often a string was parsed with
  # a particular rule
  my %levels = ();

  # first round of processing
  foreach my $string ( @{$strings} ) {

    my ( $pub, $level ) = $self->parse_JournalArticle( $string, undef, $debug );

    if ( $level ne 'NA' ) {
      $levels{$level}++;
      push @{$output}, $pub;
    } else {
      my ( $pub_other, $level_other ) = $self->split_to_components_others( $string, undef, $debug );
      if ( $level_other ne 'NA' ) {
        push @{$output}, $pub_other;
      } else {
        push @{$output}, $string;
      }
    }
  }

  # second round of processing: if we failed so far in processing a reference
  # string, we make the string shorter each round and apply the rules that we
  # have used so far; we take the last matching publication object
  my @sorted_by_counts = reverse sort { $levels{$a} <=> $levels{$b} } keys %levels;
  for ( my $i = 0 ; $i <= $#{$output} ; $i++ ) {
    next if ( $output->[$i] =~ m/Paperpile::Library::Publication/ or $allstrategies == 0 );

    my $tmp = $output->[$i];
    while ( $tmp =~ m/(.*)(\.[^\.]+)$/ ) {
      $tmp = $1;
      foreach my $rule (@sorted_by_counts) {
        my ( $pub, $level ) = $self->parse_JournalArticle( $tmp, $rule );
        if ( $level ne 'NA' ) {
          $output->[$i] = $pub;
        }
      }
    }
  }

  # third round of processing: if we failed so far in processing a reference
  # string, we do free style parsing without rules now.
  for ( my $i = 0 ; $i <= $#{$output} ; $i++ ) {
    next if ( $output->[$i] =~ m/Paperpile::Library::Publication/ or $allstrategies == 0 );

  }

  return $output;
}

sub split_to_components_others {
  my $self     = shift;
  my $string   = $_[0];
  my $mofifier = $_[1];
  my $debug    = ( $_[2] ) ? $_[2] : 0;

  print STDERR "$string\n" if ( $debug == 1 );

  my $tmphash =  _build_tmphash('BOOK');

  my $level = 'NA';

  my %REGEXPs  = %{ $self->_REGEXPS() };
  my %PATTERNS = %{ $self->_PATTERNS() };
  my %RULES    = %{ $self->_RULES() };

  my $passed = 1;
  $passed = 0 if ( $string =~ m/Proceedings(?!\sof\sthe\sNational\sAcademy\sof\sSciences)/ );
  $passed = 0 if ( $string =~ m/Proc\.(?!\sof\sthe\sNational\sAcademy\sof\sSciences)/ );

  if ( $passed == 1 ) {

    print STDERR "Proceedings check passed.\n" if ( $debug == 1 );
    foreach my $rule ( @{ $self->_RULES_BOOK() } ) {
      next if ( !$REGEXPs{$rule} );

      print STDERR "$rule\n" if ( $debug == 1 );

      my @entries = ( $string =~ m/$REGEXPs{$rule}/ );
      if ( $#entries > -1 and $level eq 'NA' ) {
        parse_by_rule( \@entries, $RULES{$rule}, $tmphash );

        ( my $newauthors, my $notparsed ) = _split_authors( $tmphash->{any}, $debug );

        if ($newauthors) {
          if ( $notparsed =~ m/^(\s*[\.,;]?\s*\(?[Ee]ds?\.?\s*\)?:?)(.*)/ ) {
            $tmphash->{editors}   = $newauthors;
            $tmphash->{booktitle} = $2;
          } else {
            $tmphash->{authors}   = $newauthors;
            $tmphash->{au_flag}   = 1;
            $tmphash->{booktitle} = $notparsed;
          }
        }

	next if ( _quality_check($tmphash, $debug, 0) == 1 );

        $level = $rule;
        my $pub = fill_publication( $tmphash );
        return ( $pub, $level );

      }
    }

    #  INCOLLECTION

    foreach my $rule ( @{ $self->_RULES_INCOLLECTION() } ) {
      next if ( !$REGEXPs{$rule} );

      print STDERR "$rule\n" if ( $debug == 1 );

      my @entries = ( $string =~ m/$REGEXPs{$rule}/ );
      if ( $#entries > -1 and $level eq 'NA' ) {
        parse_by_rule( \@entries, $RULES{$rule}, $tmphash );

        ( my $newauthors, my $notparsed ) = _split_authors( $tmphash->{any}, $debug );

        if ($newauthors) {
          $tmphash->{authors} = $newauthors;
          $tmphash->{au_flag} = 1;
          $tmphash->{title}   = $notparsed;
        }

        if ( $tmphash->{editors} ne '' ) {
          ( my $neweditors, my $notparsed_editors ) = _split_authors( $tmphash->{editors}, $debug );
          $tmphash->{editors} = $neweditors;
        }

	next if ( _quality_check($tmphash, $debug, 0) == 1 );

        $tmphash->{pubtype} = 'INCOLLECTION';

        $level = $rule;
        my $pub = fill_publication( $tmphash );
        return ( $pub, $level );

      }
    }
  }

  # process proceedings here
  foreach my $rule ( @{ $self->_RULES_INPROCEEDINGS() } ) {

    print STDERR "$rule\n" if ( $debug == 1 );

    my @entries = ( $string =~ m/$REGEXPs{$rule}/ );
    if ( $#entries > -1 and $level eq 'NA' ) {
      parse_by_rule( \@entries, $RULES{$rule}, $tmphash );

      ( my $newauthors, my $notparsed ) = _split_authors( $tmphash->{any}, $debug );

      if ($newauthors) {
        $tmphash->{authors} = $newauthors;
        $tmphash->{au_flag} = 1;
        $tmphash->{title}   = $notparsed;
        $tmphash->{title} =~ s/\s*(I|i)n:?\s*$//;
      }

      if ( $tmphash->{booktitle} ne '' ) {
        $tmphash->{booktitle} =~ s/\s(pages|pp\.?)\s*$//;

	next if ( _quality_check($tmphash, $debug, 0) == 1 );
      }

      if ( $tmphash->{title} eq '' and $tmphash->{booktitle} ne '' ) {
        if ( $tmphash->{booktitle} =~ m/(.*)\s(Proceeding.*)/ and length($1) > 5 ) {
          $tmphash->{title}     = $1;
          $tmphash->{booktitle} = $2;
        }
      }

      if ( $tmphash->{title} ne '' and $tmphash->{booktitle} ne '' ) {
        if ( $tmphash->{title} =~ m/(.*)(\.\s*[Ii]n:?\s)?(Proc\.?.*)$/ ) {
          $tmphash->{title}     = $1;
          $tmphash->{booktitle} = $3." ".$tmphash->{booktitle};
          $tmphash->{booktitle} =~ s/Proc\s/Proc\. /;
          $tmphash->{title}     =~ s/\s*[Ii]n:?\s*$//;
        }
      }

      if ( $tmphash->{editors} ne '' ) {
        ( my $neweditors, my $notparsed_editors ) = _split_authors( $tmphash->{editors}, 0 );
        $tmphash->{editors} = $neweditors;
      }

      $tmphash->{pubtype} = 'INPROCEEDINGS';

      $level = $rule;
      my $pub = fill_publication( $tmphash );
      return ( $pub, $level );

    }
  }

  foreach my $rule ( @{ $self->_RULES_INBOOK() } ) {
    next if ( !$REGEXPs{$rule} );

    print STDERR "$rule\n" if ( $debug == 1 );

    my @entries = ( $string =~ m/$REGEXPs{$rule}/ );
    if ( $#entries > -1 and $level eq 'NA' ) {
      parse_by_rule( \@entries, $RULES{$rule}, $tmphash );

      ( my $newauthors, my $notparsed ) = _split_authors( $tmphash->{any}, $debug );

      if ($newauthors) {
        if ( $notparsed =~ m/^(\s*[\.,;]?\s*\(?[Ee]ds?\.?\s*\)?:?)(.*)/ ) {
          $tmphash->{editors}   = $newauthors;
          $tmphash->{booktitle} = $2;
        } else {
          $tmphash->{authors}   = $newauthors;
          $tmphash->{au_flag}   = 1;
          $tmphash->{booktitle} = $notparsed;
        }
      }

      next if ( _quality_check($tmphash, $debug, 0) == 1 );

      $tmphash->{pubtype} = 'INBOOK';

      $level = $rule;
      my $pub = fill_publication( $tmphash );
      return ( $pub, $level );

    }
  }

  return ( undef, $level, undef );
}

# takes a single reference string and returns
# a Paperpile Publication object

sub parse_JournalArticle {
  my $self          = shift;
  my $string        = $_[0];
  my $explicit_rule = ( $_[1] ) ? $_[1] : '';
  my $debug         = ( $_[2] ) ? $_[2] : 0;

  # Let's see if we can do an immediate retrun
  my $doexit = 0;
  $doexit = 1 if ( $string =~ m/Proceedings\sof(?!\sthe\sNational\sAcademy\sof\sSciences)/ );
  $doexit = 1 if ( $string =~ m/\(eds\)/ );
  $doexit = 1 if ( $string =~ m/Proc\.\s(?!Natl?\.?\s)/ );
  $doexit = 1 if ( $string =~ m/Technical\sReport/i );
  $doexit = 0 if ( $string =~ m/(Soc\.|Society)/ );
  return ( undef, 'NA', undef ) if ( $doexit == 1 );
  print STDERR "Passed Proceedings filtering step.\n" if ( $debug == 1 );

  # initialize some stuff
  my $tmphash  = _build_tmphash('ARTICLE');
  my $level    = 'NA';
  my %REGEXPs  = %{ $self->_REGEXPS() };
  my %PATTERNS = %{ $self->_PATTERNS() };
  my %RULES    = %{ $self->_RULES() };


  if ( $string =~ m/$REGEXPs{ARTICLE_NOTITLE}/ ) {
    my $authors       = $1;
    my $journal       = $2;
    my $volume        = $3;
    my $issue         = $4;
    my $year          = $5;
    my @words_journal = split( /\s+/, $journal );

    # if the putative author string can be fully parsed
    # we believe that there is no title
    ( my $newauthors, my $notparsed ) = _split_authors( $authors, $debug );
    if ( $newauthors and $notparsed eq '' and $#words_journal < 10 ) {
      $tmphash->{authors} = $newauthors;
      $tmphash->{au_flag} = 1;
      $tmphash->{year}    = $year;
      $tmphash->{volume}  = $volume;
      $tmphash->{issue}   = $issue;
      $tmphash->{journal} = $journal;
      my $pub = fill_publication($tmphash);
      return ( $pub, 0, $RULES{$level} );
    }

  }
  print STDERR "Passed Strategy 0.\n" if ( $debug == 1 );

  foreach my $rule ( @{ $self->_RULES_ARTICLE() } ) {
    next if ( !$REGEXPs{$rule} );

    if ( $explicit_rule ne '' ) {
      next if ( $rule ne $explicit_rule );
    }

    my @entries = ( $string =~ m/$REGEXPs{$rule}/g );
    print STDERR "RULE:$rule\n" if ( $debug == 1 );
    print STDERR join( "|", @entries ), "\n" if ( $debug == 1 and $#entries > -1 );

    if ( $#entries > -1 and $level eq 'NA' ) {
      parse_by_rule( \@entries, $RULES{$rule}, $tmphash );

      # if there is already something in the author field
      if ( $tmphash->{authors} ne '' ) {
        ( my $newauthors, my $notparsed ) = _split_authors( $tmphash->{authors}, $debug );
        if ($newauthors) {
          $tmphash->{authors} = $newauthors;
          $tmphash->{au_flag} = 1;

          parse_title_journal( $tmphash->{any}, $tmphash, $debug );
        }
      } else {
        ( my $newauthors, my $notparsed ) = _split_authors( $tmphash->{any}, $debug );

        if ($newauthors) {
          $tmphash->{authors} = $newauthors;
          $tmphash->{au_flag} = 1;

          parse_title_journal( $notparsed, $tmphash, $debug );
        }
      }

      next if ( _quality_check( $tmphash, $debug, 1 ) == 1 );
      print STDERR "\t _quality_check passed.\n" if ( $debug == 1 );

      $level = $rule;
      my $pub = fill_publication($tmphash);
      return ( $pub, $level );
    }
  }

  my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );
  return ( $pub, $level );
}

# automically assigns the pattern to the correct field
sub parse_by_rule {
  my $entries = $_[0];
  my $rule    = $_[1];
  my $tmphash = $_[2];

  my @temp = split( /(_\S+_)/, $rule );

  my $count = 0;
  foreach my $i ( 0 .. $#temp ) {
    next if ( $temp[$i] !~ m/^_/ );

    #print STDERR "$i :: $temp[$i] -->  $entries->[$count]\n";

    if ( $temp[$i] =~ m/_AN._/ ) {
      $tmphash->{any} .= " $entries->[$count]";
      $count++;
    }
    if ( $temp[$i] =~ m/_JO_/ ) {
      $tmphash->{journal} = $entries->[$count];
      $count += 3;
    }
    if ( $temp[$i] =~ m/_VO_/ ) {
      $tmphash->{volume} = $entries->[$count];
      $count++;
    }
    if ( $temp[$i] =~ m/_IS_/ ) {
      $tmphash->{issue} = $entries->[$count];
      $count++;
    }
    if ( $temp[$i] =~ m/_PA_/ ) {
      $tmphash->{pages} = $entries->[$count];
      $count++;
    }
    if ( $temp[$i] =~ m/_Y\d_/ ) {
      $tmphash->{year} = $entries->[$count];
      $count++;
    }
    if ( $temp[$i] =~ m/_MO_/ ) {
      $tmphash->{month} = $entries->[$count];
      $count++;
    }

    if ( $temp[$i] =~ m/_AD_/ ) {
      $tmphash->{address} = $entries->[$count];
      $count += 3;
    }

    if ( $temp[$i] =~ m/_PU_/ ) {
      $tmphash->{publisher} = $entries->[$count];
      $count++;
    }
    if ( $temp[$i] =~ m/_EE_/ ) {
      $tmphash->{editors} = $entries->[$count];
      $count++;
    }
    if ( $temp[$i] =~ m/_AU_/ ) {
      $tmphash->{authors} = $entries->[$count];
      $count++;
    }
    if ( $temp[$i] =~ m/_AU1_/ ) {
      $tmphash->{authors} = $entries->[$count];
      $count++;
    }
    if ( $temp[$i] =~ m/_BT_/ ) {
      $tmphash->{booktitle} = $entries->[$count];
      $count++;
    }
    if ( $temp[$i] =~ m/_PR_/ ) {
      $tmphash->{booktitle} = $entries->[$count];
      $tmphash->{booktitle} =~ s/^\s*(I|i)n:?\s//;
      $count += 3;
      next;
    }
    if ( $temp[$i] =~ m/_SR_/ ) {
      $tmphash->{series} = $entries->[$count];
      $tmphash->{series} =~ s/^[Ii]n:?\s*//;
      $count += 3;
    }
    if ( $temp[$i] =~ m/_SE_/ ) {
      $tmphash->{series} = $entries->[$count];
      $tmphash->{series} =~ s/^[Ii]n:?\s*//;
      $count++;
    }
    if ( $temp[$i] =~ m/_IP_/ ) {
      $tmphash->{note} = $entries->[$count];
      $tmphash->{note} =~ s/[\(\)]//g;
      $count++;
    }
  }
}

sub build_regexp {
  my $RULES    = $_[0];
  my $PATTERNS = $_[1];

  my $REGEXPs = {};

  for my $key ( keys %{$RULES} ) {
    my $tmp = $RULES->{$key};

    $tmp =~ s/^\s+//g;
    $tmp =~ s/\(/\\\(/g;
    $tmp =~ s/\)/\\\)/g;
    $tmp =~ s/\./\\./g;
    $tmp =~ s/\s+/\\s*/g;
    while ( my ( $pattern, $value ) = each( %{$PATTERNS} ) ) {
      $tmp =~ s/$pattern/$value/g;
    }

    $REGEXPs->{$key} = '^' . $tmp . '$';
  }

  return $REGEXPs;
}

# creates and fills the publication object
sub fill_publication {
  my %tmphash = %{ $_[0] };

  # final cleaning
  $tmphash{title}     =~ s/^\s+//g           if ( $tmphash{title}     ne '' );
  $tmphash{title}     =~ s/\s+/ /g           if ( $tmphash{title}     ne '' );
  $tmphash{title}     =~ s/^[",\.]\s*//g     if ( $tmphash{title}     ne '' );
  $tmphash{title}     =~ s/\s*[\.,"]*\s*$//g if ( $tmphash{title}     ne '' );
  $tmphash{title}     =~ s/\s*[\.,"]*\s*$//g if ( $tmphash{title}     ne '' );
  $tmphash{booktitle} =~ s/^\s+//g           if ( $tmphash{booktitle} ne '' );
  $tmphash{booktitle} =~ s/^[,\.]\s*//g      if ( $tmphash{booktitle} ne '' );
  $tmphash{booktitle} =~ s/(\.|,)\s*$//g     if ( $tmphash{booktitle} ne '' );
  $tmphash{year}      =~ s/[^\d]//g          if ( $tmphash{year}      ne '' );
  $tmphash{pages}     =~ s/\s//g             if ( $tmphash{pages}     ne '' );
  $tmphash{issue}     =~ s/no\.\s//g         if ( $tmphash{issue}     ne '' );

  # normalize authors
  if ( $tmphash{authors} ne '' and $tmphash{au_flag} == 0 ) {
    ( my $newauthors, my $notparsed ) = _split_authors( $tmphash{authors}, 0 );
    if ($newauthors) {
      $tmphash{authors} = $newauthors;
    } else {
      $tmphash{authors} = $notparsed;
    }
  }
  if ( $tmphash{journal} ) {
    if ( $tmphash{journal} ne '' ) {
      $tmphash{journal} =~ s/^\s+"?\s*//g;
      $tmphash{journal} =~ s/\s+$//g;
      $tmphash{journal} =~ s/\s*(\.|,)\s*$//;
    }
  } else {
    $tmphash{journal} = '';
  }

  my $pub = Paperpile::Library::Publication->new( pubtype => $tmphash{pubtype} );
  $pub->authors( $tmphash{authors} )     if ( $tmphash{authors}   ne '' );
  $pub->editors( $tmphash{editors} )     if ( $tmphash{editors}   ne '' );
  $pub->volume( $tmphash{volume} )       if ( $tmphash{volume}    ne '' );
  $pub->issue( $tmphash{issue} )         if ( $tmphash{issue}     ne '' );
  $pub->month( $tmphash{month} )         if ( $tmphash{month}     ne '' );
  $pub->year( $tmphash{year} )           if ( $tmphash{year}      ne '' );
  $pub->pages( $tmphash{pages} )         if ( $tmphash{pages}     ne '' );
  $pub->title( $tmphash{title} )         if ( $tmphash{title}     ne '' );
  $pub->booktitle( $tmphash{booktitle} ) if ( $tmphash{booktitle} ne '' );
  $pub->journal( $tmphash{journal} )     if ( $tmphash{journal}   ne '' );
  $pub->publisher( $tmphash{publisher} ) if ( $tmphash{publisher} ne '' );
  $pub->address( $tmphash{address} )     if ( $tmphash{address}   ne '' );
  $pub->series( $tmphash{series} )       if ( $tmphash{series}    ne '' );
  $pub->note( $tmphash{note} )           if ( $tmphash{note}      ne '' );

  return $pub;
}

sub parse_title_journal {
  my $notparsed = $_[0];
  my $tmphash   = $_[1];
  my $debug     = ( $_[2] ) ? $_[2] : 0;
  my $success   = 0;

  # remove leading space chars
  $notparsed =~ s/^\s*//;

  print STDERR "NOTPARSED:$notparsed|\n" if ( $debug == 1 );

  # let's see how many words we have at the end
  my @wordstmp = split( /\s+/, $notparsed );
  my $dotstmp = 0;
  foreach my $word (@wordstmp) {
    $dotstmp++ if ( $word =~ m/^[^a-z].*\.$/ );
  }

  if ( $dotstmp >= $#wordstmp ) {
    $tmphash->{title}   = '';
    $tmphash->{journal} = $notparsed;
    $tmphash->{jr_flag} = 1;
    $success            = 1;
  }

  # let's see if it is a trivial split
  if ( $notparsed =~ m/(.*)(Journal\sof\s.*)/ ) {
    $tmphash->{title}   = $1;
    $tmphash->{journal} = $2;
    $success            = 1;
  }

  # some cleaning
  $notparsed =~ s/,\s*$//;
  $notparsed =~ s/\.\s*$//;

  # let's see if title and journal are separated by a comma
  my $count_period = ( $notparsed =~ tr/\.// );
  $count_period-- if ( $notparsed =~ m/^[^\.]+\.$/ );
  my $count_comma = ( $notparsed =~ tr/,// );
  my $count_qmark = ( $notparsed =~ tr/\?// );

  print STDERR "PERIODS:$count_period | COMMAS:$count_comma | QMARK:$count_qmark\n"
    if ( $debug == 1 );

  # we just see a period and no commas
  # a split by period separates the two parts
  if ( $count_period == 1 and $count_comma == 0 and $count_qmark == 0 and $success == 0 ) {
    print STDERR "1 period, 0 comma\n" if ( $debug == 1 );
    my @tmp = split( /\./, $notparsed );
    $tmphash->{title}   = "$tmp[0].";
    $tmphash->{journal} = $tmp[1];
    $success            = 1;
  }

  # we see no period but several commas
  # there is no easy way how to deal with this
  # we just assume the last part belongs to the
  # journal
  if ( $count_period == 0 and $count_comma >= 1 and $success == 0 ) {
    print STDERR "0 period, at least 1 comma\n" if ( $debug == 1 );
    my @tmp = split( /,/, $notparsed );

    $tmphash->{journal} = pop @tmp;
    $tmphash->{title}   = join( ',', @tmp );
    $success            = 1;
  }

  # if there is no period and no comma, but a question mark
  if (  $count_period == 0
    and $count_comma == 0
    and $success == 0
    and $notparsed =~ m/([^\?]+\?)(.*)/ ) {
    print STDERR "0 period, 0 comma\n" if ( $debug == 1 );
    $tmphash->{title}   = $1;
    $tmphash->{journal} = $2;
    $success            = 1;
  }

  # if there are several periods and no comma, but a question mark
  if (  $count_period > 0
    and $success == 0
    and $notparsed =~ m/([^\?\.]+\?)(.*)/ ) {
    print STDERR "Split by question mark.\n" if ( $debug == 1 );
    $tmphash->{title}   = $1;
    $tmphash->{journal} = $2;
    $success            = 1;
  }

  # if there is no period and no comma, and no question mark
  if ( $count_period == 0 and $count_comma == 0 and $success == 0 ) {
    print STDERR "0 period, 0 comma\n" if ( $debug == 1 );
    my @tmp = split( /\s+/, $notparsed );
    my @part2 = ();
    while ( my $word = pop(@tmp) ) {

      # when we see the first lower case word we stop
      if ( $word =~ m/^[a-z]/ ) {
        $tmphash->{title} = join( " ", @tmp );
        last;
      } else {
        unshift( @part2, $word );
      }
    }
    $tmphash->{journal} = join( " ", @part2 );
    $success = 1;
  }

  # a try to split by the last comma in the string
  # if after the comma there is no lowercase word
  if ( $notparsed =~ m/(.*),(?!\s+[a-z]+)([^,]+)$/ and $success == 0 ) {
    print STDERR "try to split by last comma.\n" if ( $debug == 1 );
    my $part1 = $1;
    my $part2 = $2;
    $part2 =~ s/^\s*//;
    print STDERR "$part1|$part2\n" if ( $debug == 1 );

    # let's see how many words we have at the end
    my @words = split( /\s+/, $part2 );
    my $dots = 0;
    foreach my $word (@words) {
      $dots++ if ( $word =~ m/\.$/ );
    }

    # common start words for journal names
    my $common_start = 0;
    $common_start = 1 if ( $part2 =~ m/^\s*J\./ );

    # if more than 33% have a dot at the end or we have
    # less than 4 words we belive that this is the journal name
    if ( $dots / ( $#words + 1 ) > 0.33 or ( $#words + 1 ) < 4 or $common_start == 1 ) {
      $tmphash->{title}   = $part1;
      $tmphash->{journal} = $part2;
      $success            = 1;
    }

  }

  if ( $success == 0 ) {
    print STDERR "NO SUCCESS TIL NOW.\n" if ( $debug == 1 );
    my $part1 = '';
    ( my $part2 = $notparsed ) =~ s/\s*(\.|,)$//;
    my $continue_parsing = 1;

    while ( $continue_parsing == 1 ) {

      last if ( $part2 !~ m/(\.|\?)/ );

      if ( $part2 =~ m/([^\.\?]+)(\.|\?)(.*)/ ) {
        $continue_parsing = 0;
        my $tmp1 = $1 . $2;
        my $tmp2 = $3;

        # We do not want to stop at positions like
        # C. elegans
        if ( $tmp1 =~ m/\s[A-Z]\.$/ and $tmp2 =~ m/^\s[a-z]/ ) {
          $part1 .= $tmp1;
          $part2            = $tmp2;
          $continue_parsing = 1;
          next;
        }

        # We do not want to stop at floating point numbers
        if ( $tmp1 =~ m/\d\.$/ and $tmp2 =~ m/^\s?\d/ ) {
          $part1 .= $tmp1;
          $part2            = $tmp2;
          $continue_parsing = 1;
          next;
        }

        # A quick check if the title may consist of two
        # sentences
        my $count1 = ( $tmp1 =~ tr/ // );
        my $count2 = ( $tmp2 =~ tr/ // );
        if ( $count2 > 3 ) {
          if ( $tmp2 =~ m/([^(\.|\?)]+)(\.|\?)/ ) {
            my $matched = $1;
            my $rest    = $';
            $matched =~ s/^\s+//;
            my @tmp = split( /\s+/, $matched );
            my $lower_case_words_matched = 0;
            foreach my $word (@tmp) {
              $lower_case_words_matched++ if ( $word =~ m/^[a-z]/ );
            }
            $lower_case_words_matched =
              ( ( $#tmp + 1 ) > 0 ) ? $lower_case_words_matched / ( $#tmp + 1 ) : 0;
            $rest =~ s/^\s+//;
            @tmp = split( /\s+/, $rest );
            my $lower_case_words_rest = 0;
            foreach my $word (@tmp) {
              $lower_case_words_rest++ if ( $word =~ m/^[a-z]/ );
            }
            $lower_case_words_rest =
              ( ( $#tmp + 1 ) > 0 ) ? $lower_case_words_rest / ( $#tmp + 1 ) : 0;
            if ( $lower_case_words_matched > $lower_case_words_rest ) {
              $part1 .= $tmp1;
              $part2            = $tmp2;
              $continue_parsing = 1;
              next;
            }
          }
        }

        $part1 .= $tmp1;
        $part2 = $tmp2;

      }
    }
    $tmphash->{title}   = $part1;
    $tmphash->{journal} = $part2;

    print STDERR "$tmphash->{title}|$tmphash->{journal}\n" if ( $debug == 1 );

    # some post processing control
    if ( $tmphash->{journal} =~ m/(.*\s[a-z]+\.)\s(.*)/ ) {
      my $one              = $1;
      my $two              = $2;
      my @words_one        = split( /\s+/, $one );
      my $lower_case_count = 0;
      foreach my $word (@words_one) {
        $lower_case_count++ if ( $word eq lc($word) );
      }
      my $append_flag = 1;
      $append_flag = 0
        if ( $tmphash->{title} =~ m/\.$/ and $lower_case_count <= 1 and $#words_one < 2 );
      if ( $append_flag == 1 ) {
        $tmphash->{title} .= " $one";
        $tmphash->{journal} = $two;
      }
    }
    print STDERR "$tmphash->{title}|$tmphash->{journal}\n" if ( $debug == 1 );

    if ( $tmphash->{title} =~ m/^[A-Z][a-z]{1,4}\.$/ ) {
      $tmphash->{journal} = $tmphash->{title} . $tmphash->{journal};
      $tmphash->{title}   = '';
    }

  }
}

# removes pdftoxml strange UTF-8 chars, and other stuff
sub clean {
  my $string = $_[0];

  $string = decode_utf8($string);    # maybe not needed?????????

  # remove citation numbers at the beginning of the string
  $string =~ s/^(\[|\(|.?)\d+(\]|\)|\.)//;
  $string =~ s/^\[?.{3,10}\]\s//;
  $string =~ s/^\[[^\d]+,\s\d{4}\]\s//;
  $string =~ s/^\d+\s+//g;

  # some correction in commas, points, ...
  while ( $string =~ m/(.*[A-Z][a-z]+)\s*\.\s*,(.*)/ ) {
    $string = "$1,$2";
  }
  while ( $string =~ m/(.*[A-Z]\.)([a-z].*)/ ) {
    $string = "$1 $2";
  }

  # general white space cleaning
  $string =~ s/(.*\d)(\(.*)/$1 $2/g;
  $string =~ s/^\s+//g;
  $string =~ s/\s+$//g;
  $string =~ s/\s+/ /g;
  $string =~ s/,\s*,/,/g;

  # remove strange characters that come from pdftoxml
  $string =~ s/\x{201C}/"/g;
  $string =~ s/\x{201D}/"/g;
  $string =~ s/\x{2014}/-/g;
  $string =~ s/\x{2212}/-/g;
  $string =~ s/\x{FB00}/ff/g;
  $string =~ s/\x{AE}/fi/g;
  $string =~ s/\x{FB01}/fi/g;
  $string =~ s/\x{FB02}/fl/g;
  $string =~ s/\x{FB03}/ffi/g;

  # umlaute; we change it to the preceeding character

  # umlaut a
  while ( $string =~ m/(.*)a\s\x{A8}\s?(\S.*)/ ) {
    $string = "$1\x{E4}$2";
  }

  # umlaut o
  while ( $string =~ m/(.*)o\s\x{A8}\s?(\S.*)/ ) {
    $string = "$1\x{F6}$2";
  }
  while ( $string =~ m/(.*)\s?\x{A8}\so(\S.*)/ ) {
    $string = "$1\x{F6}$2";
  }
  while ( $string =~ m/(.*)O\s\x{A8}\s?(\S.*)/ ) {
    $string = "$1\x{D6}$2";
  }
  while ( $string =~ m/(.*)\s?\x{A8}\sO(.*)/ ) {
    $string = "$1\x{D6}$2";
  }

  # umlaut u
  while ( $string =~ m/(.*)u\s\x{A8}\s?(\S.*)/ ) {
    $string = "$1\x{FC}$2";
  }
  while ( $string =~ m/(.*)\s?\x{A8}\su(\S.*)/ ) {
    $string = "$1\x{FC}$2";
  }

  # e
  while ( $string =~ m/(.*)e\s\x{B4}\s?(\S.*)/ ) {
    $string = "$1\x{E9}$2";
  }

  # a
  while ( $string =~ m/(.*)a\s\x{B4}\s?(\S.*)/ ) {
    $string = "$1\x{E1}$2";
  }

  # o
  while ( $string =~ m/(.*)o\s\x{B4}\s?(\S.*)/ ) {
    $string = "$1\x{F3}$2";
  }

  # n
  while ( $string =~ m/(.*)n\s\x{2DC}\s?(\S.*)/ ) {
    $string = "$1\x{F1}$2";
  }

  # S
  while ( $string =~ m/(.*)\x{2C7}\sS(\S.*)/ ) {
    $string = "$1\x{160}$2";
  }

  # the rest will be eliminated
  while ( $string =~ m/(.*[a-zA-Z])\s[^[:ascii:]]\s(\S.*)/ ) {
    $string = "$1$2";
  }
  while ( $string =~ m/(.*[a-zA-Z])[^[:ascii:]\x{2019}]\s([a-z].*)/ ) {
    $string = "$1$2";
  }

  # several issues with hyphens & co.
  $string =~ s/(.*\d+\s*)--(\s*\d+.*)/$1-$2/g;
  $string =~ s/(.*\d+\s*)\^(\s*\d+.*)/$1-$2/g;
  while ( $string =~ m/(.*[a-z])-\s+([a-z].*)/ ) {
    $string = $1 . $2;
  }
  $string = '' if ( $string =~ m/^\d+$/ );
  my $count_plus_signs = ( $string =~ tr/\+// );

  if ( $count_plus_signs > 1 ) {
    $string =~ s/\+/\./g;
  }
  $string =~ s/(.*\d+)\{(\d+.*)/$1-$2/;

  $string =~ s/(.*Acad\.?\s+Sci\.?\s*),(\s*U\.?S\.?A.*)/$1$2/;

  # We cannot parse strings that have all characters of lastnames
  # as uppercase letters
  # We do a quick check here and convert them
  if ( $string =~ m/^[A-Z]{3,},/ ) {
    my $loop_flag     = 1;
    my $string_backup = $string;
    while ( $string =~ m/(.*)(\b[A-Z]{2,}\b)(.*)/ and $loop_flag == 1 ) {
      my $tmp1 = $1;
      my $tmp2 = lc($2);
      my $tmp3 = $3;

      $string        = $1 . "\u$tmp2" . $3;
      $loop_flag     = 0 if ( $string eq $string_backup );
      $string_backup = $string;
    }
  }

  #$string = encode_utf8($string);

  return $string;
}

# splits a string into authors and returns a
# normalized string and the part that could
# not be parsed

sub _split_authors {
  my $line       = $_[0];
  my $debug      = ( $_[1] ) ? $_[1] : 0;
  my $backup     = $line;
  my $not_parsed = '';
  my @authors    = ();

  # set of regular expressions used

  my $r       = {};
  my $umlaute = '\x{C4}\x{C5}\x{D6}}\x{DC}';
  $r->{one}   = '[A-Z' . $umlaute . '](?![a-z])\.?';
  $r->{two}   = $r->{one} . '-?\s?' . $r->{one} . '(?!\s*\.\s*[A-Z]{2,})';
  $r->{three} = $r->{one} . '-?\s?' . $r->{one} . '-?\s?' . $r->{one} . '(?!\s*\.\s*[A-Z]{2,})';
  $r->{jr}    = ',?\s?Jr\.?|\s3rd\.?|\s2nd\.?|,?\s?III\.?';
  $r->{first_abbr1} =
      $r->{three} . '('
    . $r->{jr} . ')?|'
    . $r->{two} . '('
    . $r->{jr} . ')?|'
    . $r->{one} . '('
    . $r->{jr} . ')?';
  $r->{first_abbr2} = $r->{three} . '|' . $r->{two} . '|' . $r->{one};
  $r->{sep}         = ',?\sand\s|\s?,\s|,?\s&\s|';
  $r->{lastname}    = '[^(,|\s|\.|:)]{2,}(\s[^(,|\s|\.|:)]{2,})?(\s[^(,|\s|\.|:)]{2,})?';

  my $common_prefixes = {
    'da'     => 1,
    'de'     => 1,
    'del'    => 1,
    'della'  => 1,
    'di'     => 1,
    'du'     => 1,
    'la'     => 1,
    'pietro' => 1,
    'st.'    => 1,
    'st'     => 1,
    'ter'    => 1,
    'van'    => 1,
    'vanden' => 1,
    'vere'   => 1,
    'von'    => 1
  };

  # pre-processing of input; introduces spaces
  # where necessary and removes some common
  # parsing errors
  $line =~ s/,\s*,/, /g;
  $line =~ s/,+\s+/, /g;
  $line =~ s/,/, /g;
  $line =~ s/\.+/. /g;
  $line =~ s/\s+,/,/g;
  $line =~ s/\s+/ /g;
  $line =~ s/\.\s-/.-/g;
  $line =~ s/\s+$//;
  $line =~ s/^\s+//;
  while ( $line =~ m/(.*\sand)([A-Z].*)/ ) {
    $line = "$1 $2";
  }
  while ( $line =~ m/(.*\set)(al\..*)/ ) {
    $line = "$1 $2";
  }
  while ( $line =~ m/(.*[A-Z][a-z]+)\.\s([A-Z]\.\s.*)/ ) {
    $line = "$1 $2";
  }

  print STDERR "CLEANED: $line\n" if ( $debug == 1 );

  # Here we decide wihch strategy to take for parsing
  my $flag = 0;
  $flag = 1 if ( $line =~ m/^($r->{lastname}),\s?($r->{first_abbr1}).*/ );
  $flag = 2 if ( $line =~ m/^($r->{first_abbr2})\s($r->{lastname})($r->{sep}).*/ );
  $flag = 2 if ( $line =~ m/^($r->{first_abbr2})\s($r->{lastname})\.\s[A-Z].*/ );
  $flag = 3 if ( $line =~ m/^($r->{lastname})\s?($r->{first_abbr1}),.*/ );
  $flag = 3 if ( $line =~ m/^($r->{lastname})\s?($r->{first_abbr1})\s(and|&)\s/ );
  $flag = 3 if ( $line =~ m/^($r->{lastname})\s?($r->{first_abbr1})\.?$/ );
  $flag = 3 if ( $line =~ m/^($r->{lastname})\s?($r->{first_abbr1}):/ );
  $flag = 3 if ( $line =~ m/^($r->{lastname})\s?($r->{first_abbr1})\set\sal/ );
  $flag = 2 if ( $line =~ m/^($r->{first_abbr2})\s([^(,|\s)]+)\.\s[A-Z].*/ );
  $flag = 3 if ( $line =~ m/^($r->{lastname})\s($r->{first_abbr1})/ and $flag == 0 );
  $flag = 2 if ( $line =~ m/^($r->{first_abbr2})\s($r->{lastname})\set\.?\sal/ );

  # Authors are of the form: Lastname, F. F., Lastname, F. F.
  if ( $flag == 1 ) {
    ( my $tmpref, my $tmp_not_parsed ) = _parse_case_1( $line, $r, $debug, $common_prefixes );
    foreach my $entry ( @{$tmpref} ) {
      push @authors, $entry;
    }
    $not_parsed .= " $tmp_not_parsed";
  }

  # Authors are of the form: F. F. Lastname, F. F. Lastname
  if ( $flag == 2 ) {
    ( my $tmpref, my $tmp_not_parsed ) = _parse_case_2( $line, $r, $debug, $common_prefixes );
    foreach my $entry ( @{$tmpref} ) {
      push @authors, $entry;
    }
    $not_parsed .= " $tmp_not_parsed";
  }

  # Authors are of the form: Lastname F. F., Lastname F. F.
  if ( $flag == 3 ) {
    ( my $tmpref, my $tmp_not_parsed ) = _parse_case_3( $line, $r, $debug, $common_prefixes );
    foreach my $entry ( @{$tmpref} ) {
      push @authors, $entry;
    }
    $not_parsed .= " $tmp_not_parsed";
  }

  # if the authors array is not empty, we do a join and
  # some post-processing; finally return
  if ( $#authors > -1 ) {
    my $return_value = join( ' and ', @authors );
    $return_value =~ s/\./. /g;
    $return_value =~ s/\s+$//g;
    $return_value =~ s/^\s+//g;
    $return_value =~ s/\s+/ /g;
    $return_value =~ s/\s+-\s+/-/g;
    $return_value =~ s/\.\s-/.-/g;

    $not_parsed =~ s/\s+/ /g;
    $not_parsed =~ s/^\s*\.\s*//;
    $not_parsed =~ s/^\s*//;
    $not_parsed = '' if ( $not_parsed eq ' ' );

    # some postprocessing to see if we got the split between
    # authors and title correct
    if ( $not_parsed ne '' ) {
      if ( $return_value =~ m/(?<!,)\.?\sA$/ and $not_parsed !~ m/^\s*(An?|The)\s/ ) {
        my $tmpvar = "A $not_parsed";
        if ( $backup =~ m/\Q$tmpvar\E/ ) {
          $return_value =~ s/\sA$//;
          $not_parsed = "A $not_parsed";
        }
      } elsif ( $return_value =~ m/.*[A-Z]{2}\sA$/ and $not_parsed !~ m/^\s*An?\s/ ) {
        $return_value =~ s/\sA$//;
        $not_parsed = "A $not_parsed";
      } elsif ( $return_value =~ m/.*[A-Z]\sA$/ and $not_parsed =~ m/^\s*[a-z]/ ) {
        $return_value =~ s/\sA$//;
        $not_parsed = "A $not_parsed";
      }

      my $last_letter = substr( $return_value, length($return_value) - 1, 1 );
      my $tmpvar = $last_letter . $not_parsed;
      if ( $backup =~ m/\Q$tmpvar\E/ ) {
        $return_value =~ s/\s$last_letter$//;
        $not_parsed = $tmpvar;
      }

      $last_letter = substr( $return_value, length($return_value) - 1, 1 );
      $tmpvar = $last_letter . $not_parsed;
      if ( $backup =~ m/\Q$tmpvar\E/ ) {
        $return_value =~ s/\s$last_letter$//;
        $not_parsed = $tmpvar;
      }
    }

    $not_parsed =~ s/\s+/ /g;
    return ( $return_value, $not_parsed );
  }

  # if we are here, we were not able to parse
  # a single author; we return the unprocessed
  # input string
  $not_parsed = $backup;
  return ( undef, $not_parsed );
}

# parses Authors of the form: Lastname, F. F., Lastname, F. F.
sub _parse_case_1 {
  my $line       = $_[0];
  my $r          = $_[1];
  my $debug      = $_[2];
  my $common_prefixes = $_[3];
  my @authors    = ();
  my $not_parsed = '';
  my $goto_flag  = '';

START:
  my $current = $line;
  while ( $line =~ m/\G($r->{sep})?(($r->{lastname}),\s?($r->{first_abbr1}))/g ) {
    $current = $';
    print STDERR "CASE1 - CURRENT: $current\n" if ( $debug == 1 );
    my $tmp = $2;

    # We might parsed a jr-tag
    my $jr = undef;
    if ( $tmp =~ m/(.*)(Jr\.?)$/ ) {
      $tmp = $1;
      $jr  = $2;
    }
    my @parts = split( /,\s*/, $tmp );
    $jr = $parts[2] if ( $parts[2] );

    push @authors, _build_author( $parts[1], $parts[0], undef, $jr );
  }
  print STDERR "CASE1 -    LAST: $current\n" if ( $debug == 1 );

  # the not parseable part start with el al.
  # create a collective author object
  if ( $current =~ m/^(,?\s*(?<![a-z])et\sal\.?)/ ) {
    my $author = Paperpile::Library::Author->new();
    $author->collective('et al.');
    push @authors, $author->bibtex();
    $not_parsed = $';

    # let's see if there is still an author left
    # if so let's jump to the while loop again
    # and start the regular parsing process again
    if ( $not_parsed =~ m/(\s*,\s*&\s*)($r->{lastname},.*)/ ) {
      if ( $current ne $goto_flag ) {
        $goto_flag = $2;
        $line      = $2;
        goto START;
      }
    }
  }

  # there is a author, where it seems that the separating
  # comma is missing. Let's parse it differently and
  # then jump to the whil loop again
  elsif ( $current =~ m/^($r->{sep})($r->{lastname})\s($r->{first_abbr1})(\s*,\s*.*)/ and $9 ) {
    print STDERR "CASE1 -    LAST: COMMA MISSING?\n" if ( $debug == 1 );
    push @authors, _build_author( $5, $2, undef, undef );
    $line = $9;
    print STDERR "CASE1 -    LINE: $line\n" if ( $debug == 1 );

    # quick check that we do not get stuck with the goto
    if ( $current ne $goto_flag ) {
      $goto_flag = $current;
      goto START;
    }
    $not_parsed = $9;
  }

  # there is a author, where it seems that the separating
  # comma is missing. Let's parse it differently.
  elsif ( $current =~ m/^($r->{sep})($r->{lastname})\s($r->{first_abbr1})\.(.*)/ and $9 ) {
    push @authors, _build_author( $5, $2, undef, undef );
    $not_parsed = $9;
  }
  # there is a author, where it seems that the separating
  # comma is missing. Let's parse it differently.
  elsif ( $current =~ m/^($r->{sep})($r->{lastname})\s($r->{first_abbr1})$/ ) {
    push @authors, _build_author( $5, $2, undef, undef );
    $not_parsed = '';
  }

  # it seems there is an author of the form F. F. Lastname
  # Let's parse it with _parse_case_2 and add the author
  # objects to those already parsed
  elsif ( $current =~ m/^($r->{sep})?($r->{first_abbr2})\s($r->{lastname})($r->{sep})/ and
	  $3 !~ m/\s?of\s/
    and $#authors == 0 ) {
    ( my $tmpref, my $tmp_not_parsed ) = _parse_case_2( $current, $r, $debug, $common_prefixes );
    foreach my $entry ( @{$tmpref} ) {
      push @authors, $entry;
    }
    $not_parsed .= " $tmp_not_parsed";
  }

  # it seems there is an author of the form F. F. Lastname
  # Let's parse it with _parse_case_2 and add the author
  # objects to those already parsed
  elsif ( $current =~ m/^($r->{sep})?($r->{first_abbr2})\s([^(,|\s)]+)$/ and $#authors == 0 ) {
    ( my $tmpref, my $tmp_not_parsed ) = _parse_case_2( $current, $r, $debug, $common_prefixes );
    foreach my $entry ( @{$tmpref} ) {
      push @authors, $entry;
    }
    $not_parsed .= " $tmp_not_parsed";
  }

  # for some reason we see a parseable author, but it has not
  # worked so far, let's jump to the while loop again
  elsif ( $current =~ m/^\s*($r->{lastname}),\s?($r->{first_abbr1})/ ) {
    $line = $current;
    $line =~ s/^\s+//;

    # quick check that we do not get stuck with the goto
    if ( $current ne $goto_flag ) {
      $goto_flag = $current;
      goto START;
    }
  } else {
    $not_parsed = $current;
  }

  # some post-processing and return
  $not_parsed =~ s/^\s+//;
  $not_parsed =~ s/^\s*(:|\.|\,)\s+//;
  return ( \@authors, $not_parsed );
}

# parses Authors of the form: F. F. Lastname, F. F. Lastname
sub _parse_case_2 {
  my $line       = $_[0];
  my $r          = $_[1];
  my $debug      = $_[2];
  my $common_prefixes = $_[3];
  my @authors    = ();
  my $not_parsed = '';

  my $current = $line;
  print STDERR "CASE2 -   START: $current\n" if ( $debug == 1 );
  while ( $line =~ m/\G($r->{sep}|\s+)?($r->{first_abbr2})\s($r->{lastname})($r->{sep})?/g ) {

    $current = $';
    print STDERR "CASE2 - CURRENT: $current\n" if ( $debug == 1 );

    my $matched = $&;    # for backup reasons

    my $f          = $2;       # firstname
    my $l          = $3;       # lastname
    my $add_at_end = undef;    # flag to add collective author

    # Let's see if we parsed more than wanted
    if ( $l =~ m/\sand$/ ) {
      $l =~ s/\sand$//;
    }

    # we parsed too much, let's repair it
    if ( $l =~ m/(.*)(\sand\s.*)/ ) {
      $l    = $1;
      $line = "$2$current";
    }
    print STDERR "\t $l\n" if ( $debug == 1 );
    if ( $l =~ m/(.*)\set\sal\.?$/ ) {
      $l = $1;
      my $author = Paperpile::Library::Author->new();
      $author->collective('et al.');
      $add_at_end = $author->bibtex();
    }

    # Let's check if parsing of lastname was correct
    my @names = split( /\s+/, $l );
    my $count = 0;
    foreach my $name (@names) {
      $count++ if ( $name =~ m/^[a-z]/ );
      $count-- if ( defined $common_prefixes->{$name} );
    }

    # if we have more than two lower case words, let's stop
    # does not seem to be parsed corrctly; let's stop here
    if ( $count > 1 ) {
      $current = "$matched $current";
      last;
    }

    push @authors, _build_author( $f, $l, undef, undef );
    push @authors, $add_at_end if ($add_at_end);
  }
  print STDERR "CASE2 -    LAST: $current\n" if ( $debug == 1 );

  if ( $current =~ m/^(\s*\.\s*)(.*)/ ) {
    $current = $2;
  }
  print STDERR "CASE2 -    LAST: $current\n" if ( $debug == 1 );

  # the not parseable part start with el al.
  # create a collective author object
  if ( $current =~ m/^(\s*et\sal\.)/ ) {
    my $author = Paperpile::Library::Author->new();
    $author->collective('et al.');
    push @authors, $author->bibtex();
    $not_parsed = $';
  }

  # a regular parsable case, but we missed it somehow
  # maybe because of the separator
  elsif ( $current =~ m/^(\s?and\s|\s)?($r->{first_abbr2})\s($r->{lastname})\./ ) {
    push @authors, _build_author( $2, $3, undef, undef );
    $not_parsed = $';
  }

  # a regular parsable case, but we missed it somehow
  # maybe because of the separator
  elsif ( $current =~ m/^($r->{first_abbr2})\s($r->{lastname})\./ ) {
    push @authors, _build_author( $1, $2, undef, undef );
    $not_parsed = $';
  }

  # We see a author of the form LASTNAME, F. F.
  elsif ( $current =~ m/^($r->{lastname}),\s($r->{first_abbr2})/ ) {

    # Let's check if parsing of lastname was correct
    my @names = split( /\s+/, $1 );
    my $count = 0;
    foreach my $name (@names) {
      $count++ if ( $name =~ m/^[a-z]/ );
      $count-- if ( defined $common_prefixes->{$name} );
    }

    if ( $count < 1 ) {
      ( my $tmpref, my $tmp_not_parsed ) = _parse_case_1( $current, $r, $debug, $common_prefixes );
      foreach my $entry ( @{$tmpref} ) {
	push @authors, $entry;
      }
      $not_parsed .= " $tmp_not_parsed";
    } else {
      $current =~ s/^\s?\.\s//;
      $not_parsed = $current;
    }
  } else {
    $current =~ s/^\s?\.\s//;
    $not_parsed = $current;
  }

  # some post-processing and return
  $not_parsed =~ s/^\s+//;
  $not_parsed =~ s/^\s*(:|\.|\,)\s+//;
  return ( \@authors, $not_parsed );
}

# parses Authors of the form: Lastname F. F., Lastname F. F.
sub _parse_case_3 {
  my $line       = $_[0];
  my $r          = $_[1];
  my $debug      = $_[2];
  my $common_prefixes = $_[3];
  my @authors    = ();
  my $not_parsed = '';

  my $current = $line;
  while ( $line =~ m/\G($r->{sep})?(($r->{lastname})\s($r->{first_abbr1}))($r->{sep})/g ) {
    $current = $';
    print STDERR "CASE3 - CURRENT: $current\n" if ( $debug == 1 );

    my ( $f, $l, $jrtag ) = _parsing_helper3( $2, $r );
    push @authors, _build_author( $f, $l, undef, $jrtag );
  }
  print STDERR "CASE3 -   LAST1: $current\n"       if ( $debug == 1 );
  print STDERR "CASE3 - NOTPARSED1: $not_parsed\n" if ( $debug == 1 );

  # for some reason (separator) we missed a parseable author
  if ( $current =~ m/^\s*,?\s*($r->{lastname}\s($r->{first_abbr1}))(\.|:)/g ) {
    $not_parsed = $';
    my ( $f, $l, $jrtag ) = _parsing_helper3( $1, $r );
    push @authors, _build_author( $f, $l, undef, $jrtag );
  } elsif ( $current =~ m/^\s*,?\s*($r->{lastname}\s($r->{first_abbr1}))\s*$/g ) {
    $not_parsed = $';
    my ( $f, $l, $jrtag ) = _parsing_helper3( $1, $r );
    push @authors, _build_author( $f, $l, undef, $jrtag );
  }

  # the not parseable part start with el al.
  # create a collective author object
  elsif ( $current =~ m/(\s*,?\s*(?<![a-z])et\sal\.?)/ ) {
    my $author = Paperpile::Library::Author->new();
    $author->collective('et al.');
    push @authors, $author->bibtex();
    $not_parsed = $';
  }

  # there is a switch in the style
  # F. F. LASTNAME
  elsif ( $current =~ m/^($r->{sep})?($r->{first_abbr2})\s($r->{lastname})($r->{sep}).*/ ) {
    ( my $tmpref, my $tmp_not_parsed ) = _parse_case_2( $current, $r, $debug, $common_prefixes );
    foreach my $entry ( @{$tmpref} ) {
      push @authors, $entry;
    }
    $not_parsed .= " $tmp_not_parsed";
  } elsif ( $current =~ m/^($r->{sep})?($r->{first_abbr2})\s($r->{lastname})\..*/ ) {
    ( my $tmpref, my $tmp_not_parsed ) = _parse_case_2( $current, $r, $debug, $common_prefixes );
    foreach my $entry ( @{$tmpref} ) {
      push @authors, $entry;
    }
    $not_parsed .= " $tmp_not_parsed";
  } else {
    $not_parsed = $current;
  }

  print STDERR "CASE3 - NOTPARSED2: $not_parsed\n" if ( $debug == 1 );

  # the not parseable part start with el al.
  # let's try it here once more
  # create a collective author object
  if ( $not_parsed =~ m/(\s*,?\s*(?<![a-z])et\sal\.?)/ ) {
    my $author = Paperpile::Library::Author->new();
    $author->collective('et al.');
    push @authors, $author->bibtex();
    $not_parsed = $';
  }

  print STDERR "CASE3 - NOTPARSED3: $not_parsed\n" if ( $debug == 1 );

  # some post-processing and return
  $not_parsed =~ s/^\s+//;
  $not_parsed =~ s/^\s*(:|\.|\,)\s+//;
  return ( \@authors, $not_parsed );
}

# helper sub; split a string into
# last name, jr tag, and initials
sub _parsing_helper3 {
  my $tmp = $_[0];
  my $r   = $_[1];

  $tmp =~ s/^\s+//;

  my @parts = split( /\s+/, $tmp );

  # Let's assume all words that
  # contain a lowercase letter
  # belong to the last name
  my @ltmp = ();
  my @ftmp = ();
  foreach my $word (@parts) {
    if ( $word =~ m/[a-z]/ ) {
      push @ltmp, $word;
    } else {
      push @ftmp, $word;
    }
  }

  my $l = join( ' ', @ltmp );
  my $f = join( ' ', @ftmp );

  my $jrtag = undef;
  if ( $f =~ m/($r->{jr})/ ) {
    $jrtag = $1;
    $f     = $` . ' ' . $';
    $f =~ s/\s+/ /g;
  }

  return ( $f, $l, $jrtag );
}

# helper sub to create normalized
# author strings
sub _build_author {
  my $first = $_[0];
  my $last  = $_[1];
  my $von   = $_[2];
  my $jr    = $_[3];

  if ( $last =~ m/(.*)\s([A-Z]\.)$/ ) {
    $first = "$2 $first";
    $last  = $1;
  }
  if ( $last =~ m/.*[a-z]\.\s*$/ ) {
    $last =~ s/\.\s*$//;
  }
  if ($jr) {
    $jr =~ s/^\s*//;
    $jr =~ s/\s*$//;
  }

  $first =~ s/\.//g;
  my @tmp = split( //, $first );
  $first = join( ' ', @tmp );

  my $author = Paperpile::Library::Author->new();
  $author->last($last)   if ($last);
  $author->first($first) if ($first);
  $author->von($von)     if ($von);
  $author->jr($jr)       if ($jr);

  return $author->bibtex();
}

sub _build_tmphash {
  my $pubtype = $_[0];

  my @fields = (
    'pubtype',     'title',    'booktitle', 'series',       'authors',   'editors',
    'affiliation', 'journal',  'chapter',   'volume',       'number',    'issue',
    'edition',     'pages',    'url',       'howpublished', 'publisher', 'organization',
    'school',      'address',  'year',      'month',        'day',       'eprint',
    'issn',        'isbn',     'pmid',      'lccn',         'arxivid',   'doi',
    'abstract',    'keywords', 'linkout',   'note',         'any',       'au_flag', 
    'tmp',         'jr_flag'
  );

  my %tmphash = ( );

  foreach my $entry ( @fields ) {
    $tmphash{$entry} = '';
  }
  $tmphash{'au_flag'} = 0;
  $tmphash{'jr_flag'} = 0;
  $tmphash{'pubtype'} = $pubtype if ( $pubtype );

  return \%tmphash;
}

sub _quality_check {
  my $tmphash = $_[0];
  my $debug   = ( $_[1] ) ? $_[1] : 0;
  my $flag    = ( $_[2] ) ? $_[2] : 0;

  # flag = 1: check journal name

  my $max_year = 2020;
  my $min_year = 1800;
  my $reset = 0;

  # check on journal
  if ( $flag == 1 ) {
    $reset = 1 if ($tmphash->{journal} eq ''  and $tmphash->{jr_flag} == 0 );
    $reset = 1 if ($tmphash->{journal} eq ' '  );
    $reset = 1 if ($tmphash->{'journal'} =~ m/\d{2,}/  );
    $reset = 1 if (length($tmphash->{'journal'}) <= 2  );
    $reset = 1 if ($tmphash->{'journal'} =~ m/^pp/  );

    my @words = split(/\s+/, $tmphash->{journal} );
    my $lower_case_count = 0;
    foreach my $word ( @words ) {
      next if ( $word eq 'the' );
      next if ( $word eq 'of' );
      next if ( $word eq 'on' );
      next if ( $word =~ m/^\s*$/ );
    $lower_case_count++ if ( $word eq lc($word) );
    }
    $reset = 1 if ( $lower_case_count > 2 );
  }

  # check key words on title
  $reset = 1 if ($tmphash->{'title'} =~ m/[Vv]ol\.?\s*\d/ );
  $reset = 1 if ($tmphash->{'title'} =~ m/[Ee]dited\sby/ );
  $reset = 1 if ($tmphash->{'title'} =~ m/[Ee]ds\./ );
  $reset = 1 if ($tmphash->{'title'} =~ m/editor/ );

  # check key words on book title
  $reset = 1 if ($tmphash->{'booktitle'} =~ m/In:/ );
  $reset = 1 if ($tmphash->{'booktitle'} =~ m/,\seds/ );
  $reset = 1 if ($tmphash->{'booktitle'} =~ m/editor/ );
  $reset = 1 if ($tmphash->{'booktitle'} =~ m/[Vv]ol\.?\s*\d/ );
  $reset = 1 if ($tmphash->{'booktitle'} =~ m/volume\s*\d/ );


  if ( $tmphash->{'issue'} ne '' ) {
    if ( $tmphash->{'issue'} =~ m/(\d+)-(\d+)/ ) {
      $reset = 1 if ( abs($2-$1) > 3 );
    }
  }
  if ( $tmphash->{'year'} ) {
    $tmphash->{'year'} =~ s/\D//g;
    if ( $tmphash->{'year'} =~ m/^\d+$/ ) {
      $reset = 1 if ( $tmphash->{'year'} > $max_year );
      $reset = 1 if ( $tmphash->{'year'} < $min_year );
    } else {
      $reset = 1;
    }
  }

  if ( $reset == 1 ) {
    $tmphash->{'au_flag'}   = 0;
    $tmphash->{'authors'}   = '';
    $tmphash->{'editors'}   = '';
    $tmphash->{'series'}    = '';
    $tmphash->{'title'}     = '';
    $tmphash->{'booktitle'} = '';
    $tmphash->{'journal'}   = '';
    $tmphash->{'pages'}     = '';
    $tmphash->{'volume'}    = '';
    $tmphash->{'issue'}     = '';
    $tmphash->{'any'}       = '';
    $tmphash->{'month'}     = '';
    $tmphash->{'publisher'} = '';
    $tmphash->{'jr_flag'}   = 0;
   }

  return $reset;
}

1;
