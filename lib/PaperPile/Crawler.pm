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
has 'debug'    => ( is => 'rw', isa => 'Bool', default => 1 );

sub BUILD {

  my $self = shift;
  $self->_browser( PaperPile::Utils->get_browser );

}

sub search_file {

  ( my $self, my $URL ) = @_;

  my $driver = $self->_match_site($URL);

  if ( not $driver ) {
    croak('No driver found.');
  }

  my $site_rules = $driver->{rule};

  if ( not @$site_rules ) {
    croak('No rules specified in driver.');
  }

  # Take the redirected URL (if redirection has taken place)
  $URL = $driver->{final_url};

  my $file = undef;

  my $ruleCount = 1;

  foreach my $rule ( @{$site_rules} ) {

    print "\n Applying rule $ruleCount\n" if $self->debug;

    my $currURL = $URL;

    my $stepCount = 1;

    foreach my $step ( @{ $rule->{pattern} } ) {
      print "  Step $stepCount\n" if $self->debug;
      $currURL = $self->_followURL( $currURL, $step );
      if ( not defined $currURL ) {
        print "  Rule $ruleCount not successful...\n" if $self->debug;
        last;
      }
      $stepCount++;
    }

    if ( defined $currURL ) {
      print "    Got $currURL.\n" if $self->debug;
      $file = $currURL;
      last;
    }
    else {
      print "  Could not find PDF.\n" if $self->debug;
    }
    $ruleCount++;
  }
  return $file;
}

sub fetch_pdf {

  ( my $self, my $url, my $file ) = @_;

  my $response = $self->_browser->get($url);
  open( PDF, ">$file" );
  binmode(PDF);
  print PDF $response->content;

  if ( $self->_check_pdf("$file") ) {
    return 1;
  }
  else {
    print "  Downloaded file not a PDF.\n" if $self->debug;
    return 0;
  }
}

sub _match_site {

  ( my $self, my $URL ) = @_;

  my $driver = $self->_driver;

  # first match all patterns against the URL

  my $original_url = $URL;

  for my $run ( 'original', 'redirected' ) {

    if ( $run eq 'redirected' ) {
      my $response = $self->_browser->get($URL);
      $URL = $response->request->uri;
    }

    foreach my $siteName ( keys %{ $driver->{site} } ) {
      foreach my $pattern (
        @{ $driver->{site}->{$siteName}->{signature}->[0]->{url} } )
      {

        print "Matching $URL vs. $pattern. " if $self->debug;

        $pattern =~ s/!//g;

        if ( $URL =~ m!($pattern)! ) {
          # save resolved URL for downstream use to avoid doing this again.
          $driver->{site}->{$siteName}->{final_url} = $URL;
          print "Match. \n" if $self->debug;
          return $driver->{site}->{$siteName};
        } else {
          print "No match. \n" if $self->debug;
        }


      }
    }
  }

  return undef;

}

sub load_driver {

  my $self = shift;

  open( XML, "<" . $self->driver_file )
    or croak( "Could not open driver file " . $self->driver_file );
  my $content = '';
  $content .= $_ foreach (<XML>);
  $self->_driver( XMLin( $content, ForceArray => 1 ) );

}

sub get_tests {

  my $self = shift;

  my $driver = $self->_driver;

  my $tests = {};

  foreach my $siteName ( keys %{ $driver->{site} } ) {
    my @tmp = ();
    foreach my $test ( @{ $driver->{site}->{$siteName}->{test}->[0]->{url} } ) {
      push @tmp, $test;
    }
    $tests->{$siteName} = [@tmp];
  }

  return $tests;
}

sub _followURL {
  ( my $self, my $URL, my $rule ) = @_;
  my $newURL = $URL;

  my $match   = $rule->{match}->[0];
  my $rewrite = $rule->{rewrite}->[0];

  # If nothing is specified, just return the original URL;
  # Useful at the start with the first URL.
  if ( ( not $match ) and ( not $rewrite ) ) {
    print "  Nothing todo for $URL...\n" if $self->debug;
    return $newURL;
  }

  if ($match) {
    $newURL = $self->_matchURL( $URL, $match );
    return undef if ( not defined $newURL );
  }

  if ($rewrite) {
    $newURL = $self->_rewriteURL( $newURL, $rewrite );
  }

  return $newURL;

}

sub _matchURL {

  ( my $self, my $URL, my $pattern ) = @_;

  my $response = $self->_browser->get($URL);

  my $content = $response->content;
  $content =~ s/\n//g;
  my $tmp = time;
  open( FILE, ">$tmp.html" );
  print FILE $content;

  $pattern =~ s/!//g;

  print "    Trying to match pattern $pattern in content of $URL...\n"
    if $self->debug;

  if ( $content =~ m!$pattern! ) {
    my $match=$1;
    print "    ..and found $match...\n" if $self->debug;
    return URI->new_abs( $match, $response->base);
  }
  else {
    print "    ..but did not find anything...\n" if $self->debug;
    return undef;
  }

}

sub _rewriteURL {

  ( my $self, my $URL, my $pattern ) = @_;

  my $newURL = $URL;

  my $command = '$newURL=~s' . $pattern;

  eval($command);

  if ($@){
    print "  Error in pattern: $@";
    return undef;
  }

  if ( $newURL eq $URL ) {
    print "    Rewrite rule did not match: $pattern on $URL\n" if $self->debug;
    return undef;
  }

  print "    Rewrote $URL to $newURL...\n" if $self->debug;

  return $newURL;

}

sub _check_pdf {

  ( my $self, my $file ) = @_;

  open( INFILE, "<$file" );
  binmode( INFILE, ':raw' );
  seek( INFILE, 0, 0 );
  my $buf;
  read( INFILE, $buf, 255 );

  if ( $buf !~ m/^\%PDF/ ) {
    return 0;
  }
  else {
    return 1;
  }
}

1;
