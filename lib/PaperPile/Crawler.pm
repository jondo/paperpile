package PaperPile::Crawler;
use Moose;
use Moose::Util::TypeConstraints;
use Carp;
use LWP;
use HTML::Entities;
use HTML::LinkExtor;
use HTML::TreeBuilder;
use XML::Simple;
use URI::URL;
use URI::Split qw(uri_split uri_join);
use Encode;
use Data::Dumper;

use PaperPile::Utils;

$Data::Dumper::Indent = 1;

has 'driver_file' => (
  is  => 'rw',
  isa => 'Str'
);

has '_driver'  => ( is => 'rw', isa => 'HashRef' );
has '_browser' => ( is => 'rw', isa => 'LWP::UserAgent' );
has 'debug' => ( is => 'rw', isa => 'Bool', default => 1 );

sub BUILD {

  my $self     = shift;
  $self->_browser(PaperPile::Utils->get_browser);

}

sub search_file {

  ( my $self, my $URL ) = @_;

  my $site_rules = $self->_match_site($URL);

  if ( not @$site_rules ) {
    croak('No driver found for URL $url.');
  }

  my $ruleCount=1;

  foreach my $rule (@{$site_rules}){

    print "Rule $ruleCount\n" if $self->debug;

    my $currURL=$URL;

    my $stepCount=1;

    foreach my $step (@{$rule->{pattern}}){
      print "Step $stepCount\n" if $self->debug;
      $currURL=$self->_followURL($currURL, $step);
      if (not defined $currURL){
        print "Error in process...\n";
        last;
      }
      $stepCount++;
    }

    if (defined $currURL){
      print "Got $currURL.\n" if $self->debug;
      last;
    } else {
      print "Could not find PDF.\n" if $self->debug;
    }
  }
  $ruleCount++;

}

sub _match_site {

  ( my $self, my $URL ) = @_;

  my $driver = $self->_driver;

  # first match all patterns against the URL

  my $original_url=$URL;

  for my $run ('original','redirected'){

    if ($run eq 'redirected'){
      my $response = $self->_browser->get($URL);
      $URL=$response->request->uri;
    }

    foreach my $siteName ( keys %{ $driver->{site} } ) {

      my $pattern = $driver->{site}->{$siteName}->{signature}->[0]->{url}->[0];

      $pattern =~ s/!//g;

      if ( $URL =~ m!($pattern)! ) {
        return $driver->{site}->{$siteName}->{rule};
      }
    }
  }

  return [];

}

sub load_driver {

  my $self = shift;

  open( XML, "<" . $self->driver_file )
    or croak( "Could not open driver file " . $self->driver_file );
  my $content = '';
  $content .= $_ foreach (<XML>);
  $self->_driver( XMLin( $content, ForceArray => 1 ) );

}

sub _followURL {
  ( my $self, my $URL, my $rule ) = @_;
  my $newURL = $URL;

  my $match   = $rule->{match}->[0];
  my $rewrite = $rule->{rewrite}->[0];

  # If nothing is specified, just return the original URL;
  # Useful at the start with the first URL.
  if ( ( not $match ) and ( not $rewrite ) ) {
    print "Nothing todo for $URL...\n" if $self->debug;
    return $newURL;
  }

  if ($match) {
    $newURL = matchURL( $URL, $match );
    return undef if ( not defined $newURL );
  }

  if ($rewrite) {
    $newURL = $self->_rewriteURL( $newURL, $rewrite );
  }

  return $newURL;

}

sub _matchURL {

  ( my $self, my $URL, my $pattern ) = @_;
  my $response = $self . _browser->get($URL);

  my $content = $response->content;
  $content =~ s/\n//g;
  my $tmp = time;
  open( FILE, ">$tmp.html" );
  print FILE $content;

  $pattern =~ s/!//g;

  print "Trying to match pattern $pattern in content of $URL...\n" if $self->debug;

  if ( $content =~ m!($pattern)! ) {
    print "..and found $1...\n" if $self->debug;
    return URI->new_abs( $1, $response->base );
  }
  else {
    croak "..but did not find anything...\n";
  }

}

sub _rewriteURL {

  ( my $self, my $URL, my $pattern ) = @_;

  my $newURL = $URL;

  my $command = '$newURL=~s' . $pattern;

  eval($command);

  if ($newURL eq $URL){
    croak 'Rewrite rule did not match';
  }

  print "Rewrote $URL to $newURL...\n" if $self->debug;

  return $newURL;

}

1;
