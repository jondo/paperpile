package Paperpile::Job;

use Moose;
use Moose::Util::TypeConstraints;

use Paperpile::Utils;
use Paperpile::Exceptions;
use Paperpile::Queue;
use Paperpile::Library::Publication;
use Paperpile::Crawler;
use Paperpile::PdfExtract;

use Data::Dumper;
use File::Path;
use File::Spec;
use File::Copy;
use File::stat;
use File::Compare;
use Storable qw(lock_store lock_retrieve);

enum 'Types' => (
  'MATCH',         # match a (partial) reference against a web resource
  'PDF_IMPORT',    # extract metadata from PDF and match agains web resource
  'PDF_SEARCH',    # search PDF online
  'WEB_IMPORT',     # Import a reference that was sent from the browser
  'TEST_JOB'
);

enum 'Status' => (
  'PENDING',       # job is waiting to be started
  'RUNNING',       # job is running
  'DONE',          # job is successfully finished.
  'ERROR'         # job finished with an error or was canceled.
);

has 'type'   => ( is => 'rw', isa => 'Types' );
has 'status' => ( is => 'rw', isa => 'Status' );

has 'id'    => ( is => 'rw' );    # Unique id identifying the job
has 'error' => ( is => 'rw' );    # Error message if job failed

has 'message' => ( is => 'rw' );   # Long-winded progress message.

# Field to store different job type specific information
has 'info' => ( is => 'rw', isa => 'HashRef' );

# Time (in seconds) that was used to finish a job
has 'duration' => ( is => 'rw', isa => 'Int' );

# This field serves as way to send interrupts to a running job. If set
# to 'CANCEL' a running job should exit with an exception UserCancel.
has 'interrupt' => ( is => 'rw', default => '' );

# Publication object which is needed for all job types
has 'pub' => ( is => 'rw', isa => 'Paperpile::Library::Publication' );

# File name to store the job object
has '_file' => ( is => 'rw' );

# rowid in the database table. At the moment only used to re-submit
# jobs at the original position
has '_rowid' => ( is => 'rw', default => undef );

sub BUILD {
  my ( $self, $params ) = @_;

  # if no id is given we create a new job
  if ( !$params->{id} ) {
    $self->generate_id;
    $self->status('PENDING');
    $self->info( { msg => $self->noun." waiting..." } );
    $self->error('');
    $self->duration(0);

    my $file = File::Spec->catfile( Paperpile::Utils->get_tmp_dir(), 'queue', $self->id );
    $self->_file($file);
    $self->save;
  }
  # otherwise restore object from disk
  else {
    $self->_file( File::Spec->catfile( Paperpile::Utils->get_tmp_dir(), 'queue', $self->id ) );
    $self->restore;
    $self->pub->refresh_job_fields($self);
  }
}

## Save job object to disk

sub save {
  my $self = shift;

  my $file = $self->_file;
  lock_store( $self, $self->_file );

}

## Read job object from disk

sub restore {
  my $self = shift;

  my $stored = undef;

  eval { $stored = lock_retrieve( $self->_file ); };

  return if not $stored;

  foreach my $key ( $self->meta->get_attribute_list ) {
    $self->$key( $stored->$key );
  }
}

sub reset {
  my $self = shift;

  if ($self->status eq 'RUNNING') {
    $self->interrupt('CANCEL');
    $self->save;
  }

  $self->update_status('PENDING');
  $self->error('');
  $self->interrupt('');
  $self->info({msg => ''});
  $self->save;
}

sub noun {
  my $self = shift;

  my $type = $self->type;
  return 'PDF download' if ($type eq 'PDF_SEARCH');
  return 'PDF import' if ($type eq 'PDF_IMPORT');
  return 'Test job' if ($type eq 'TEST_JOB');
}

sub remove {
  my $self = shift;

  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  my $id = $self->id;
  $dbh->do("DELETE FROM Queue WHERE jobid='$id';");

  unlink $self->_file;
}

sub cancel {
  my $self = shift;

  next if ($self->status ~~ ['ERROR', 'DONE']);

  if ($self->status eq 'RUNNING') {
    $self->interrupt('CANCEL');
  }

  $self->error($self->noun . ' canceled.');
  $self->update_status('ERROR');

  $self->save;
}

## Generate alphanumerical random id

sub generate_id {

  my $self = shift;

  my $string = '';

  my $i = 0;

  while ( $i < 16 ) {
    my $j = chr( int( rand(127) ) );
    if ( $j =~ /[a-zA-Z0-9]/ ) {
      $string .= uc($j);
      $i++;
    }
  }
  $self->id($string);
}

## Updates status in job file and queue database table

sub update_status {
  my ( $self, $status ) = @_;

  $self->status($status);

  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  my $job_id = $dbh->quote( $self->id );

  $dbh->begin_work;

  $status = $dbh->quote( $self->status );

  my $duration = $self->duration;

  $dbh->do("UPDATE Queue SET status=$status, duration=$duration WHERE jobid=$job_id");

  $dbh->commit;

  $self->save;

}

## Updates field 'key' with value 'value' in the info hash. Both the
## current instance and the saved information on disk are updated.

sub update_info {

  my ($self, $key, $value) = @_;

  my $stored = lock_retrieve( $self->_file );

  $stored->{info}->{$key} = $value;

  lock_store( $stored, $self->_file );

  $self->{info}->{$key} = $value;

}




## Runs the job in a forked sub-process

sub run {

  my $self = shift;

  my $pid = undef;

  # fork returned undef, indicating that it failed
  if ( !defined( $pid = fork() ) ) {
    die "Cannot fork: $!";
  }

  # fork returned 0, so this branch is child
  elsif ( $pid == 0 ) {

    $self->update_status('RUNNING');

    my $start_time = time;

    print STDERR " --> Started job ".$self->type." at ".$start_time."!!\n";

    eval {
      $self->_do_work;
    };

    if ($@) {
      $self->_catch_error;
    } else {
      my $end_time = time;
      $self->duration( $end_time - $start_time );
      $self->update_status('DONE');
    }

    my $q = Paperpile::Queue->new();
    $q->run;

    exit();
  }
}


# Calls the appropriate sequence of tasks for the different job
# types. All the functions that are called here work on the $self->pub
# object and sequentially update its contents until the job is
# done. All errors during this process throw exceptions that are
# caught centrally in the 'run' function above.

sub _do_work {

  my $self = shift;

  # $self->update_info('msg','Searching PDF');

  # sleep(2);

  # $self->update_info('msg','Starting download');

  # sleep(2);

  # $self->update_info('msg','Downloading');
  # $self->update_info( 'size', 1000 );

  # sleep(1);

  # $self->update_info( 'downloaded', 200 );

  # sleep(1);

  # $self->update_info( 'downloaded', 500 );

  # sleep(1);

  # $self->update_info( 'downloaded', 800 );

  # sleep(1);

  # $self->update_info( 'downloaded', 1000 );

  # sleep(1);

  # ExtractionError->throw("Some random error") if (rand(1) > 0.5);

  # $self->update_info('msg','File successfully downloaded.');
  # return;

  if ($self->type eq 'PDF_SEARCH'){

    if (!$self->pub->linkout && !$self->pub->doi){
      $self->_match;

      # This currently does not handle the case e.g when we match
      # successfully against PubMed but don't get a doi/linkout and a
      # downstream plugin would give us this information
      if (!$self->pub->linkout && !$self->pub->doi){
        NetMatchError->throw("Could not find the PDF");
      }
    }

    if (!$self->pub->pdf_url){
      $self->_crawl;
    }

    $self->_download;

    if ($self->pub->_imported){
      $self->_attach_pdf;
    }

    $self->update_info('callback',{fn => 'CONSOLE', args => $self->pub->pdf_url});
    $self->update_info('msg','File successfully downloaded.');

  }

  if ($self->type eq 'PDF_IMPORT') {

    $self->_lookup_pdf;

    if ($self->pub->_imported) {

      $self->update_info('msg',"PDF already in database (".$self->pub->citekey.").");

    } else {
      $self->_extract_meta_data;

      if ( !$self->pub->{doi} and !$self->pub->{title} ) {
        ExtractionError->throw("Could not find DOI or title in PDF.");
      }

      $self->_match;
      $self->_insert;
      $self->_attach_pdf;

      $self->update_info('msg',"PDF successfully imported.");
      $self->update_info('callback',{fn => 'updatePubGrid'});

    }
  }

  if ($self->type eq 'TEST_JOB') {

      $self->update_info('msg', 'Test job phase 1...');

      sleep(3);

      $self->update_info('msg', 'Test job phase 2...');

      sleep(3);

      $self->update_info('msg', 'Test job complete!');
  }
}


## Set error fields after an exception was thrown

sub _catch_error {

  my $self = shift;

  my $e = Exception::Class->caught();

  if ( ref $e ) {
    $self->error( $e->error );
    $self->update_status('ERROR');
    print STDERR " --> ERROR: ".$e->error."\n";
    $self->save;
  } else {
    print STDERR $@; # log this error also on console
    $self->error("An unexpected error has occured ($@)");
  }
}

## Rethrows an error that was catched by an eval{}

sub _rethrow_error {

  my $self = shift;

  my $e = Exception::Class->caught();

  if ( ref $e ) {
    $e->rethrow;
  } else {
    die($@);
  }
}


sub get_message {
  my $self = shift;

  if ($self->error) {
    return $self->error;
  }

  if ($self->info) {
    return $self->info->{'msg'};
  }

  return 'Empty message...';
}

## Dumps the job object as hash

sub as_hash {

  my $self = shift;

  my %hash = ();

  foreach my $key ( $self->meta->get_attribute_list ) {
    my $value = $self->$key;

    # Save the entire 'info' hash.
    if ( $key eq 'info' ) {
      $hash{info}     = $self->$key;
    }

    next if ref( $self->$key );

    $hash{$key} = $value;
  }
  
  $hash{message} = $self->get_message;

  $hash{citekey}  = $self->pub->citekey;
  $hash{title}    = $self->pub->title;
  $hash{doi}    = $self->pub->doi;
  $hash{citation} = $self->pub->_citation_display;
  $hash{authors}  = $self->pub->_authors_display;
  $hash{pdf}  = $self->pub->pdf;

  return {%hash};

}

## The functions that do the actual work are following now. They are
## called by _do_work in a modular fashion. They all work on the
## $self->pub object and throw exceptions if something goes wrong.

# Matches the publications against the different plugins given in the
# 'search_seq' user variable.

sub _match {

  my $self = shift;

  my $model    = Paperpile::Utils->get_library_model;
  my $settings = $model->settings;

  my @plugin_list = split( /,/, $settings->{search_seq} );

  foreach my $plugin (@plugin_list) {

    $self->update_info('msg',"Matching against $plugin...");

    eval { $self->_match_single($plugin); };

    my $e;
    if ( $e = Exception::Class->caught ) {

      # Did not find a match, continue with next plugin
      if ( $e = Exception::Class->caught('NetMatchError') ) {
        next;
      }
      # Other error has occured -> stop now by rethrowing error
      else {
        $self->_rethrow_error;
      }
    }
    # Found match -> stop now
    else {
      last;
    }
  }
}

## Does the actual match for a single pub object on a given plugin.

sub _match_single {

  my ( $self, $match_plugin ) = @_;

  my $plugin_module = "Paperpile::Plugins::Import::" . $match_plugin;
  my $plugin        = eval( "use $plugin_module; $plugin_module->" . 'new()' );

  my $pub = $self->pub;

  $pub = $plugin->match($pub);

  $self->pub($pub);

}

## Crawls for the PDF on the publisher site

sub _crawl {

  my $self = shift;

  $self->update_info('msg',"Searching PDF...");

  my $crawler = Paperpile::Crawler->new;
  $crawler->debug(1);
  $crawler->driver_file( Paperpile::Utils->path_to( 'data', 'pdf-crawler.xml' )->stringify );
  $crawler->load_driver();

  my $pdf;

  my $start_url = '';

  if ($self->pub->doi){
    $start_url = 'http://dx.doi.org/'.$self->pub->doi;
  } elsif ($self->pub->linkout){
    $start_url = $self->pub->linkout;
  } else {
    die("No target url for PDF download");
  }

  $pdf = $crawler->search_file( $start_url );

  $self->pub->pdf_url($pdf) if $pdf;

}

## Downloads the PDF

sub _download {

  my $self = shift;

  $self->update_info( 'msg', "Downloading PDF..." );

  my $file =
    File::Spec->catfile( Paperpile::Utils->get_tmp_dir, "download", $self->pub->sha1 . ".pdf" );

  # In case file already exists remove it
  unlink($file);

  my $ua = Paperpile::Utils->get_browser();

  my $res = $ua->request(
    HTTP::Request->new( GET => $self->pub->pdf_url ),
    sub {
      my ( $data, $response, $protocol ) = @_;

      $self->restore;

      if ( $self->interrupt eq 'CANCEL' ) {
        die("CANCEL");
      }

      if ( not -e $file ) {
        my $length = $response->content_length;

        if ( defined $length ) {
          $self->update_info( 'size', $length );
        } else {
          $self->update_info( 'size', undef );
        }

        open( FILE, ">$file" )
          or FileWriteError->throw(
          error => "Could not open temporary file for download,  $!.",
          file  => $file
          );
        binmode FILE;
      }

      print FILE $data
        or FileWriteError->throw(
        error => "Could not write data to temporary file,  $!.",
        file  => "$file"
        );
      my $current_size = stat($file)->size;

      $self->update_info( 'downloaded', $current_size );

    }
  );

  # Check if download was successful

  if ( $res->header("X-Died") || !$res->is_success ) {
    unlink($file);
    if ( $res->header("X-Died") ) {
      if ( $res->header("X-Died") =~ /CANCEL/ ) {
        UserCancel->throw( error => $self->noun . ' canceled.' );
      } else {
        NetGetError->throw(
          error => 'Download error (' . $res->header("X-Died") . ').',
          code  => $res->code,
        );
      }
    } else {
      NetGetError->throw(
        error => 'Download error ('. $res->message . ').',
        code  => $res->code,
      );
    }
  }

  # Check if we have got really a PDF and not a "Access denied" screen
  close(FILE);
  open( FILE, "<$file" );
  binmode(FILE);
  my $content;
  read( FILE, $content, 64 );

  if ( $content !~ m/^\%PDF/ ) {
    unlink($file);
    NetGetError->throw(
      'Could not download PDF. Your institution might need a subscription for the journal!');
  }

  $self->pub->pdf($file);

}


## Extracts meta-data from a PDF

sub _extract_meta_data {

  my $self = shift;

  my $bin = Paperpile::Utils->get_binary( 'pdftoxml');

  my $extract = Paperpile::PdfExtract->new( file => $self->pub->pdf, pdftoxml => $bin );

  my $pub = $extract->parsePDF;

  $pub->pdf($self->pub->pdf);

  $self->pub($pub);

}


## Look if a PDF file is already in the database, first checks if a
## file of the same size is in the database. If so, we do a full
## binary comparison to be sure

sub _lookup_pdf {

  my $self = shift;

  my $size = stat($self->pub->{pdf})->size;

  my $model = Paperpile::Utils->get_library_model;

  my $paper_root = $model->get_setting('paper_root');

  my $sth = $model->dbh->prepare("SELECT rowid,pdf,pdf_size FROM Publications WHERE pdf_size=$size;");
  $sth->execute;

  my $rowid = undef;

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $file = File::Spec->catfile( $paper_root, $row->{pdf} );

    if ( compare( $file, $self->pub->pdf ) == 0 ) {
      $rowid = $row->{rowid};
      last;
    }
  }

  if ($rowid) {
    my $pub = $model->standard_search( 'rowid=' . $rowid, 0, 1 )->[0];
    $self->pub($pub);
  }

}


## Inserts the current publication object into the database

sub _insert {

  my $self = shift;

  my $model = Paperpile::Utils->get_library_model;

  $model->create_pubs( [$self->pub] );

  $self->pub->_imported(1);

}

## Attaches a PDF file to the database entry of the current
## publication object.

sub _attach_pdf {

  my $self = shift;

  my $model = Paperpile::Utils->get_library_model;

  my $attached_file=$model->attach_file($self->pub->pdf, 1, $self->pub->_rowid, $self->pub);

  unlink($self->pub->pdf);

  $self->pub->pdf($attached_file);

}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
