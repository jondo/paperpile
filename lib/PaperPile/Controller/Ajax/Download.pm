package PaperPile::Controller::Ajax::Download;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Utils;
use PaperPile::Library::Publication;
use PaperPile::Crawler;
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

  my $source_id = $c->request->params->{source_id};
  my $sha1      = $c->request->params->{sha1};
  my $source = $c->session->{"source_$source_id"};
  my $url        = $c->request->params->{url};

  my $pub = $source->find_sha1($sha1);

  my $crawler=PaperPile::Crawler->new;
  $crawler->debug(1);
  $crawler->driver_file('/home/wash/play/PaperPile/t/data/driver.xml');
  $crawler->load_driver();
  my $pdf=$crawler->search_file($url);

  if (not defined $pdf){
    $pdf='null';
  }

  $c->stash->{success} = 'true';
  $c->stash->{pdf} = "$pdf";
  $c->forward('PaperPile::View::JSON');

}

sub get : Local {
  my ( $self, $c ) = @_;

  my $source_id = $c->request->params->{source_id};
  my $sha1      = $c->request->params->{sha1};
  my $source = $c->session->{"source_$source_id"};
  my $url        = $c->request->params->{url};

  my $pub = $source->find_sha1($sha1);

  my $tmp_dir=$c->model('DBI')->get_setting('tmp_dir');
  my $dir="$tmp_dir/download/$sha1";
  rmtree($dir);
  mkpath($dir);
  my $file="$dir/paper.pdf";

  my $ua=PaperPile::Utils->get_browser();
  my $res = $ua->request(HTTP::Request->new(GET => $url),
  sub{
      my ($data, $response, $protocol)=@_;
      if (not -e $file){
        my $length = $response->content_length;
        open(SIZE, ">$file.size");
        if (defined $length){
          print SIZE "$length\n";
        } else {
          print SIZE "null\n"; # Don't know size
        }
        close(SIZE);
        open(FILE, ">$file") || die "Can't open $file: $!\n";
        binmode FILE;
      } else {
        open(FILE, ">>$file") || die "Can't open $file: $!\n";
        binmode FILE;
      }
      print FILE $data or die "Can't write to $file: $!\n";
      close FILE;
      #select(undef, undef, undef, 0.05) # sleep 1/4 second;
    }
 );

  if (fileno(FILE)) {
    close(FILE) || die "Can't write to $file: $!\n";
     if ($res->header("X-Died") || !$res->is_success) {
       if (my $died = $res->header("X-Died")) {
         print STDERR "$died\n";
       }
     }
   } else {
     if (my $died = $res->header("X-Died")) {
       print STDERR "$died\n";
     }
   }

  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}

sub finish : Local{
  my ( $self, $c ) = @_;
  my $source_id = $c->request->params->{source_id};
  my $sha1      = $c->request->params->{sha1};

  my $source = $c->session->{"source_$source_id"};
  my $pub = $source->find_sha1($sha1);

  my $tmp_dir=$c->model('DBI')->get_setting('tmp_dir');
  my $tmp_file="$tmp_dir/download/$sha1/paper.pdf";

  my $root=$pub->format($c->model('DBI')->get_setting('paper_root'));
  my $pattern=$pub->format($c->model('DBI')->get_setting('paper_pattern'));

  my $dest=	File::Spec->catfile($root, $pattern).".pdf";

  my ($volume,$dirs,$file) = File::Spec->splitpath( $dest );

  mkpath($dirs);
  copy($tmp_file, $dest);

  $c->model('DBI')->update_field($pub->_rowid, 'pdf', $dest);


  $c->stash->{pdf_file} = "$dest";
  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}


sub progress : Local {
  my ( $self, $c ) = @_;

  my $sha1  = $c->request->params->{sha1};

  my $tmp_dir=$c->model('DBI')->get_setting('tmp_dir');

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
    $total_size='null';
  }

  $c->stash->{success} = 'true';
  $c->stash->{current_size} = $current_size;
  $c->stash->{total_size} = $total_size;
  $c->forward('PaperPile::View::JSON');

}

1;
