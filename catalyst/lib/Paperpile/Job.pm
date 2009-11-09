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
use File::Temp qw/ tempfile /;
use Time::HiRes qw/ usleep/;

use JSON;
use 5.010;

enum 'Types'  => qw(MATCH PDF_IMPORT PDF_SEARCH WEB_IMPORT);
enum 'Status' => qw(RUNNING PENDING DONE);

has 'id'       => ( is => 'rw', isa => 'Str' );
has 'type'     => ( is => 'rw', isa => 'Types' );
has 'status'   => ( is => 'rw', isa => 'Status' );
has 'error'    => ( is => 'rw', isa => 'Str' );
has 'progress' => ( is => 'rw', isa => 'Str' );
has 'duration' => ( is => 'rw', isa => 'Int' );

has 'pub'   => ( is => 'rw', isa => 'Paperpile::Library::Publication' );
has 'queue' => ( is => 'rw', isa => 'Paperpile::Queue' );

sub BUILD {
  my ( $self, $params ) = @_;
  $self->generate_id;
  $self->status('PENDING');
  $self->progress('Waiting.');
  $self->error('');
}

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


sub status_update {
  my ( $self, $status ) = @_;
  $self->status($status);
  $self->queue( Paperpile::Queue->new() );
  $self->queue->update_job($self);
  Paperpile::Utils->store( 'job_' . $self->id, $self );
}

sub progress_update {
  my ( $self, $progress ) = @_;
  $self->progress($progress);
  $self->queue( Paperpile::Queue->new() );
  $self->queue->update_job($self);
}

sub run {

  my $self = shift;

  my $pid = undef;

  # fork returned undef, so failed
  if ( !defined( $pid = fork() ) ) {
    die "Cannot fork: $!";
  }
  # fork returned 0, so this branch is child
  elsif ( $pid == 0 ) {

    my $start_time = time;

    $self->status_update('RUNNING');

    $self->progress_update('Stage1');

    foreach my $x ( 0 .. 10 ) {
      open( LOG, ">>log" );
      print LOG $self->id, "  step $x $$\n";
      close(LOG);
      sleep(1);
    }

    my $end_time = time;

    $self->duration( $end_time - $start_time );

    if ( int( rand(10) ) > 5 ) {
      $self->error('An error has occured');
    }

    $self->status_update('DONE');

    $self->queue->restore;
    $self->queue->run;

    exit();
  }

  # $self->status_update('RUNNING');

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

sub as_hash {

  my $self = shift;

  my %hash = ();

  foreach my $key ( $self->meta->get_attribute_list ) {
    my $value = $self->$key;

    # take only simple scalar and not refs of any sort
    next if ref($value);
    $hash{$key} = $value;
  }

  $hash{citekey}  = $self->pub->citekey;
  $hash{title}    = $self->pub->title;
  $hash{citation} = $self->pub->_citation_display;
  $hash{authors}  = $self->pub->_authors_display;

  return {%hash};

}

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

    $self->progress_update("Searching $plugin");

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

  $self->progress_update("Searching PDF on publisher site.");

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

  $self->progress_update("Downloading PDF");

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
