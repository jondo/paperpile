# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

package Paperpile::Controller::Ajax::Misc;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Utils;
use Data::Dumper;
use File::Spec;
use File::Path;
use File::Copy;
use Paperpile::Exceptions;
use MooseX::Timestamp;
use LWP;
use HTTP::Request::Common;
use File::Temp qw(tempfile);
use YAML qw(LoadFile);
use URI::Escape;
use JSON;

use 5.010;

sub reset_db : Local {

  my ( $self, $c ) = @_;

  $c->model('Library')->init_db( $c->config->{pub_fields}, $c->config->{user_settings} );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub tag_list : Local {

  my ( $self, $c ) = @_;

  my $tags = $c->model('Library')->get_tags;

  my @data = ();

  foreach my $row (@$tags) {
    push @data, {
      tag   => $row->{tag},
      style => $row->{style},
      };
  }

  my %metaData = (
    root   => 'data',
    fields => [ 'tag', 'style' ],
  );

  $c->stash->{data} = [@data];

  $c->stash->{metaData} = {%metaData};

  $c->forward('Paperpile::View::JSON');

}

sub _EscapeString {
  my $string = $_[0];

  # remove leading spaces
  $string =~ s/^\s+//;

  # remove spaces at the end
  $string =~ s/\s+$//;

  # escape each single word and finally join
  # with plus signs
  my @tmp = split( /\s+/, $string );
  foreach my $i ( 0 .. $#tmp ) {
    $tmp[$i] = uri_escape_utf8( $tmp[$i] );
  }

  return join( "+", @tmp );
}


sub feed_list : Local {
  my ( $self, $c ) = @_;
  my $query     = $c->request->params->{query};
  my $offset = $c->request->params->{start} || 0;
  my $limit = $c->request->params->{limit} || 10;

  $query = _EscapeString($query);

  my $searchUrl = 'http://stage.paperpile.com/api/v1/feeds/list/';

  my $full_uri = $searchUrl . '?query=' . $query;

  my $browser = Paperpile::Utils->get_browser;
  my $response     = $browser->get( $full_uri );
  my $content      = $response->content;

  my $json = new JSON;
  my $object = $json->decode ($content);
  my @feeds = @{$object->{feeds}};

  my $start_i = $offset;
  my $end_i = $offset + $limit;
  my @array = ();
  for (my $i=$start_i; $i < scalar @feeds; $i++) {
    last if ($i > $end_i);

    push @array, $feeds[$i];
  }

  my %metaData = (
    totalProperty => 'total_entries',
    root          => 'feeds',
    id            => 'name',
    fields        => ['name','url']
  );

  $c->stash->{feeds} = \@array;
  $c->stash->{total_entries} = scalar @feeds;
  $c->stash->{metaData} = {%metaData};

  $c->forward('Paperpile::View::JSON');
}

sub journal_list : Local {

  my ( $self, $c ) = @_;
  my $query     = $c->request->params->{query};
  my $query_bak = $c->request->params->{query};

  my $model = $c->model('App');

  $query = $model->dbh->quote("$query*");

  my $sth = $model->dbh->prepare(
    "SELECT Journals.short, Journals.long FROM Journals 
     JOIN Journals_lookup ON Journals.rowid=Journals_lookup.rowid 
     WHERE Journals_lookup MATCH $query
     ORDER BY Journals.short;"
  );

  my ( $short, $long );
  $sth->bind_columns( \$short, \$long );
  $sth->execute;

  # we process the raw SQL output in three ways
  # 1) On top we rank those hits that exactly match the query
  # 2) Next we take those hits that start with the query. These
  #    hits are then sorted by the second word in the short title
  # 3) anything else
  my @data     = ();
  my @quality1 = ();
  my @quality2 = ();

  while ( $sth->fetch ) {
    if ( $long =~ m/^$query_bak$/i ) {
      push @data, { long => $long, short => $short };
      next;
    }
    if ( $short =~ m/^$query_bak$/i ) {
      push @data, { long => $long, short => $short };
      next;
    }
    if ( $long =~ m/^$query_bak/i and $long !~ m/\s/ ) {
      push @data, { long => $long, short => $short };
      next;
    }
    if ( $long =~ m/^$query_bak/i ) {
      ( my $next_words = $short ) =~ s/(\S+\s)(\S+)/$2/;
      if ( $next_words =~ m/^\(/ ) {
        push @data, { long => $long, short => $short };
        next;
      }
      push @quality1, { long => $long, short => $short, next_words => $next_words };
      next;
    }
    push @quality2, { long => $long, short => $short };
  }

  my @sorted = sort { uc( $a->{'next_words'} ) cmp uc( $b->{'next_words'} ) } @quality1;
  foreach my $entry (@sorted) {
    push @data, $entry;
  }
  foreach my $entry (@quality2) {
    push @data, $entry;
  }

  $c->stash->{data} = [@data];
  $c->forward('Paperpile::View::JSON');

}

sub get_settings : Local {

  my ( $self, $c ) = @_;

  # app_settings are read from the config file, they are never changed
  # by the user and constant for a specific version of the application
  my @list1 = %{ $c->config->{app_settings} };

  my @list2 = %{ $c->model('User')->settings };
  my @list3 = %{ $c->model('Library')->settings };

  my %merged = ( @list1, @list2, @list3 );

  my $fields = LoadFile( $c->path_to('conf/fields.yaml') );

  foreach my $key ( 'pub_types', 'pub_fields', 'pub_tooltips', 'pub_identifiers' ) {
    $merged{$key} = $fields->{$key};
  }

  $c->stash->{data} = {%merged};

  $c->forward('Paperpile::View::JSON');

}

sub test_network : Local {

  my ( $self, $c ) = @_;

  my $cancel_handle = $c->request->params->{cancel_handle};

  Paperpile::Utils->register_cancel_handle($cancel_handle);

  #for my $i (0..15){
  #  print STDERR "$i ";
  #  last if Paperpile::Utils->check_cancel($$);
  #  sleep(1);
  #}

  my $browser = Paperpile::Utils->get_browser( $c->request->params );

  my $response = $browser->get('http://google.com');

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'Error: ' . $response->message,
      code  => $response->code
    );
  }

  Paperpile::Utils->clear_cancel($$);

}

sub cancel_request : Local {

  my ( $self, $c ) = @_;

  my $cancel_handle = $c->request->params->{cancel_handle};
  my $kill = $c->request->params->{kill};

  $kill=0 if not defined $kill;

  Paperpile::Utils->activate_cancel_handle($cancel_handle, $kill);

}


sub clean_duplicates : Local {
  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};
  my $plugin  = $c->session->{"grid_$grid_id"};
}

sub inc_read_counter : Local {

  my ( $self, $c ) = @_;
  my $rowid      = $c->request->params->{rowid};
  my $sha1       = $c->request->params->{sha1};
  my $times_read = $c->request->params->{times_read};

  my $touched = timestamp gmtime;
  $c->model('Library')
    ->dbh->do(
    "UPDATE Publications SET times_read=times_read+1,last_read='$touched' WHERE rowid=$rowid");

  $c->stash->{data} =
    { pubs => { $sha1 => { last_read => $touched, times_read => $times_read + 1 } } };

}

sub report_crash : Local {

  my ( $self, $c ) = @_;

  #my $url ='http://127.0.0.1:3003/api/v1/feedback/crashreport';

  my $url = 'http://stage.paperpile.com/api/v1/feedback/crashreport';

  my $error        = $c->request->params->{info};
  my $catalyst_log = $c->request->params->{catalyst_log};

  my $browser = Paperpile::Utils->get_browser();

  my $version_name = $c->config->{app_settings}->{version_name};
  my $version_id   = $c->config->{app_settings}->{version_id};
  my $build_number = $c->config->{app_settings}->{build_number};
  my $platform     = $c->config->{app_settings}->{platform};

  my $subject =
    "Unknown exception on $platform;  version: $version_id ($version_name); build: $build_number";

  #TODO: Make sure that explicit /tmp is portable on MacOSX and Windows
  my ( $fh, $filename ) = tempfile( "catalyst-XXXXX", DIR=> '/tmp', SUFFIX => '.txt' );

  my $attachment = undef;

  if ($catalyst_log) {
    print $fh $catalyst_log;
    $attachment = [$filename];
  }

  my $r = POST $url,
    Content_Type => 'form-data',
    Content      => [
    subject    => $subject,
    body       => $error,
    from       => 'Paperpile client',
    attachment => $attachment,
    ];

  my $response = $browser->request($r);

  unlink($filename);

}

sub report_pdf_download_error : Local {

  my ( $self, $c ) = @_;

  #my $url ='http://127.0.0.1:3003/api/v1/feedback/crashreport';

  my $url = 'http://stage.paperpile.com/api/v1/feedback/crashreport';

  my $pub          = $c->request->params->{info};
  my $catalyst_log = $c->request->params->{catalyst_log};

  my $subject = 'Automatic bug report: PDF download error';
  my $browser = Paperpile::Utils->get_browser();

  my ( $fh, $filename ) = tempfile( "catalyst-XXXXX", DIR => '/tmp', SUFFIX => '.txt' );

  my $attachment = undef;

  if ($catalyst_log) {
    print $fh $catalyst_log;
    $attachment = [$filename];
  }

  my $r = POST $url,
    Content_Type => 'form-data',
    Content      => [
    subject    => $subject,
    body       => $pub,
    from       => 'Paperpile client',
    attachment => $attachment,
    ];

  my $response = $browser->request($r);

  unlink($filename);
}



sub report_pdf_match_error : Local {

  my ( $self, $c ) = @_;

  my $url = 'http://stage.paperpile.com/api/v1/feedback/crashreport';

  my $file = $c->request->params->{info};

  my $subject = 'Automatic bug report: PDF match error';
  my $browser = Paperpile::Utils->get_browser();

  my $r = POST $url,
    Content_Type => 'form-data',
    Content      => [
    subject    => $subject,
    body       => $file,
    from       => 'Paperpile client',
    attachment => [$file],
    ];

  my $response = $browser->request($r);

}





1;
