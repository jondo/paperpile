package PaperPile::Utils;
use Moose;
use Moose::Util::TypeConstraints;
use Carp;
use LWP;
use Data::Dumper;
use FindBin;
$Data::Dumper::Indent = 1;

sub get_browser{
  my $browser = LWP::UserAgent->new;
  $browser->proxy('http', 'http://localhost:8146/');
  $browser->cookie_jar({});
  $browser->agent('Mozilla/5.0');
  return $browser;
}

=pod
=head1 get_config()

Gives access to config data when $c is not available

=cut

sub get_config{

  my $conf = Config::General->new($FindBin::Bin."/../paperpile.conf");

  return $conf->get_all;

}


1;
