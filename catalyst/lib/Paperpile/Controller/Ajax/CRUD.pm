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

package Paperpile::Controller::Ajax::CRUD;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Job;
use Paperpile::Queue;
use Data::Dumper;
use HTML::TreeBuilder;
use HTML::FormatText;
use 5.010;

sub insert_entry : Local {
  my ( $self, $c ) = @_;

  my $grid_id   = $c->request->params->{grid_id};

  my $plugin    = $self->_get_plugin($c);
  my $selection = $self->_get_selection($c);
  my %output    = ();

  # Go through and complete publication details if necessary.
  my @pub_array = ();
  foreach my $pub (@$selection) {
    if ( $plugin->needs_completing($pub) ) {
      my $old_sha1 = $pub->sha1;
      my $new_pub  = $plugin->complete_details($pub);

      # Store the old / original sha1 for use later on...
      $new_pub->{_old_sha1} = $old_sha1;
      push @pub_array, $new_pub;
    } else {
      push @pub_array, $pub;
    }
  }

  $c->model('Library')->create_pubs( \@pub_array );

  my $pubs = {};
  foreach my $pub (@pub_array) {
    $pub->_imported(1);
    my $pub_hash = $pub->as_hash;
    if ( $pub->{_old_sha1} ) {

      # ... now use the old / original sha1 as the sha1 to be returned to the front end,
      # while flagging that we have a *new* sha1 that the front-end should update to.
      # The actual updating to the new sha1 happens within the grid.js file.
      $pub_hash->{sha1}      = $pub->{_old_sha1};
      $pub_hash->{_new_sha1} = $pub->sha1;
    } else {
      $pub_hash->{sha1} = $pub->sha1;
    }

    $pubs->{ $pub_hash->{sha1} } = $pub_hash;
  }

  # If the number of imported pubs is reasonable, we return the updated pub data
  # directly and don't reload the entire grid that triggered the import.
  if ( scalar( keys %$pubs ) < 50 ) {
    $c->stash->{data} = { pubs => $pubs };

    # There is no need to reload the entire grid for the
    $c->stash->{data}->{pub_delta_ignore} = $grid_id;
  }

  # Trigger a complete reload
  $c->stash->{data}->{pub_delta} = 1;

  $self->_update_counts($c);

}

sub complete_entry : Local {

  my ( $self, $c ) = @_;
  my $plugin = $self->_get_plugin($c);
  my $selection = $self->_get_selection($c);

  my $cancel_handle = $c->request->params->{cancel_handle};

  Paperpile::Utils->register_cancel_handle($cancel_handle);

  my @new_pubs = ();
  my $results = {};
  foreach my $pub (@$selection) {
    my $pub_hash;
    if ($plugin->needs_completing($pub)) {
      my $new_pub = $plugin->complete_details($pub);
      my $old_sha1 = $pub->sha1;
      my $new_sha1 = $new_pub->sha1;

      $pub_hash = $new_pub->as_hash;
      $pub_hash->{sha1} = $old_sha1;
      $pub_hash->{_new_sha1} = $new_sha1;
    }
    $results->{$pub_hash->{sha1}} = $pub_hash;
  }

  $c->stash->{data} = {pubs => $results};

  Paperpile::Utils->clear_cancel($$);

}

sub new_entry : Local {

  my ( $self, $c ) = @_;

  my $match_job = $c->request->params->{match_job};

  my %fields = ();

  foreach my $key ( %{ $c->request->params } ) {
    next if $key =~ /^_/;
    $fields{$key} = $c->request->params->{$key};
  }

  my $pub = Paperpile::Library::Publication->new( {%fields} );

  $c->model('Library')->create_pubs( [$pub] );

  $self->_update_counts($c);

  # That's handled as form on the front-end so we have to explicitly
  # indicate success
  $c->stash->{success}=\1;

  $c->stash->{data}->{pub_delta} = 1;

  # Inserting a PDF that failed to match automatically and that has a
  # jobid in the queue. We update the job entry here.
  if ($match_job) {
    my $job = Paperpile::Job->new( { id => $match_job } );
    $job->update_status('DONE');
    $job->error('');
    $job->update_info('msg',"Data inserted manually.");
    $job->pub($pub);
    $job->save;
    $c->stash->{data}->{jobs}->{$match_job} = $job->as_hash;
  }
}

sub delete_entry : Local {
  my ( $self, $c ) = @_;
  my $plugin  = $self->_get_plugin($c);
  my $mode    = $c->request->params->{mode};

  my $data = $self->_get_selection($c);

  # ignore all entries that are not imported
  my @imported = ();
  foreach my $pub (@$data) {
    next if not $pub->_imported;
    push @imported, $pub;
  }

  $data = [@imported];

  $c->model('Library')->delete_pubs($data) if $mode eq 'DELETE';
  $c->model('Library')->trash_pubs( $data, 'RESTORE' ) if $mode eq 'RESTORE';

  if ( $mode eq 'TRASH' ) {
    $c->model('Library')->trash_pubs( $data, 'TRASH' );
    $c->session->{"undo_trash"} = $data;
  }

  $self->_collect_data($c,$data,['_imported','trashed']);

  $c->stash->{data}->{pub_delta} = 1;
  $c->stash->{num_deleted} = scalar @$data;

  $plugin->total_entries( $plugin->total_entries - scalar(@$data) );

  $self->_update_counts($c);

  $c->forward('Paperpile::View::JSON');

}

sub undo_trash : Local {

  my ( $self, $c ) = @_;

  my $data = $c->session->{"undo_trash"};

  $c->model('Library')->trash_pubs( $data, 'RESTORE' );

  delete( $c->session->{undo_trash} );

  $self->_update_counts($c);

  $c->stash->{data}->{pub_delta} = 1;

}

sub update_entry : Local {
  my ( $self, $c ) = @_;

  my $sha1 = $c->request->params->{sha1};
  my $plugin  = $self->_get_plugin($c);
  my $old_pub = $plugin->find_sha1($sha1);
  my $data    = $old_pub->as_hash;

  my $new_data = {};
  foreach my $field ( keys %{ $c->request->params } ) {
    next if $field =~ /grid_id/;
    $new_data->{$field} = $c->request->params->{$field};
  }

  my $new_pub = $c->model('Library')->update_pub( $old_pub, $new_data );

  delete( $plugin->_hash->{ $old_pub->sha1 } );
  $plugin->_hash->{ $new_pub->sha1 } = $new_pub;

  # That's handled as form on the front-end so we have to explicitly
  # indicate success
  $c->stash->{success} = \1;

  $c->stash->{data} = { pubs => {$old_pub->sha1 => $new_pub->as_hash}};


}

sub update_notes : Local {
  my ( $self, $c ) = @_;

  my $rowid = $c->request->params->{rowid};
  my $sha1  = $c->request->params->{sha1};
  my $html  = $c->request->params->{html};

  $c->model('Library')->update_field( 'Publications', $rowid, 'annote', $html );

  my $tree      = HTML::TreeBuilder->new->parse($html);
  my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 72 );
  my $text      = $formatter->format($tree);

  $c->model('Library')->update_field( 'Fulltext',     $rowid, 'notes', $text );

}

sub add_tag : Local {
  my ( $self, $c ) = @_;

  my $tag     = $c->request->params->{tag};
  my $grid_id = $c->request->params->{grid_id};

  my $data = $self->_get_selection($c);

  # First import entries that are not already in the database
  my @to_be_imported = ();
  foreach my $pub (@$data) {
    push @to_be_imported, $pub if !$pub->_imported;
  }

  $c->model('Library')->create_pubs( \@to_be_imported );

  my $dbh = $c->model('Library')->dbh;

  $dbh->begin_work();

  foreach my $pub (@$data) {
    my @tags = split( /,/, $pub->tags );
    push @tags, $tag;
    my %seen = ();
    @tags = grep { !$seen{$_}++ } @tags;
    my $new_tags = join( ',', @tags );
    $c->model('Library')->update_tags( $pub->_rowid, $new_tags );
    $pub->tags($new_tags);
  }
  $dbh->commit();

  if (@to_be_imported) {
    $self->_update_counts($c);
    $self->_collect_data($c, $data, [ 'tags', '_imported', 'citekey', 'created', 'pdf' ] );
    $c->stash->{data}->{pub_delta}        = 1;
    $c->stash->{data}->{pub_delta_ignore} = $grid_id;
  } else {
    $self->_collect_data($c, $data, ['tags'] );
  }

}


sub remove_tag : Local {
  my ( $self, $c ) = @_;

  my $tag  = $c->request->params->{tag};
  my $data = $self->_get_selection($c);

  my $dbh = $c->model('Library')->dbh;

  $dbh->begin_work;

  foreach my $pub (@$data) {
    my $new_tags = $pub->tags;
    $new_tags =~ s/^\Q$tag\E,//g;
    $new_tags =~ s/^\Q$tag\E$//g;
    $new_tags =~ s/,\Q$tag\E$//g;
    $new_tags =~ s/,\Q$tag\E,/,/g;
    $c->model('Library')->update_tags( $pub->_rowid, $new_tags );
    $pub->tags($new_tags);
  }

  $dbh->commit;

  $self->_collect_data($c, $data,['tags']);
  $c->forward('Paperpile::View::JSON');
}

sub update_tags : Local {
  my ( $self, $c ) = @_;

  my $rowid = $c->request->params->{rowid};
  my $sha1  = $c->request->params->{sha1};
  my $tags  = $c->request->params->{tags};

  $c->model('Library')->update_tags( $rowid, $tags );

}

sub style_tag : Local {
  my ( $self, $c ) = @_;

  my $tag   = $c->request->params->{tag};
  my $style = $c->request->params->{style};

  $c->model('Library')->set_tag_style( $tag, $style );

  my $pubs = $self->_get_cached_data($c);
  $self->_collect_data($c, $pubs,['tags']);
}

sub new_tag : Local {
  my ( $self, $c ) = @_;

  my $tag   = $c->request->params->{tag};
  my $style = $c->request->params->{style};
  my $sort_order = $c->request->params->{sort_order};

  $c->model('Library')->new_tag( $tag, $style , $sort_order);

}

sub delete_tag : Local {
  my ( $self, $c ) = @_;

  my $tag = $c->request->params->{tag};

  $c->model('Library')->delete_tag($tag);

  my $pubs = $self->_get_cached_data($c);
  foreach my $pub ( @$pubs ) {
    my $new_tags = $pub->tags;
    $new_tags =~ s/^\Q$tag\E,//g;
    $new_tags =~ s/^\Q$tag\E$//g;
    $new_tags =~ s/,\Q$tag\E$//g;
    $new_tags =~ s/,\Q$tag\E,/,/g;
    $pub->tags($new_tags);
  }

  $self->_collect_data($c, $pubs,['tags']);
}

sub rename_tag : Local {
  my ( $self, $c ) = @_;

  my $old_tag = $c->request->params->{old_tag};
  my $new_tag = $c->request->params->{new_tag};

  $c->model('Library')->rename_tag( $old_tag, $new_tag );

  my $pubs = $self->_get_cached_data($c);
  foreach my $pub ( @$pubs ) {
    my $new_tags = $pub->tags;
    $new_tags =~ s/^\Q$old_tag\E,/$new_tag,/g;
    $new_tags =~ s/^\Q$old_tag\E$/$new_tag/g;
    $new_tags =~ s/,\Q$old_tag\E$/,$new_tag/g;
    $new_tags =~ s/,\Q$old_tag\E,/,$new_tag,/g;
    $pub->tags($new_tags);
  }

  $self->_collect_data($c, $pubs,['tags']);
}

sub generate_edit_form : Local {
  my ( $self, $c ) = @_;

  my $pub = Paperpile::Library::Publication->new();

  my $pubtype = $c->request->params->{pubtype};

  my %config = Paperpile::Utils::get_config;

  my @output = ();

  foreach my $field ( split( /\s+/, $config{pubtypes}->{$pubtype}->{all} ) ) {
    push @output, { name => $field, fieldLabel => $config{fields}->{$field} };
  }

  my $form = [@output];

  $c->stash->{form} = $form;

  $c->forward('Paperpile::View::JSON');

}

sub move_in_folder : Local {
  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $node_id = $c->request->params->{node_id};

  my $data = $self->_get_selection($c);

  # First import entries that are not already in the database
  my @to_be_imported = ();
  foreach my $pub (@$data) {
    push @to_be_imported, $pub if !$pub->_imported;
  }

  $c->model('Library')->create_pubs( \@to_be_imported );

  my $dbh = $c->model('Library')->dbh;

  $dbh->begin_work();

  if ( $node_id ne 'FOLDER_ROOT' ) {
    my $newFolder = $node_id;

    foreach my $pub (@$data) {
      my @folders = split( /,/, $pub->folders );
      push @folders, $newFolder;
      my %seen = ();
      @folders = grep { !$seen{$_}++ } @folders;
      my $new_folders = join( ',', @folders );
      $c->model('Library')->update_folders( $pub->_rowid, $new_folders );
      $pub->folders($new_folders);
    }
  }

  $dbh->commit();

  if (@to_be_imported) {
    $self->_update_counts($c);
    $self->_collect_data($c, $data, [ 'folders', '_imported', 'citekey', 'created','pdf' ] );
    $c->stash->{data}->{pub_delta}        = 1;
    $c->stash->{data}->{pub_delta_ignore} = $grid_id;
  } else {
    $self->_collect_data($c, $data, ['folders'] );
  }

}


sub delete_from_folder : Local {
  my ( $self, $c ) = @_;

  my $folder_id = $c->request->params->{folder_id};

  my $data = $self->_get_selection($c);

  #foreach my $pub (@$data) {
  #  my $new_folders = $c->model('Library')->delete_from_folder( $pub->_rowid, $folder_id );
  #  $pub->folders($new_folders);
  #}

  $c->model('Library')->delete_from_folder( $data, $folder_id );

  $self->_collect_data($c, $data, ['folders'] );
}


sub batch_download : Local {
  my ( $self, $c ) = @_;
  my $plugin  = $self->_get_plugin($c);

  my $data = $self->_get_selection($c);

  my $q = Paperpile::Queue->new();

  my @jobs = ();

  foreach my $pub (@$data) {
    my $j = Paperpile::Job->new(
      type => 'PDF_SEARCH',
      pub  => $pub,
    );

    $j->pub->_search_job( { id => $j->id, status => $j->status, msg => $j->info->{msg} } );

    push @jobs, $j;
  }

  $q->submit( \@jobs );
  $q->save;
  $q->run;
  $self->_collect_data($c, $data, ['_search_job'] );


  #my $pid = undef;

  #if ( !defined( $pid = fork() ) ) {
  #  die "Cannot fork: $!";
  #} elsif ( $pid == 0 ) {
  #  print STDERR "================> This is the child.";

  #  close(STDOUT);
  #  close(STDERR);

  #  foreach my $i (0..10){
  #    sleep(1);
  #  }
  #  exit();
  #} else {
  #  print STDERR "================> This is the parent.";
  #}

  $c->stash->{data}->{job_delta} = 1;

  $c->detach('Paperpile::View::JSON');

}

sub _get_plugin {
  my $self = shift;
  my $c = shift;

  my $grid_id = $c->request->params->{grid_id};
  my $plugin = $c->session->{"grid_$grid_id"};
  return $plugin;
}

sub _get_selection {

  my ( $self, $c, $light_objects ) = @_;

  my $grid_id   = $c->request->params->{grid_id};
  my $selection = $c->request->params->{selection};
  my $plugin    = $self->_get_plugin($c);

  if ($light_objects) {
    $plugin->light_objects(1);
  } else {
    $plugin->light_objects(0);
  }

  my @data = ();

  if ( $selection eq 'ALL' ) {
    @data = @{ $plugin->all };
  } else {
    my @tmp;
    if ( ref($selection) eq 'ARRAY' ) {
      @tmp = @$selection;
    } else {
      push @tmp, $selection;
    }
    for my $sha1 (@tmp) {
      my $pub = $plugin->find_sha1($sha1);
      if ( defined $pub ) {
        push @data, $pub;
      }
    }
  }

  return [@data];

}

sub _get_cached_data {

  my ( $self, $c ) = @_;

  my @list = ();

  foreach my $var ( keys %{ $c->session } ) {
    next if !( $var =~ /^grid_/ );
    my $plugin = $c->session->{$var};
    foreach my $pub ( values %{ $plugin->_hash } ) {
      push @list, $pub;
    }
  }

  return [@list];

}

sub _update_counts {

  my ( $self, $c ) = @_;

  foreach my $var ( keys %{ $c->session } ) {
    next if !( $var =~ /^grid_/ );
    my $plugin = $c->session->{$var};
    if ( $plugin->plugin_name eq 'DB' or $plugin->plugin_name eq 'Trash' ) {
      $plugin->update_count();
    }
  }
}

sub _collect_data {
  my ( $self, $c, $pubs, $fields ) = @_;

  $c->stash->{data} = {} unless (defined $c->stash->{data});

  my $max_output_size = 50;
  if (scalar(@$pubs) > $max_output_size) {
    $c->stash->{data}->{pub_delta} = 1;
    return ();
  }

  my %output = ();
  foreach my $pub (@$pubs) {
    my $hash       = $pub->as_hash;

    my $pub_fields = {};
    if ($fields) {
      map { $pub_fields->{$_} = $hash->{$_} } @$fields;
    } else {
      $pub_fields = $hash;
    }
    $output{ $hash->{sha1} } = $pub_fields;
  }

  $c->stash->{data}->{pubs} = \%output;
}

1;
