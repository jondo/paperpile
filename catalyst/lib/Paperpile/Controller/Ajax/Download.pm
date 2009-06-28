package Paperpile::Controller::Ajax::Download;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Utils;
use Paperpile::Library::Publication;
use Paperpile::Crawler;
use Data::Dumper;
use LWP::UserAgent ();
use LWP::MediaTypes qw(guess_media_type media_suffix);
use URI ();
use HTTP::Date ();
use File::Path;
use File::Spec;
use File::Copy;

use File::stat;
use 5.010;


sub search : Local {
  my ( $self, $c ) = @_;

  my $grid_id      = $c->request->params->{grid_id};
  my $sha1         = $c->request->params->{sha1};
  my $grid         = $c->session->{"grid_$grid_id"};
  my $url          = $c->request->params->{linkout};
  my $match_plugin = $c->request->params->{plugin};

  my $pub = $grid->find_sha1($sha1);

  if ( !$url and $match_plugin ) {
    my $plugin_module = "Paperpile::Plugins::Import::" . $match_plugin;
    my $plugin        = eval( "$plugin_module->" . 'new()' );

    eval { $pub = $plugin->match($pub); };

    my $e;

    if ( $e = Exception::Class->caught ) {
      if ( $e = Exception::Class->caught('NetMatchError') ) {
        NetMatchError->throw("Could not find PDF via $match_plugin");
      } else {
        $e = Exception::Class->caught();
        ref $e ? $e->rethrow : die $e;
      }
    }

    if ( !$pub->linkout ) {
      NetMatchError->throw("Found paper at $match_plugin but no PDF link is given.");
    }
    $url = $pub->linkout;
  }

  my $crawler = Paperpile::Crawler->new;
  $crawler->debug(1);
  $crawler->driver_file( $c->path_to( 'data', 'pdf-crawler.xml' )->stringify );
  $crawler->load_driver();
  my $pdf = $crawler->search_file($url);

  print STDERR Dumper($pdf);

  $c->stash->{pdf} = "$pdf";

}

sub get : Local {
  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $sha1    = $c->request->params->{sha1};
  my $plugin  = $c->session->{"grid_$grid_id"};
  my $url     = $c->request->params->{url};

  my $pub = $plugin->find_sha1($sha1);

  my $tmp_dir = $c->model('User')->get_setting('tmp_dir');
  my $dir     = "$tmp_dir/download/$sha1";

  rmtree($dir);
  mkpath($dir)
    or FileWriteError->throw(
    error => 'Download error. Could not create temporary dir for download.',
    file  => $dir
    );
  my $file = "$dir/paper.pdf";

  my $ua = Paperpile::Utils->get_browser();

  my $res = $ua->request(
    HTTP::Request->new( GET => $url ),
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
    NetGetError->throw(error => 'Download error.',
                       code => $res->code,
                      );
  }

  # Check if we have got really a PDF and not a "Access denied" screen
  close(FILE);
  open(FILE, "<$file");
  binmode(FILE);
  my $content;
  read( FILE, $content, 64 );

  if ( $content !~ m/^\%PDF/ ) {
    rmtree($dir);
    NetGetError->throw('Could not download PDF. Your institution might need a subscription for the journal.');
  }

  $c->stash->{pdf} = $file;

}

sub finish : Local{
  my ( $self, $c ) = @_;
  my $source_id = $c->request->params->{source_id};
  my $sha1      = $c->request->params->{sha1};

  my $source = $c->session->{"source_$source_id"};
  my $pub = $source->find_sha1($sha1);

  my $tmp_dir=$c->model('User')->get_setting('tmp_dir');
  my $tmp_file="$tmp_dir/download/$sha1/paper.pdf";

  my $root=$pub->format($c->model('Library')->get_setting('paper_root'));
  my $pattern=$pub->format($c->model('Library')->get_setting('paper_pattern'));

  my $dest=	File::Spec->catfile($root, $pattern).".pdf";

  my ($volume,$dirs,$file) = File::Spec->splitpath( $dest );

  mkpath($dirs);
  copy($tmp_file, $dest);

  $c->model('Library')->update_field('Publications',$pub->_rowid, 'pdf', $dest);

  $c->stash->{pdf_file} = "$dest";
  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub progress : Local {
  my ( $self, $c ) = @_;

  my $sha1  = $c->request->params->{sha1};

  my $tmp_dir=$c->model('User')->get_setting('tmp_dir');

  my $file="$tmp_dir/download/$sha1/paper.pdf";

  my $current_size;
  my $total_size;

  if (-e $file){
    $current_size=stat($file)->size;
    open(SIZE,"<$file.size");
    $total_size=<SIZE>;
    chomp($total_size);
  } else {
    $current_size=0;
    $total_size=undef;
  }

  $c->stash->{success} = \1;
  $c->stash->{current_size} = $current_size;
  $c->stash->{total_size} = $total_size;
  $c->forward('Paperpile::View::JSON');

}

1;
