
# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.



package Paperpile::PdfCrawler;
use Moose;
use Moose::Util::TypeConstraints;
use Carp;
use LWP;
use HTML::Entities;
use HTML::LinkExtor;
use HTML::TreeBuilder;
use XML::Simple;
use URI::URL;
use Encode;
use Data::Dumper;
use Config::Any;
use Paperpile::Utils;
use Paperpile::Exceptions;
use Paperpile::PdfUserAgent;

use YAML;

$Data::Dumper::Indent = 1;

has 'driver_file' => (
  is  => 'rw',
  isa => 'Str'
);

has '_driver'  => ( is => 'rw', isa => 'HashRef' );
has 'browser' => ( is => 'rw', isa => 'LWP::UserAgent' );
has 'debug'    => ( is => 'rw', isa => 'Bool', default => 1 );
has '_cache'   => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

# Allows to update status information for queue task.
has 'jobid' => ( is => 'rw', default => undef );


sub BUILD {

  my $self = shift;
  $self->browser( Paperpile::Utils->get_browser );

  # Bless the browser object as a customized Paperpile useragent
  bless $self->browser,"Paperpile::PdfUserAgent";
  # Store a reference to ourselves within the customized browser object.
  $self->browser->crawler($self);
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
    #CrawlerError->throw(error=>'PDF not found. Error in driver file.',
    #                    url => $URL,
    #                   );

    die("PDF not found. Error in driver file.");

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

    # $file is a URI:http at this point, return with " " to transfrom
    # it to string
    return "$file";
  }
}

## Finds the site drive for the given URL
## Return undef if no driver can be found

sub _identify_site {

  ( my $self, my $URL ) = @_;

  my $driver = $self->_driver;

  my $original_url = $URL;
  my $body         = '';

  # First, we search only the current URL for a match against the driver.
  # But this is usually fruitless, as the initial URL is normally a dx.doi.org.
  # Next, we request the page contents and use BOTH the new URL and the new
  # page contents as targets for pattern matching.
  for my $target ( 'URL', 'page' ) {

    if ( $target eq 'page' ) {

      # Request the page, and load the body and new URL. This only needs to happen once.
      my $response = $self->_get_location($URL);
      $body = $response->content;
      $URL  = $response->request->uri;
    }

    # Update the status returned back to the front-end.
    # Note that this only shows up during the actual regex matching -- during any
    # page requests made using _get_location, the message will be set within that
    # method to something like  "Fetching from xyz..."
    Paperpile::Utils->update_job_info(
      $self->jobid, 'msg',
      "Searching $target for PDF...",
      "PDF download canceled"
    );

    foreach my $site ( @{ $driver->{site} } ) {

      # We load both the URL and body patterns, but keep them independent.
      my @url_patterns  = ();
      my @body_patterns = ();
      push @body_patterns, @{ $site->{signature}->{body} }
        if ( defined $site->{signature}->{body} );
      push @url_patterns, @{ $site->{signature}->{url} } if ( defined $site->{signature}->{url} );

      foreach my $pair ( ( [ \@url_patterns, $URL ], [ \@body_patterns, $body ] ) ) {
        my @arr      = @$pair;
        my @patterns = @{ $arr[0] };
        my $target   = $arr[1];
        foreach my $pattern (@patterns) {

          # At this point, $target is either the page URL or the body contents,
          # which is an empty string if the page body hasn't been loaded yet.

          $pattern = $self->_resolve_pattern($pattern);

          #print STDERR "Matching $URL vs. $pattern. " if $self->debug;

          $pattern =~ s/!//g;

          my $match = 0;
          $match = 1 if ( $target =~ m!($pattern)! );

          if ($match) {

            # save resolved URL for downstream use to avoid doing this again.
            $site->{final_url} = $URL;
            print STDERR "Match. Using driver " . $site->{name} . "\n" if $self->debug;
            return $site;
          } else {
            #print STDERR "No match. \n" if $self->debug;
          }
        }
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

  my $msg = "Locating PDF on " . $self->_short_domain($URL). "...";

  Paperpile::Utils->update_job_info( $self->jobid, 'msg', $msg, "PDF download canceled" );

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

## Returns a (possibly) shortened version of the domain base of the given URL.
## Used for front-end status message.
sub _short_domain {
  my ($self, $url) = @_;

  my $full_domain = Paperpile::Utils->domain_from_url($url);

  my $limit = 16;
  my $short_domain = ( length($full_domain) > $limit ) ?
	substr($full_domain, 0,$limit) : $full_domain;
  return $short_domain;
}

## Wrapper around LWP, adds simple cache and error handling

sub _get_location {

  my ( $self, $URL ) = @_;

  if ( $self->_cache->{$URL} ) {
    return $self->_cache->{$URL};
  }

  my $domain = $self->_short_domain($URL);
  my $msg    = "Fetching from $domain...";

  # Custom message for DOI resolution.
  $msg = "Resolving DOI..." if ( $domain =~ /doi\.org/i );
  Paperpile::Utils->update_job_info( $self->jobid, 'msg', $msg, "PDF download canceled" );

  # Keep a list of all URLs we're redirected through, for caching purposes.
  my %url_keys;
  $url_keys{$URL} = 1;

  my $response = $self->browser->request(
    HTTP::Request->new( GET => $URL ),
    sub {
      my ( $data, $response, $protocol ) = @_;

      # As the resonse is being retrieved, we may get redirected.
      # Update the status message to reflect the current URL base,
      # so we show the progress through each of the redirects.
      my $cur_url = $response->base;
      if ( $cur_url ne $URL ) {
        $url_keys{$cur_url} = 1;
        my $cur_domain = $self->_short_domain($cur_url);
        Paperpile::Utils->update_job_info(
          $self->jobid, 'msg',
          "Fetching from $cur_domain...",
          "PDF download canceled"
        );
      }

      $response->content( $response->content . $data );
    }
  );

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'Network error while downloading PDF: ' . $response->message,
      code  => $response->code
    );
  }

  # Cache the response, keyed by the request URL and any URLs we were
  # redirected through.
  foreach my $key ( keys %url_keys ) {
    $self->_cache->{$key} = $response;
  }

  return $response;
}



sub check_pdf {

  ( my $self, my $url ) = @_;
  my $max_content = 64;

  # get only the start of the file and stop after $max_content
  my $content  = '';
  my $response = $self->browser->get(
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

  my $response = $self->browser->get($url);
  open( PDF, ">$file" );
  binmode(PDF);
  print PDF $response->content;

  return 1;

}

1;
