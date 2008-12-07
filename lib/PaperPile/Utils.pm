package PaperPile::Utils;
use Moose;
use Moose::Util::TypeConstraints;
use Carp;
use LWP;
use Data::Dumper;
$Data::Dumper::Indent = 1;

sub get_browser{
  my $browser = LWP::UserAgent->new;
  $browser->proxy('http', 'http://localhost:8146/');
  $browser->cookie_jar({});
  $browser->agent('Mozilla/5.0');
  return $browser;
}



1;
