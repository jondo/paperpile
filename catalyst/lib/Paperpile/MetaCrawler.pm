
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



package Paperpile::MetaCrawler;
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
use Paperpile::MetaCrawler::Targets;

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

# Allows to update status information for queue task.
has 'jobid' => ( is => 'rw', default => undef );

sub BUILD {

  my $self = shift;
  $self->_browser( Paperpile::Utils->get_browser );

}

sub search_file {

  ( my $self, my $URL ) = @_;

  my $driver = $self->_identify_site($URL);

  if ( not $driver ) {
    CrawlerUnknownSiteError->throw(
      error => 'Could not find bibliographic data. Publisher site not supported.',
      url   => $URL,
    );
  }

  my $site_rules = $driver->{rule};

  if ( not @$site_rules ) {
    die("Could not find bibliographic data. Error in driver file.");
  }

  # Take the redirected URL (if redirection has taken place)
  $URL = $driver->{final_url};

  my $content_url = undef;
  my $target      = undef;

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
      $content_url = $currURL;
      $target      = $rule->{target};
      last;
    } else {
      print STDERR "  Could not find target.\n" if $self->debug;
    }
    $ruleCount++;
  }

  if ( !defined $content_url ) {
    CrawlerScrapeError->throw("Could not find bibliographic data.");
  } else {

    my $response = $self->_get_location($content_url);
    my $content  = $response->content;

    my $module = "Paperpile::MetaCrawler::Targets::$target";
    my $m      = eval("use $module; $module->new()");

    print STDERR $@ if $@;

    return $m->convert($content, $content_url);

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
  $self->_driver( XMLin( $content, ForceArray => ['url','body','rule','pattern','site','page'] , KeyAttr => {namedRegex=>'name'}) );

}

## Return test cases
sub get_tests {

  my $self = shift;

  my $driver = $self->_driver;

  my $tests = {};

  foreach my $site ( @{$driver->{site} } ) {
    my @tmp = ();
    foreach my $test ( @{ $site->{test}->{page} } ) {
      push @tmp, $test;
    }
    $tests->{$site->{name}} = [@tmp];
  }

  return $tests;
}

## Wrapper around LWP, adds simple cache and error handling

sub _get_location {

  my ( $self, $URL ) = @_;

  if ( $self->_cache->{$URL} ) {
    return $self->_cache->{$URL};
  }

  my $domain = Paperpile::Utils->domain_from_url($URL);

  my $msg = "Waiting for $domain...";

  if ( $domain =~ /doi\.org/ ) {
    $msg = "Resolving DOI...";
  }

  my $response = $self->_browser->request(
    HTTP::Request->new( GET => $URL ),
    sub {
      my ( $data, $response, $protocol ) = @_;
      $response->content( $response->content . $data );
      Paperpile::Utils->update_job_info( $self->jobid, 'msg', $msg, "Meta-data lookup canceled." );
    }
  );

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'Network error while downloading bibliographic data: ' . $response->message,
      code  => $response->code
    );
  }

  $self->_cache->{$URL} = $response;

  return $response;
}




1;
