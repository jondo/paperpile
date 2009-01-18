package PaperPile::Controller::Ajax::Download;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Utils;
use PaperPile::Library::Publication;
use PaperPile::Library::Source::File;
use PaperPile::Library::Source::DB;
use PaperPile::Library::Source::PubMed;
use PaperPile::PDFviewer;
use Data::Dumper;
use LWP::UserAgent ();
use LWP::MediaTypes qw(guess_media_type media_suffix);
use URI ();
use HTTP::Date ();
use File::Path;
use File::stat;
use 5.010;

sub get : Local {
  my ( $self, $c ) = @_;

  my $source_id = $c->request->params->{source_id};
  my $sha1      = $c->request->params->{sha1};
  my $source = $c->session->{"source_$source_id"};
  my $url        = $c->request->params->{url};

  my $pub = $source->find_sha1($sha1);

  my $dir="/home/wash/play/PaperPile/tmp/download/$sha1";
  my $list;
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
          print SIZE "unknown\n";
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

sub progress : Local {
  my ( $self, $c ) = @_;

  my $sha1  = $c->request->params->{sha1};

  my $dir="/home/wash/play/PaperPile/tmp/download/$sha1";
  my $file="$dir/paper.pdf";

  my $current_size=stat($file)->size;

  open(SIZE,"<$file.size");
  my $total_size=<SIZE>;
  chomp($total_size);

  $c->stash->{success} = 'true';
  $c->stash->{percent} = $current_size/$total_size;
  $c->forward('PaperPile::View::JSON');

}

1;
