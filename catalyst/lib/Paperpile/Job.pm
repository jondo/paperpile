package Paperpile::Job;

use Moose;
use Moose::Util::TypeConstraints;

use Paperpile::Queue;
use Paperpile::Library::Publication;
use Paperpile::Utils;
use Paperpile::Exceptions;
use Paperpile::Crawler;

use Data::Dumper;
use File::Path;
use File::Spec;
use File::Copy;
use Storable qw(lock_store lock_retrieve);

enum 'Types' => (
  'MATCH',         # match a (partial) reference against a web resource
  'PDF_IMPORT',    # extract metadata from PDF and match agains web resource
  'PDF_SEARCH',    # search PDF online
  'WEB_IMPORT'     # Import a reference that was sent from the browser
);

enum 'Status' => (
  'PENDING',       # job is waiting to be started
  'RUNNING',       # job is running
  'DONE'           # job is done
);

has 'type'   => ( is => 'rw', isa => 'Types' );
has 'status' => ( is => 'rw', isa => 'Status' );

has 'id'    => ( is => 'rw' );    # Unique id identifying the job
has 'error' => ( is => 'rw' );    # Error message if job failed

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


sub BUILD {
  my ( $self, $params ) = @_;

  # if no id is given we create a new job
  if ( !$params->{id} ) {
    $self->generate_id;
    $self->status('PENDING');
    $self->info( { msg => 'Waiting' } );
    $self->error('');
    $self->duration(0);

    my $file = File::Spec->catfile( Paperpile::Utils->get_tmp_dir(), 'queue' );
    mkpath($file);
    $file = File::Spec->catfile( $file, $self->id );
    $self->_file($file);
    $self->save;
  }

  # otherwise restore object from disk
  else {
    $self->_file( File::Spec->catfile( Paperpile::Utils->get_tmp_dir(), 'queue', $self->id ) );
    $self->restore;
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

  my $error = 0;
  $error = 1 if $self->error;
  my $duration = $self->duration;

  $dbh->do("UPDATE Queue SET status=$status, error=$error, duration=$duration WHERE jobid=$job_id");

  $dbh->commit;

  $self->save;

}

sub info_update {
  my ( $self, $info ) = @_;
  $self->info($info);
  $self->save;
}

## Runs the job in a forked sub-process

sub run {

  my $self = shift;

  my $pid = undef;

  # fork returned undef, so failed
  if ( !defined( $pid = fork() ) ) {
    die "Cannot fork: $!";
  }

  # fork returned 0, so this branch is child
  elsif ( $pid == 0 ) {

    srand();

    $self->update_status('RUNNING');

    my $start_time = time;

    eval {
      foreach my $x ( 0 .. 10 ) {
        $self->restore;

        if ( $self->interrupt eq 'CANCEL' ) {
          UserCancel->throw("Job stopped");
        }

        $self->info_update( { msg => "Stage $x" } );
        sleep(int(rand(10)));
      }
    };

    if ($@) {
      $self->_catch_error;
    }

    my $end_time = time;

    $self->duration( $end_time - $start_time );

    if ( int( rand(10) ) > 5 ) {
      $self->error('An error has occured');
    }

    $self->update_status('DONE');

    my $q = Paperpile::Queue->new();
    $q->run;

    exit();
  }

  # if ($self->type eq 'PDF_SEARCH'){

  #   if (not $self->pub->linkout){
  #     $self->_match;
  #     if ($self->error){
  #       $self->status_update('DONE');
  #       return;
  #     }
  #   }

  #   if (not $self->pub->pdf_url){
  #     $self->_crawl;
  #     if ($self->error){
  #       $self->status_update('DONE');
  #       return;
  #     }
  #   }

  #   $self->_download;
  #   if ($self->error){
  #     $self->status_update('DONE');
  #     return;
  #   }

  #   $self->status_update('DONE');
  # }

}

# Dumps the job object as hash

sub as_hash {

  my $self = shift;

  my %hash = ();

  foreach my $key ( $self->meta->get_attribute_list ) {
    my $value = $self->$key;

    # Also save info->{msg} as field 'progress'
    if ( $key eq 'info' ) {
      $hash{progress} = $self->$key->{msg};
      $hash{info}     = $self->$key;
    }

    next if ref( $self->$key );

    $hash{$key} = $value;
  }

  $hash{citekey}  = $self->pub->citekey;
  $hash{title}    = $self->pub->title;
  $hash{citation} = $self->pub->_citation_display;
  $hash{authors}  = $self->pub->_authors_display;

  return {%hash};

}

# Set error fields after an exception was thrown

sub _catch_error {

  my $self = shift;

  my $e = Exception::Class->caught();

  if ( ref $e ) {
    $self->error( $e->error );
  } else {
    $self->error("An unexpected error has occured ($@)");
  }
}

sub _match {

  my $self = shift;

  my $model    = Paperpile::Utils->get_library_model;
  my $settings = $model->settings;

  my @plugin_list = split( /,/, $settings->{search_seq} );

  my $matched = 0;

  foreach my $plugin (@plugin_list) {

    $self->info_update("Searching $plugin");

    eval { $self->_match_single($plugin); };

    my $e;
    if ( $e = Exception::Class->caught ) {
      if ( $e = Exception::Class->caught('NetMatchError') ) {
        next;
      } else {
        $matched = 0;
        $self->_catch_error;
        last;
      }
    } else {
      $matched = 1;
      last;
    }
  }

  if ( $self->error ) {
    $self->error('Could not find reference in online databases.');
  }
}

sub _match_single {

  my ( $self, $match_plugin ) = @_;

  my $plugin_module = "Paperpile::Plugins::Import::" . $match_plugin;
  my $plugin        = eval( "use $plugin_module; $plugin_module->" . 'new()' );

  my $pub = $self->pub;

  $pub = $plugin->match($pub);

  $self->pub($pub);

}

sub _crawl {

  my $self = shift;

  $self->info_update("Searching PDF on publisher site.");

  my $crawler = Paperpile::Crawler->new;
  $crawler->debug(0);
  $crawler->driver_file( Paperpile::Utils->path_to( 'data', 'pdf-crawler.xml' )->stringify );
  $crawler->load_driver();

  my $pdf;

  eval { $pdf = $crawler->search_file( $self->pub->linkout ) };

  $self->pub->pdf_url($pdf) if $pdf;

  if ( Exception::Class->caught ) {
    if ( Exception::Class->caught('CrawlerError') ) {
      if ( Exception::Class->caught('CrawlerUnknownSiteError') ) {
        $self->error('Publisher site not supported');
      }
      if ( Exception::Class->caught('CrawlerScrapeError') ) {
        $self->error('Could not download PDF. You might need a subscription.');
      }
    } else {
      $self->_catch_error;
    }
  }
}

sub _download {

  my $self = shift;

  $self->info_update("Downloading PDF");

  my $file;

  eval {

    my $dir = File::Spec->catfile( Paperpile::Utils->get_tmp_dir, "download", $self->id );

    rmtree($dir);
    mkpath($dir)
      or FileWriteError->throw(
      error => 'Download error. Could not create temporary dir for download.',
      file  => $dir
      );

    $file = "$dir/paper.pdf";

    my $ua = Paperpile::Utils->get_browser();

    my $res = $ua->request(
      HTTP::Request->new( GET => $self->pub->pdf_url ),
      sub {
        my ( $data, $response, $protocol ) = @_;
        if ( not -e $file ) {
          my $length = $response->content_length;
          open( SIZE, ">$file.size" )
            or FileWriteError->throw(
            error => 'Download error. Could not create temporary file for download.',
            file  => "$file.size"
            );
          if ( defined $length ) {
            print SIZE "$length\n";
          } else {
            print SIZE "null\n";
          }
          close(SIZE);
          open( FILE, ">$file" )
            or FileWriteError->throw(
            error => 'Download error. Could not open temporary file for download.',
            file  => $file
            );
          binmode FILE;
        }
        print FILE $data
          or FileWriteError->throw(
          error => 'Download error. Could not write data to temporary file.',
          file  => "$file"
          );
      }
    );

    # Check if download was successfull
    if ( $res->header("X-Died") || !$res->is_success ) {
      NetGetError->throw(
        error => 'Download error.',
        code  => $res->code,
      );
    }

    # Check if we have got really a PDF and not a "Access denied" screen
    close(FILE);
    open( FILE, "<$file" );
    binmode(FILE);
    my $content;
    read( FILE, $content, 64 );

    if ( $content !~ m/^\%PDF/ ) {
      rmtree($dir);
      NetGetError->throw(
        'Could not download PDF. Your institution might need a subscription for the journal.');
    }

  };

  my $e;
  if ( $e = Exception::Class->caught ) {
    if ( $e = Exception::Class->caught('PaperpileError') ) {
      $self->error( $e->error );
    } else {
      $self->_catch_error;
    }
  } else {
    $self->pub->pdf($file);
  }

}

no Moose::Util::TypeConstraints;

1;
