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
use Config::Any;
use PaperPile::Utils;

use YAML;

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

## Tries to get the PDF link for the given URL;
## Returns undef if no PDF could be found

sub search_file {

  ( my $self, my $URL ) = @_;

  my $driver = $self->_identify_site($URL);

  if ( not $driver ) {
    carp('No driver found.');
    return undef;
  }

  my $site_rules = $driver->{rule};

  if ( not @$site_rules ) {
    carp('No rules specified in driver.');
    return undef;
  }

  # Take the redirected URL (if redirection has taken place)
  $URL = $driver->{final_url};

  my $file = undef;

  my $ruleCount = 1;

  foreach my $rule ( @{$site_rules} ) {

    print STDERR "\n Applying rule $ruleCount\n" if $self->debug;

    my $currURL = $URL;

    my $stepCount = 1;

    foreach my $step ( @{ $rule->{pattern} } ) {
      print STDERR "  Step $stepCount\n" if $self->debug;
      $currURL = $self->_followURL( $currURL, $step );
      if ( not defined $currURL ) {
        print STDERR "  Rule $ruleCount not successful...\n" if $self->debug;
        last;
      }
      $stepCount++;
    }

    if ( defined $currURL ) {
      print STDERR "    Got $currURL.\n" if $self->debug;
      $file = $currURL;
      last;
    }
    else {
      print STDERR "  Could not find PDF.\n" if $self->debug;
    }
    $ruleCount++;
  }
  return $file;
}

## Finds the site drive for the given URL
## Return undef if no driver can be found

sub _identify_site {

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
       @{ $driver->{site}->{$siteName}->{signature}->{url} } )
      {

        print STDERR "Matching $URL vs. $pattern. " if $self->debug;

        $pattern =~ s/!//g;

        if ( $URL =~ m!($pattern)! ) {

          # save resolved URL for downstream use to avoid doing this again.
          $driver->{site}->{$siteName}->{final_url} = $URL;
          print STDERR "Match. Using driver $siteName.\n" if $self->debug;
          return $driver->{site}->{$siteName};
        }
        else {
          print STDERR "No match. \n" if $self->debug;
        }
      }
    }
  }

  # if we haven't found a signature in the url, we check the content of the page

  my $response = $self->_browser->get($URL);
  my $body     = $response->content;
  $URL = $response->request->uri;

  foreach my $siteName ( keys %{ $driver->{site} } ) {
    foreach my $pattern (
      @{ $driver->{site}->{$siteName}->{signature}->[0]->{body} } )
    {

      print STDERR "Matching page content vs. $pattern. " if $self->debug;

      $pattern =~ s/!//g;

      if ( $body =~ m!($pattern)! ) {
        $driver->{site}->{$siteName}->{final_url} = $URL;
        print STDERR "Match. Using driver $siteName.\n" if $self->debug;
        return $driver->{site}->{$siteName};
      }
      else {
        print STDERR "No match. \n" if $self->debug;
      }
    }
  }

  # if we haven't found anything by now, we give up

  return undef;

}

## Function to get from one URL to the next;
## either rewrite the URL, find the new URL by pattern 
## matching in the content of the page; or do both (or 
## nothing at all)

sub _followURL {
  ( my $self, my $URL, my $rule ) = @_;
  my $newURL = $URL;

  my $match   = $rule->{match};
  my $rewrite = $rule->{rewrite};

  # If nothing is specified, just return the original URL;
  # Useful at the start with the first URL.
  if ( ( not $match ) and ( not $rewrite ) ) {
    print STDERR "  Nothing todo for $URL...\n" if $self->debug;
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

## function to match URL (see _followURL for description)

sub _matchURL {

  ( my $self, my $URL, my $pattern ) = @_;

  my $response = $self->_browser->get($URL);

  my $content = $response->content;
  $content =~ s/\n//g;
  my $tmp = time;
  #open( FILE, ">$tmp.html" );
  #print FILE $content;

  $pattern =~ s/!//g;

  print STDERR "    Trying to match pattern $pattern in content of $URL...\n"
    if $self->debug;

  if ( $content =~ m!$pattern! ) {
    my $match = $1;
    print STDERR "    ..and found $match...\n" if $self->debug;
    return URI->new_abs( $match, $response->base );
  }
  else {
    print STDERR "    ..but did not find anything...\n" if $self->debug;
    return undef;
  }

}

## function to rewrite URL (see _followURL for description)

sub _rewriteURL {

  ( my $self, my $URL, my $pattern ) = @_;

  my $newURL = $URL;

  my $command = '$newURL=~s' . $pattern;

  eval($command);

  if ($@) {
    print STDERR "  Error in pattern: $@";
    return undef;
  }

  if ( $newURL eq $URL ) {
    print STDERR "    Rewrite rule did not match: $pattern on $URL\n" if $self->debug;
    return undef;
  }

  print STDERR "    Rewrote $URL to $newURL...\n" if $self->debug;

  return $newURL;

}

## Loads driver from XML file
sub load_driver {

  my $self = shift;

  open( XML, "<" . $self->driver_file )
    or croak( "Could not open driver file " . $self->driver_file );
  my $content = '';
  $content .= $_ foreach (<XML>);
  $self->_driver( XMLin( $content, ForceArray => ['url','body','rule','pattern','site'] ) );

  open(YAML,">/home/wash/play/PaperPile/catalyst/t/data/driver.yml");
  print YAML YAML::Dump($self->_driver);

  #print Dumper($cfg);


}

## Return test cases
sub get_tests {

  my $self = shift;

  my $driver = $self->_driver;

  my $tests = {};

  foreach my $siteName ( keys %{ $driver->{site} } ) {
    my @tmp = ();
    foreach my $test ( @{ $driver->{site}->{$siteName}->{test}->{url} } ) {
      push @tmp, $test;
    }
    $tests->{$siteName} = [@tmp];
  }

  return $tests;
}

sub check_pdf {

  ( my $self, my $url ) = @_;
  my $max_content = 64;

  # get only the start of the file and stop after $max_content
  my $content  = '';
  my $response = $self->_browser->get(
    $url,
    ':content_cb' => sub {
      my ( $data, $response, $protocol ) = @_;
      $content .= $data;
      die if length( $response > $max_content );
      return ();
    },
    $max_content + 1
  );

  if ( $content !~ m/^\%PDF/ ) {
    return 0;
  }
  else {
    return 1;
  }

}

## Download the PDF file given in $url to file $file
## For testing purpose only

sub fetch_pdf {

  ( my $self, my $url, my $file ) = @_;

  my $response = $self->_browser->get($url);
  open( PDF, ">$file" );
  binmode(PDF);
  print PDF $response->content;

  return 1;

}

1;
