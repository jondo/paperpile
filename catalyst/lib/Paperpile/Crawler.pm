package Paperpile::Crawler;
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
use Paperpile::Utils;
use Paperpile::Exceptions;

use YAML;

$Data::Dumper::Indent = 1;

has 'driver_file' => (
  is  => 'rw',
  isa => 'Str'
);

has '_driver'  => ( is => 'rw', isa => 'HashRef' );
has '_browser' => ( is => 'rw', isa => 'LWP::UserAgent' );
has 'debug'    => ( is => 'rw', isa => 'Bool', default => 1 );
has '_cache'   => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

sub BUILD {

  my $self = shift;
  $self->_browser( Paperpile::Utils->get_browser );

}


## Tries to get the PDF link for the given URL;
## Returns undef if no PDF could be found

sub search_file {

  ( my $self, my $URL ) = @_;

  my $driver = $self->_identify_site($URL);

  if ( not $driver ) {
    CrawlerUnknownSiteError->throw(error=>'PDF not found. Publisher site not supported.',
                                   url => $URL,
                                  );
  }

  my $site_rules = $driver->{rule};

  if ( not @$site_rules ) {
    # should not happen
    CrawlerError->throw(error=>'PDF not found. Error in driver file.',
                        url => $URL,
                       );
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

  if (!defined $file){
    CrawlerScrapeError->throw("Could not download PDF. Your institution might need a subscription for the journal.");
  } else {

    return $file;
  }
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
      my $response = $self->_get_location($URL);
      $URL = $response->request->uri;
    }

    foreach my $site ( @{ $driver->{site} } ) {
      foreach my $pattern ( @{ $site->{signature}->{url} } ) {

        $pattern = $self->_resolve_pattern($pattern);

        print STDERR "Matching $URL vs. $pattern. " if $self->debug;

        $pattern =~ s/!//g;

        if ( $URL =~ m!($pattern)! ) {

          # save resolved URL for downstream use to avoid doing this again.
          $site->{final_url} = $URL;
          print STDERR "Match. Using driver " . $site->{name} . "\n" if $self->debug;
          return $site;
        } else {
          print STDERR "No match. \n" if $self->debug;
        }
      }
    }
  }

  # if we haven't found a signature in the url, we check the content of the page

  my $response = $self->_get_location($URL);
  my $body     = $response->content;
  $URL = $response->request->uri;

  #open( FILE, ">$$.html" );
  #print FILE $body;

  foreach my $site ( @{ $driver->{site} } ) {
    foreach my $pattern ( @{ $site->{signature}->{body} } ) {

      $pattern = $self->_resolve_pattern($pattern);

      print STDERR "Matching page content vs. $pattern. " if $self->debug;

      $pattern =~ s/!//g;

      if ( $body =~ m!($pattern)! ) {
        $site->{final_url} = $URL;
        print STDERR "Match. Using driver " . $site->{name} . "\n" if $self->debug;
        return $site;
      } else {
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

  my $match   = $self->_resolve_pattern($rule->{match});
  my $rewrite = $self->_resolve_pattern($rule->{rewrite});

  # If nothing is specified, just return the original URL;
  # Useful at the start with the first URL.
  if ( ( not $match ) and ( not $rewrite ) ) {
    print STDERR "  Nothing todo for $URL...\n" if $self->debug;
    return $newURL;
  }

  if ($match) {
    $newURL = $self->_matchURL( $URL, $match );
    # Decode &'s which are encoded in HTML
    if (defined $newURL){
      $newURL=~s/&amp;/&/g;
    } else {
      return undef;
    }
  }

  if ($rewrite) {
    $newURL = $self->_rewriteURL( $newURL, $rewrite );
  }

  return $newURL;

}

## function to match URL (see _followURL for description)

sub _matchURL {

  ( my $self, my $URL, my $pattern ) = @_;

  my $response = $self->_get_location($URL);

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

  open( XML, "<" . $self->driver_file ) or die( "Could not open driver file " . $self->driver_file );

  my $content = '';
  $content .= $_ foreach (<XML>);
  $self->_driver( XMLin( $content, ForceArray => ['url','body','rule','pattern','site'] , KeyAttr => {namedRegex=>'name'}) );

  #open(YAML,">/home/wash/play/Paperpile/catalyst/t/data/driver.yml");
  #print YAML YAML::Dump($self->_driver);
  #print Dumper($cfg);


}

## Return test cases
sub get_tests {

  my $self = shift;

  my $driver = $self->_driver;

  my $tests = {};

  foreach my $site ( @{$driver->{site} } ) {
    my @tmp = ();
    foreach my $test ( @{ $site->{test}->{url} } ) {
      push @tmp, $test;
    }
    $tests->{$site->{name}} = [@tmp];
  }

  return $tests;
}

## Looks up named RegExes and if necessary replaces the pattern with
## one from the list

sub _resolve_pattern {
  my ($self, $pattern) = @_;

  if (defined $pattern){
    if (ref ($pattern) eq 'HASH'){
      return $self->_driver->{patterns}->{namedRegex}->{$pattern->{namedRegex}}->{content};
    }
  }
  return $pattern;
}

## Wrapper around LWP, adds simple cache and error handling

sub _get_location {

  my ($self, $URL) = @_;

  if ($self->_cache->{$URL}){
    return $self->_cache->{$URL};
  }

  my $response=$self->_browser->get($URL);

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'Network error while downloading PDF: ' . $response->message,
      code  => $response->code
    );
  }

  $self->_cache->{$URL}=$response;

  return $response;
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
