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


package Paperpile::Library::Publication;
use Mouse;
use Digest::SHA1;
use Data::GUID;
use Data::Dumper;
use File::Temp qw(tempfile);

use Paperpile;
use Paperpile::Utils;
use Paperpile::Library::Author;
use Paperpile::Exceptions;
use Paperpile::Formats;
use Encode qw(encode_utf8);
use Text::Unidecode;
use YAML::XS qw(LoadFile Dump);
use File::Spec;
use File::Path;
use 5.010;

# We currently support the following publication types
our @types = qw(
  ARTICLE
  BOOK
  BOOKLET
  INBOOK
  INCOLLECTION
  PROCEEDINGS
  INPROCEEDINGS
  MANUAL
  MASTERSTHESIS
  PHDTHESIS
  TECHREPORT
  UNPUBLISHED
  MISC
);

# The fields in this objects are equivalent to the fields in the
# database table 'Publications'. Fields starting with underscore are
# special helper fields not stored in the database. In addition to
# built in fields which are hardcoded in the database schema and here
# in this Module, there is a list of fields stored (and documented) in
# the configuration file paperpile.yaml.

### 'Built-in' fields

# The unique rowid in the SQLite table 'Publications'
has '_rowid' => ( is => 'rw' );

# The unique sha1 key which is currently calculated from title,
# authors and year. The purpose is to compare quickly if two
# publications are the same
has 'sha1' => ( is => 'rw' );

# Globally unique identifier that never changes and that can be used
# to track a publication also outside the local database (e.g. for
# syncinc across networks)
has 'guid' => ( is => 'rw' );

# Timestamp when the entry was created
has 'created' => ( is => 'rw', default => '' );

# Flags entry as trashed
has 'trashed' => ( is => 'rw', isa => 'Int', default => 0 );

# Timestamp when it was last read
has 'last_read' => ( is => 'rw', default => '' );

# How many times it was read
has 'times_read' => ( is => 'rw', isa => 'Int', default => 0 );

# The guid of an attached PDF file
has 'pdf' => ( is => 'rw', default => '' );

# File name of PDF relative to paper_root. Use for display purpose and
# to reconstruct PDF path without going back to attachments table
has 'pdf_name' => ( is => 'rw', default => '' );

# Comma separated list of guids of other attachments
has 'attachments' => ( is => 'rw', default=>'');
has '_attachments_list' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

# User provided annotation "Notes", formatted in HTML
has 'annote' => ( is => 'rw', default => '' );

# Comma separated list of guids for labels (known as "labels" in the UI)
has 'labels' => ( is => 'rw', default => '' );

# Temporary field to handle labels which are not imported into the
# user's library.
has 'labels_tmp' => ( is => 'rw', default => '' );


# Comma separated list of folders
has 'folders' => ( is => 'rw', default => '' );

# Temporary field to handle folders which are not imported into the
# user's library.
#has 'folders_tmp' => ( is => 'rw', default => '' );


### Fields from the config file

my $config = LoadFile( Paperpile->path_to('conf/fields.yaml') );

foreach my $field ( keys %{ $config->{pub_fields} } ) {

  # These contribute to the sha1 and need a trigger to re-calculate it
  # upon change
  if ( $field ~~ [ 'year', 'title', 'booktitle' ] ) {
    has $field => (
      is      => 'rw',
      default => '',
      trigger => sub {
        my $self = shift;
        $self->refresh_fields;
      }
    );
  } elsif ( $field ~~ [ 'authors', 'editors' ] ) {
    has $field => (
      is      => 'rw',
      default => '',
      trigger => sub {
        my $self = shift;
        $self->refresh_authors;
      }
    );
  } else {
    has $field => (
      is      => 'rw',
      default => ''
    );
  }
}

### Helper fields which have no equivalent field in the database

# If available, direct link to PDF goes in here
has '_pdf_url' => ( is => 'rw', default => '' );

# Temporary store absolute file name of PDF that is to be imported
# together with the publication object
has '_pdf_tmp' => ( is => 'rw', default => '' );

# Temporary store list of absolute file names of attachments to be
# imported together with the publication object
has '_attachments_tmp' => ( is => 'rw', default => sub { [] } );

# Formatted strings to be displayed in the frontend.
has '_authors_display'  => ( is => 'rw' );
has '_citation_display' => ( is => 'rw' );

# If an entry is already in our database this field is true.
has '_imported' => ( is => 'rw', isa => 'Bool' );
# Used as a flag during Library import to store whether an import
# was skipped because an identical reference already exists.
has '_insert_skipped' => ( is => 'rw' );


# Can be set to a job id of the task queue. It allows to update job
# status messages from functions in Publication class.
has '_jobid' => ( is => 'rw', default => undef );

# If true, has a PDF search / download job in progress.
has '_search_job' => ( is => 'rw', default => undef );

# If true, has a PDF search / download job in progress.
has '_metadata_job' => ( is => 'rw', default => undef );

# Job object, only exists if there is a current job tied to the publication

# Some import plugins first only scrape partial information and use this
# flag as an indicator that they need a second stage to fetch more info.
has '_needs_details_lookup' => ( is => 'rw', default => '' );

# Stores a link that (for now) only GoogleScholar.pm uses as a source for looking
# up details if the other methods (URL matching, etc.) fail.
has '_details_link' => ( is => 'rw', default => '' );

# Is some kind of _details_link for Google Scholar. It is the link
# to British Library Direct, where bibliographic data is available.
# In some cases it also offers the absract, which is impossible to
# get directly from Google.
has '_google_BL_link' => ( is => 'rw', default => '' );

# Holds the linkout for a related article search.
has '_related_articles' => ( is => 'rw', default => '' );

# If a search in the local database returns a hit in the fulltext,
# abstract or notes the hit+context ('snippet') is stored in these
# fields
has '_snippets' => ( is => 'rw' );

# CSS style to highlight the entry in the frontend
has '_highlight' => ( is => 'rw', default => 'pp-grid-highlight0' );

# ID of the cluster the publication belongs to after a duplicate search
has '_dup_id' => ( is => 'rw' );

# Holds the Google Scholar link to other versions of
# the same publication.
has '_all_versions' => ( is => 'rw', default => '' );

# Google Scholar gives the IP or URL as publisher. This is not
# that what we want to display as publisher, but it is useful
# for other purposes in the Google Scholar Plugin.
has '_www_publisher' => ( is => 'rw', default => '' );

# If true fields update themselves automatically. Is only activated
# after initial object creation in BUILD to avoid excessive redundant
# refreshing.
has '_auto_refresh' => ( is => 'rw', isa => 'Int', default => 0 );

# If set to true helper fields for gui (_citation_display,
# _author_display) are not generated. Thus we avoid created tons of
# author objects which is not always needed (e.g. for import).
has '_light' => ( is => 'rw', isa => 'Int', default => 0 );

# If object comes from a database we store the file. Currently
# only used for function refresh_attachments
has '_db_connection' => ( is => 'rw', default => '' );

# Flag indicating that publication has been imported from PDF and could
# not be matched to an online reference
has '_incomplete' => ( is => 'rw', default => '' );

# Used to store old guid when guid changes in some cases on import
has '_old_guid' => ( is => 'rw' );

sub BUILD {
  my ( $self, $params ) = @_;

  $self->_auto_refresh(1);
  $self->refresh_authors;

}

# Function: refresh_fields

# Update dynamic fields like sha1 and formatted strings for display

sub refresh_fields {
  ( my $self ) = @_;

  return if ( not $self->_auto_refresh );

  if ( not $self->_light ) {

    ## Citation display string
    my $cit = $self->format_citation;
    if ($cit) {
      $self->_citation_display($cit);
    }

  }

  ## Sha1
  $self->calculate_sha1;

}

sub refresh_authors {

  ( my $self ) = @_;

  return if $self->_light;
  return if not( $self->_auto_refresh );

  ## Author display string
  my $authors = $self->format_authors;
  if ($authors) {
    $self->_authors_display($authors);
  }
  $self->refresh_fields;
}

# Function: calculate_sha1

# Calculate unique sha1 from several key fields. Needs more thought on
# what to include. Function is a mess right now.

sub calculate_sha1 {

  ( my $self ) = @_;

  my $ctx = Digest::SHA1->new;

  if ( ( $self->authors or $self->_authors_display or $self->editors )
    or ( $self->title or $self->booktitle ) ) {
    if ( $self->authors ) {
      $ctx->add( encode_utf8( $self->authors ) );
    } elsif ( $self->_authors_display and !$self->editors ) {
      $ctx->add( encode_utf8( $self->_authors_display ) );
    }
    if ( $self->editors ) {
      $ctx->add( encode_utf8( $self->editors ) );
    }
    if ( $self->title ) {
      $ctx->add( encode_utf8( $self->title ) );
    }
    if ( $self->booktitle ) {
      $ctx->add( encode_utf8( $self->booktitle ) );
    }

  }

  $self->sha1( $ctx->hexdigest );

}

# Function: format_citation

# Currently this function return an adhoc Pubmed like citation format
# Replace this with proper formatting function once CSL is in place

sub format_citation {

  ( my $self ) = @_;

  my $cit = '';

  my $j = $self->journal;

  if ($j) {
    $j =~ s/\.//g;
    $cit .= '<i>' . $j . '</i>. ';
  }

  if ( $self->booktitle ) {
    if ( $self->pubtype eq 'INCOLLECTION' ) {
      $cit .= "in ";
    }
    if ( $self->title ) {
      $cit .= '<i>' . $self->booktitle . '</i>. ' if ( $self->title ne $self->booktitle );
    } else {
      $cit .= '<i>' . $self->booktitle . '</i>. ';
    }
  }

  $cit .= $self->howpublished . ' ' if ( $self->howpublished );
  $cit .= '<i>Unpublished</i>. '      if ( $self->pubtype eq 'UNPUBLISHED' );
  $cit .= '<i>PhD Thesis</i>. '       if ( $self->pubtype eq 'PHDTHESIS' );
  $cit .= '<i>Master\'s Thesis</i>. ' if ( $self->pubtype eq 'MASTERSTHESIS' );
  $cit .= $self->school . ' '         if ( $self->school );

  $cit .= '(' . $self->year . ')' if ( $self->year );
  $cit .= ' ' . $self->month if ( $self->month );
  $cit .= '; ' if ( $cit && $self->year );

  if ( $self->pubtype eq 'ARTICLE' or $self->pubtype eq 'INPROCEEDINGS' ) {
    $cit .= '<b>' . $self->volume . '</b>:' if ( $self->volume );
    $cit .= '(' . $self->issue . ') '       if ( $self->issue );
    $cit .= $self->pages                    if ( $self->pages );
  }

  if ( $self->pubtype eq 'BOOK' or $self->pubtype eq 'INBOOK' or $self->pubtype eq 'INCOLLECTION' )
  {
    $cit .= $self->publisher . ', ' if ( $self->publisher );
    $cit .= $self->address . ' '    if ( $self->address );
  }

  $cit =~ s/\s*[;,.]\s*$//;

  return $cit;

}


sub best_link {
  my $self = shift;

  if ( $self->doi ) {
    return 'http://dx.doi.org/' . $self->doi;
  } elsif ( $self->linkout ) {
    return $self->linkout;
  } elsif ( $self->url ) {
    return $self->url;
  }

  # We can't consider Pubmed a valid link because we can't be sure if
  # we get a linkout/doi from there.

  # elsif ( $self->pmid ) { return
  # 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?retmode=ref&cmd=prlinks&db=PubMed&id='. $self->pmid;
  # }

  return '';
}

# Takes any fields that are defined in $other_pub and aren't defined in $self
# and applies them to $self. Also brings over $other_pub's PDF (if $self does not
# have one defined) and attachments.
sub merge_into_me {
  my ($self, $other_pub, $library) = @_;

  my ($dbh, $in_prev_tx) = $library->begin_or_continue_tx;

  my $guid       = $self->guid;
  my $other_guid = $other_pub->guid;

  # He's got a PDF that we want.
  if ( !$self->pdf && $other_pub->pdf ) {
    my $sth =
      $dbh->prepare("SELECT * FROM Attachments WHERE publication='$other_guid' and is_pdf=1;");
    $sth->execute;

    while ( my $row = $sth->fetchrow_hashref() ) {
      my $other_pdf = $row->{local_file};
      $library->attach_file( $other_pdf, 1, $self, 0 );
    }
  }

  # Now bring over all attachments.
  if ( $other_pub->attachments ) {
    my $sth =
      $dbh->prepare("SELECT * FROM Attachments WHERE publication='$other_guid' and is_pdf=0;");
    $sth->execute;

    while ( my $row = $sth->fetchrow_hashref() ) {
      my $other_pdf = $row->{local_file};
      $library->attach_file( $other_pdf, 0, $self, 0 );
    }
  }

  foreach my $folder ( split( ',', $other_pub->folders ) ) {
    $library->add_to_collection( [$self], $folder );
  }
  foreach my $label ( split( ',', $other_pub->labels ) ) {
    $library->add_to_collection( [$self], $label );
  }

  foreach my $key ( $self->meta->get_attribute_list ) {
    my $value = $self->$key;

    next if ( $key =~ m/(folders|labels|pdf_name|pdf|attachments)/gi );
    next if ( ref($value) );

    if ( $self->is_trivial_value( $key, $value )
      && !$self->is_trivial_value( $key, $other_pub->$key ) ) {
      my $other_value = $other_pub->$key;
      $self->$key( $other_pub->$key );
    }
  }

  $library->commit_or_continue_tx($in_prev_tx);

}

sub is_trivial_value {
  my $self  = shift;
  my $key   = shift;
  my $value = shift;

  my $tmp = $value;

  return 1 if ( !defined $tmp );
  return 1 if ( $tmp eq '' );

  $tmp =~ s/\s+//g;    # All spaces.

  return 1 if ( $tmp eq '' );

  #print STDERR "NOT trivial: $key \t\t $value\n";
  return 0;
}

sub format_authors {

  my $self = shift;

  #return "";

  my @display = ();
  if ( $self->authors ) {

    my $tmp = Paperpile::Library::Author->new();

    foreach my $a ( split( /\band\b/i, $self->authors ) ) {

      #push @display, Paperpile::Library::Author->new( full => $a )->nice;
      $tmp->full($a);
      push @display, $tmp->nice;
      $tmp->clear;
    }
    $self->_authors_display( join( ', ', @display ) );
  }

  # We only show editors when no authors are given
  if ( $self->editors and !$self->authors ) {
    foreach my $a ( split( /\band\b/i, $self->editors ) ) {
      push @display, Paperpile::Library::Author->new( full => $a )->nice;
    }
    $self->_authors_display( join( ', ', @display ) . ' (eds.)' );
  }

}

sub refresh_job_fields {
  my ( $self, $job ) = @_;

  my $data = {};

  $data->{status} = $job->status;
  $data->{id}     = $job->id;
  $data->{error}  = $job->error;
  $data->{start}  = $job->start;

  foreach my $key ( keys %{ $job->info } ) {
    $data->{$key} = $job->info->{$key};
  }

  if ( $job->job_type eq 'PDF_SEARCH' ) {
    $self->_search_job($data);
  } elsif ( $job->job_type eq 'METADATA_UPDATE' ) {
    $self->_metadata_job($data);
  }
}

# Gets attachment information from a database (given in
# $self->_db_connection) into the pub object. Is not very efficient if
# this is called for a long list of objects with attachments. But
# generally non-PDF attachments are probably not so common that we can
# keep it that way for now.

sub refresh_attachments {
  ( my $self, my $model ) = @_;

  $self->_attachments_list( [] );

  if ($self->attachments && ($self->_db_connection || $model))  {

    if (!$model){
      $model = Paperpile::Model::Library->new( {file => $self->_db_connection} );
    }
    my ($dbh, $in_prev_tx) = $model->begin_or_continue_tx;

    my $paper_root = $model->get_setting('paper_root');
    my $guid       = $self->guid;
    my $sth = $dbh->prepare("SELECT * FROM Attachments WHERE publication='$guid' AND is_pdf=0;");

    $sth->execute;

    my @output = ();
    my @files  = ();
    while ( my $row = $sth->fetchrow_hashref() ) {
      my $link = "/serve/" . $row->{local_file};

      ( my $suffix ) = ( $link =~ /\.([^.]*)$/ );

      push @output, {
        file => $row->{name},
        path => $row->{local_file},
        link => $link,
        cls  => "file-$suffix",
        guid => $row->{guid}
        };

      push @files, $row->{local_file};

    }

    $self->_attachments_list( \@output );

    # if attachments are present and pub is not imported it is an
    # temporary database. To make sure attachments are considered
    # during import we set _attachments_tmp here.
    if ( !$self->_imported ) {
      $self->_attachments_tmp( \@files );
    }

    $self->_attachments_list( \@output );

    $model->commit_or_continue_tx($in_prev_tx);

  }
}

# Lookup data via the match function of the search plugins given in
# the array $plugin_list. If a match is found the name of the
# sucessful plugin, otherwise undef is returned. If $require_linkout
# is set, we only consider a auto_complete successful if we got a
# doi/linkout (for use during PDF download)

sub auto_complete {

  my ( $self, $plugin_list, $require_linkout ) = @_;

  # First check if the user wants to search PubMed at all
  my $hasPubMed = 0;
  if ( grep { $_ eq 'PubMed' } @$plugin_list ) {
    $hasPubMed = 1;
  }

  if ( $self->arxivid) {
    # If we have only an ArXiv ID we rank the ArXiv plugin first
    if (!$self->title){
      @$plugin_list = ( 'ArXiv', grep { $_ ne 'ArXiv' } @$plugin_list );
    } else {
      # If we have other data and the arxivid but ArXiv is not in the
      # list we add it as last option
      if ( !(grep { $_ eq 'ArXiv' } @$plugin_list )) {
        @$plugin_list = ( grep { $_ ne 'ArXiv'} @$plugin_list, 'ArXiv' );
      }
    }
  }

  # If a doi or linkout is given we use the URL module to look first
  # directly on the publisher site
  if ($self->doi || $self->linkout){
    unshift @$plugin_list, 'URL';
  }

  # If a we have a PMID we search PubMed, likewise if we have a DOI
  # and the user uses PubMed because PubMed data is usually the most
  # reliable
  if ( $self->pmid || ($self->doi && $hasPubMed)) {
    @$plugin_list = ( 'PubMed', grep { $_ ne 'PubMed' } @$plugin_list );
  }

  # Try all plugins sequentially until a match is found
  my $success_plugin = undef;
  my $caught_error   = undef;

  foreach my $plugin_name (@$plugin_list) {

    my $msg = "Searching $plugin_name";

    $msg = "Search publisher's site" if $plugin_name eq 'URL';

    Paperpile::Utils->update_job_info($self->_jobid, 'msg', $msg);

    eval {
      my $plugin_module = "Paperpile::Plugins::Import::" . $plugin_name;
      my $plugin        = eval( "use $plugin_module; $plugin_module->" . 'new()' );
      $plugin->jobid($self->_jobid);
      $self = $plugin->match($self);
    };

    my $e;
    if ( $e = Exception::Class->caught ) {

      # Did not find a match, continue with next plugin
      if ( Exception::Class->caught('NetMatchError') ) {
        next;
      }

      # Other exception has occured; still try other plugins but save
      # error message to show if all plugins fail
      else {
        if ( ref $e ) {
          $caught_error = $e->error;
          next;
        }

        # Abort on unexpected exception
        else {
          die($@);
        }
      }
    }

    # Found match -> stop now
    else {

      if ($require_linkout && !$self->best_link){
        next;
      }

      $success_plugin = $plugin_name;
      $caught_error   = undef;
      last;
    }
  }

  # Rethrow errors that were observed previously
  if ($caught_error) {
    PaperpileError->throw($caught_error);
  }

  if ($success_plugin){
    my $name = $success_plugin;
    $name = 'publisher site' if ($name eq 'URL');
    return $name;
  } else {
    return undef;
  }

}

sub create_guid {
  my $self = shift;

  # use Paperpile::Utils->generate_guid instead

  my $_guid = Data::GUID->new;
  $_guid = $_guid->as_hex;
  $_guid =~ s/^0x//;
  $self->guid($_guid);

}

sub add_label {
  my ( $self, $guid ) = @_;
  $self->add_guid( 'labels', $guid );
}

sub add_folder {
  my ( $self, $guid ) = @_;
  $self->add_guid( 'folders', $guid );
}


sub remove_label {
  my ( $self, $guid ) = @_;
  $self->remove_guid( 'labels', $guid );
}

sub remove_folder {
  my ( $self, $guid ) = @_;
  $self->remove_guid( 'folders', $guid );
}

sub remove_guid {

  my ( $self, $what, $guid ) = @_;

  return unless ( defined $what );

  $what = 'folders' if ( $what eq 'FOLDER' );
  $what = 'labels'    if ( $what eq 'LABEL' );

  my $list = $self->$what;

  $list=~s/^$guid,//;
  $list=~s/$guid,//;
  $list=~s/$guid$//;

  $self->$what($list);

}


sub add_guid {

  my ( $self, $what, $guid ) = @_;

  return unless ( defined $what );

  $what = 'folders' if ( $what eq 'FOLDER' );
  $what = 'labels'    if ( $what eq 'LABEL' );

  my @guids = split( /,/, $self->$what );
  push @guids, $guid;
  my %seen = ();
  @guids = grep { !$seen{$_}++ } @guids;
  my $new_guids = join( ',', @guids );
  $self->$what($new_guids);
}

sub as_hash {

  ( my $self ) = @_;

  my %hash = ();

  #$self->refresh_job_fields;
  $self->refresh_attachments;

  foreach my $key ( $self->meta->get_attribute_list ) {
    my $value = $self->$key;


    # Remove strange unicode characters that cause problems in JSON
    # interpreter in the frontend. Right no we just clear \x{2028} but
    # there might be more; see here:
    # http://stackoverflow.com/questions/2965293/javascript-parse-error-on-u2028-unicode-character
    # PMID 21070612 is a test case which contains \x{2028} and breaks
    # the frontend whitout the following:

    if (defined $value){
      $value=~s/\x{2028}//g;
    }

    # Force it to a number to be correctly converted to JSON
    if ( $key ~~ [ 'times_read', 'trashed', '_imported' ] ) {
      $value += 0;
    }

    $hash{$key} = $value if ( $key eq '_attachments_list' );

    # take only simple scalar and allowed refs
    next if ( ref($value) && $key ne '_search_job' && $key ne '_metadata_job' );

    $hash{$key} = $value;
  }

  return {%hash};

}

# returns fields that store bibliographic data in YAML format

sub as_YAML {

  ( my $self ) = @_;

  my %hash = ( );

  foreach my $key ( $self->meta->get_attribute_list ) {
    my $value = $self->$key;
    next if ( not defined $value );
    next if ( $value eq '' );
    next if ( $key =~ m/^_/ );
    next if ( $key =~ m/sha1/ );
    next if ( $key =~ m/times_read/ );
    next if ( $key =~ m/trashed/ );

    $hash{$key} = $value;
  }

  return Dump \%hash;
}


# Function: get_authors

# We store the authors in a flat string in BibTeX formatting This
# function returns an ArrayRef of Paperpile::Library::Author objects.
# if $editors is true, we return editors

sub get_authors {

  ( my $self, my $editors ) = @_;
  my @authors = ();

  my $data = $self->authors;

  if ($editors) {
    $data = $self->editors;
  }

  return [] if not $data;

  foreach my $a ( split( /\band\b/i, $data ) ) {
    $a =~ s/^\s+//;
    $a =~ s/\s+$//;
    push @authors, Paperpile::Library::Author->new( full => $a );
  }
  return [@authors];
}

# Function: format_pattern

# Generates a string from a pattern like [firstauthor][year] See code
# for available fields and syntax.

# The optional HashRef $substitutions can hold additional fields to be
# replaced dynamically. e.g {key => 'Gruber2009'} will replace [key]
# with 'Gruber2009'.

sub format_pattern {

  ( my $self, my $pattern, my $substitutions ) = @_;

  my @authors = ();
  foreach my $a ( @{ $self->get_authors(0) } ) {
    if ( $a->collective ) {
      push @authors, $a->collective;
    } else {
      push @authors, $a->last;
    }
  }
  # if no authors are given we use editors
  if ( not @authors ) {

    foreach my $a ( @{ $self->get_authors(1) } ) {
      if ( $a->collective ) {
        push @authors, $a->collective;
      } else {
        push @authors, $a->last;
      }
    }
  }
  if ( not @authors ) {
    @authors = ('_unnamed_');
  }

  # Make sure there are no slashes or backslashes in the author names
  foreach my $i ( 0 .. $#authors ) {
    $authors[$i] =~ s!/!!g;
    $authors[$i] =~ s!\\!!g;
  }

  my $first_author = $authors[0];
  my $last_author  = $authors[$#authors];

  # Assume that nobody uses a pattern that includes the first author
  # and not the last author.
  if ( $first_author eq $last_author ) {
    $last_author = '';
  }

  my $YYYY    = $self->year;
  my $YY      = $YYYY;
  my $title   = $self->title;
  my $journal = $self->journal;

  # Make sure there are no slashes or backslashes in any of the other fields
  $title   =~ s!/!_!g;
  $YY      =~ s!/!_!g;
  $YYYY    =~ s!/!_!g;
  $journal =~ s!/!_!g;
  $title   =~ s!\\!_!g;
  $YY      =~ s!\\!_!g;
  $YYYY    =~ s!\\!_!g;
  $journal =~ s!\\!_!g;

  my @title_words = split( /\s+/, $title );

  $journal      =~ s/\s+/_/g;
  $first_author =~ s/\s+/_/g;
  $last_author  =~ s/\s+/_/g;

  if ( defined $YY && length($YY) == 4 ) {
    $YY = substr( $YYYY, 2, 2 );
  } else {
    $YY = $YYYY = '_undated_';
  }

  # [firstauthor]
  if ( $pattern =~ /\[((firstauthor)(:(\d+))?)\]/i ) {
    my $found_field = $1;
    $first_author = uc($first_author)      if $2 eq 'FIRSTAUTHOR';
    $first_author = ucfirst($first_author) if $2 eq 'Firstauthor';
    $first_author = lc($first_author)      if $2 eq 'firstauthor';
    $first_author = substr( $first_author, 0, $4 ) if $3;
    $pattern =~ s/$found_field/$first_author/g;
  }

  # [lastauthor]
  if ( $pattern =~ /\[((lastauthor)(:(\d+))?)\]/i ) {
    my $found_field = $1;
    $last_author = uc($last_author)      if $2 eq 'LASTAUTHOR';
    $last_author = ucfirst($last_author) if $2 eq 'Lastauthor';
    $last_author = lc($last_author)      if $2 eq 'lastauthor';
    $last_author = substr( $last_author, 0, $4 ) if $3;
    $pattern =~ s/$found_field/$last_author/g;
  }

  # [authors]
  if ( $pattern =~ /\[((authors)(\d*)(:(\d+))?)\]/i ) {
    my $found_field = $1;
    my $to          = @authors;
    $to = $3 if $3;
    foreach my $i ( 0 .. $to - 1 ) {
      $authors[$i] = substr( $authors[$i], 0, $5 ) if ($4);
      $authors[$i] = uc( $authors[$i] )      if $2 eq 'AUTHORS';
      $authors[$i] = ucfirst( $authors[$i] ) if $2 eq 'Authors';
      $authors[$i] = lc( $authors[$i] )      if $2 eq 'authors';
    }
    my $author_string = join( '_', @authors[ 0 .. $to - 1 ] );
    if ( $to < @authors ) {
      $author_string .= '_et_al';
    }
    $pattern =~ s/$found_field/$author_string/g;
  }

  # [title]
  if ( $pattern =~ /\[((title)(\d*)(:(\d+))?)\]/i ) {
    my $found_field = $1;
    my $to          = @title_words;
    $to = $3 if $3;
    foreach my $i ( 0 .. $to - 1 ) {
      $title_words[$i] = substr( $title_words[$i], 0, $5 ) if ($4);
      $title_words[$i] = uc( $title_words[$i] ) if $2 eq 'TITLE';
      $title_words[$i] = lc( $title_words[$i] ) if $2 eq 'title';
    }
    my $title_string = join( '_', @title_words[ 0 .. $to - 1 ] );
    $pattern =~ s/$found_field/$title_string/g;
  }

  # [YY] and [YYYY]
  if ( $pattern =~ /\[YY\]|\[YYYY\]/ ) {
    if ($YYYY) {
      $pattern =~ s/\[YY\]/$YY/g;
      $pattern =~ s/\[YYYY\]/$YYYY/g;
    }
  }

  # [journal]
  if ( $pattern =~ /\[(journal)\]/i ) {
    my $found_field = $1;
    $journal     = uc($journal)      if $1 eq 'JOURNAL';
    $journal     = ucfirst($journal) if $1 eq 'Journal';
    $journal = lc($journal)      if $1 eq 'journal';
    $pattern =~ s/$found_field/$journal/g;
  }

  # Custom substitutions, given as parameter

  if ( defined $substitutions ) {
    foreach my $key ( keys %$substitutions ) {
      my $value = $substitutions->{$key};
      $pattern =~ s/\[$key\]/$value/g;
    }
  }

  # remove brackets that are still left
  $pattern =~ s/\[//g;
  $pattern =~ s/\]//g;

  # Try to change unicode character to the appropriate ASCII characters
  $pattern = unidecode($pattern);

  # Remove all remaining non-alphanumeric characters that might be
  # left but keep slashes
  $pattern =~ s{/}{__SLASH__}g;
  $pattern =~ s/\W//g;
  $pattern =~ s{__SLASH__}{/}g;

  # No name, no date
  if ( $pattern =~ /(unnamed__undated|undated__unnamed)/ ) {

    my $subst;

    my $max = $#title_words;
    $max = 3 if $max >= 3;
    my $title_string = join( '_', @title_words[ 0 .. $max ] );

    # Use title words if not already in pattern
    if ($title_string) {
      if ( not $pattern =~ /$title_string/ ) {
        $subst = $title_string;
      } else {
        $subst = '';
      }
    } else {
      $subst = 'incomplete_reference';
    }

    $pattern =~ s/(unnamed__undated|undated__unnamed)/$subst/;
  }

  # Fix underscores
  $pattern =~ s/_+/_/g;      # merge double underscores
  $pattern =~ s/^_//;        # remove underscores from beginning
  $pattern =~ s/_$//;        # remove underscores from end
  $pattern =~ s/\/_/\//g;    # remove underscores from paths: path/_unnamed_2000
  $pattern =~ s/_\//\//g;    # remove underscores from paths: path/unnamed_/2000

  return $pattern;

}

# Fill itself with data from a $string that is given in a supported
# bibliography format

sub build_from_string {

  my ( $self, $string) = @_;

  my ( $fh, $file_name ) = tempfile();

  print $fh $string;
  close($fh);

  my $reader = Paperpile::Formats->guess_format( $file_name );

  my $data = $reader->read->[0]->as_hash;

  foreach my $key (keys %$data){
    $self->$key($data->{$key});
  }

  unlink($file_name);

}



# Basic validation of fields to make sure nothing breaks and fields
# are set as intended. Should be called when Publication object is
# created from dubious source (e.g. file import plugins). Right now it
# is very basic but we should extend it.

sub sanitize_fields {

  my ( $self ) = @_;

  # If there is no sha1 there is also no title. Set title to make sure
  # sha1 gets set and doesn not cause troubles downstream.
  if (!$self->sha1){
    $self->title('No Title');
    $self->calculate_sha1;
  }
}

sub debug {
  my $self = shift;
  my $hash = $self->as_hash;

  print STDERR "PUB: { \n";
  foreach my $key ( sort keys %$hash ) {
    my $value = $hash->{$key} || "";
    next if ( $value eq '' );
    print STDERR "  $key => " . $value . "\n";
  }
  print STDERR "}\n";
}



1;

