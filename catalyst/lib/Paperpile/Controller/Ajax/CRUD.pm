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

  my $grid_id = $c->request->params->{grid_id};

  my $selection = $self->_get_selection( $c, 1 );

  my %output = ();

  $c->model('Library')->create_pubs($selection);

  foreach my $pub (@$selection) {
    $pub->_imported(1);
  }

  my $pubs = $self->_collect_data($selection,['_imported','citekey','created','sha1','pdf']);
  $c->stash->{data}    = {pubs => $pubs};

  # Trigger a complete reload
  $c->stash->{data}->{pub_delta} = 1;

  # There is no need to reload the original grid 
  $c->stash->{data}->{pub_delta_ignore} = $grid_id;

  $self->_update_counts($c);

}

sub complete_entry : Local {

  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};
  my $sha1    = $c->request->params->{sha1};
  my $plugin  = $c->session->{"grid_$grid_id"};

  my $pub = $plugin->find_sha1($sha1);
  $pub = $plugin->complete_details($pub);

  $c->model('Library')->exists_pub( [$pub] );

  $c->stash->{data} = $pub->as_hash;

}

sub new_entry : Local {

  my ( $self, $c ) = @_;

  my $attach_pdf = $c->request->params->{attach_pdf};

  my %fields = ();

  foreach my $key ( %{ $c->request->params } ) {
    next if $key =~ /^_/;
    $fields{$key} = $c->request->params->{$key};
  }

  my $pub = Paperpile::Library::Publication->new( {%fields} );

  $c->model('Library')->create_pubs( [$pub] );

  if ($attach_pdf) {
    $c->model('Library')->attach_file( $attach_pdf, 1, $pub->_rowid, $pub );
  }

  $self->_update_counts($c);

  # That's handled as form on the front-end so we have to explicitly
  # indicate success
  $c->stash->{success}=\1;

  $c->stash->{data}->{pub_delta} = 1;

}

sub delete_entry : Local {
  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};
  my $plugin  = $c->session->{"grid_$grid_id"};
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

  my $pubs = $self->_collect_data($data,['_imported','trashed']);

  $c->stash->{data}    = {pubs => $pubs};
  $c->stash->{data}->{pub_delta} = 1;
  $c->stash->{num_deleted} = scalar @$data;

  $plugin->total_entries( $plugin->total_entries - scalar(@$data) );

  $self->_update_counts($c);

  $c->forward('Paperpile::View::JSON');

}

sub undo_trash : Local {

  my ( $self, $c ) = @_;

  my $data = $c->session->{"undo_trash"};

  $c->forward('Paperpile::View::JSON');

  $c->model('Library')->trash_pubs( $data, 'RESTORE' );

  delete( $c->session->{undo_trash} );

  $self->_update_counts($c);

  $c->forward('Paperpile::View::JSON');

}

sub update_entry : Local {
  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};

  my $sha1 = $c->request->params->{sha1};

  my $plugin  = $c->session->{"grid_$grid_id"};
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

  $c->model('Library')->update_field( 'Fulltext_full',     $rowid, 'notes', $text );
  $c->model('Library')->update_field( 'Fulltext_citation', $rowid, 'notes', $text );

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
    my $update =
      $self->_collect_data( $data, [ 'tags', '_imported', 'citekey', 'created', 'pdf' ] );
    $c->stash->{data} = { pubs => $update };
    $c->stash->{data}->{pub_delta}        = 1;
    $c->stash->{data}->{pub_delta_ignore} = $grid_id;
  } else {
    my $update = $self->_collect_data( $data, ['tags'] );
    $c->stash->{data} = { pubs => $update };
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

  my $update = $self->_collect_data($data,['tags']);
  $c->stash->{data}    = {pubs => $update};
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
  my $update = $self->_collect_data($pubs,['tags']);
  $c->stash->{data}    = {pubs => $update};  

}

sub new_tag : Local {
  my ( $self, $c ) = @_;

  my $tag   = $c->request->params->{tag};
  my $style = $c->request->params->{style};

  $c->model('Library')->new_tag( $tag, $style );

}

sub delete_tag : Local {
  my ( $self, $c ) = @_;

  my $tag = $c->request->params->{tag};

  $c->model('Library')->delete_tag($tag);

  my $pubs = $self->_get_cached_data($c);
  foreach my $pub ( @$pubs ) {
    my $new_tags = $pub->tags;
    $new_tags =~ s/^$tag,//g;
    $new_tags =~ s/^$tag$//g;
    $new_tags =~ s/,$tag$//g;
    $new_tags =~ s/,$tag,/,/g;
    $pub->tags($new_tags);
  }

  my $update = $self->_collect_data($pubs,['tags']);
  $c->stash->{data}    = {pubs => $update};

}

sub rename_tag : Local {
  my ( $self, $c ) = @_;

  my $old_tag = $c->request->params->{old_tag};
  my $new_tag = $c->request->params->{new_tag};

  $c->model('Library')->rename_tag( $old_tag, $new_tag );

  my $pubs = $self->_get_cached_data($c);
  foreach my $pub ( @$pubs ) {
    my $new_tags = $pub->tags;
    $new_tags =~ s/^$old_tag,/$new_tag,/g;
    $new_tags =~ s/^$old_tag$/$new_tag/g;
    $new_tags =~ s/,$old_tag$/,$new_tag/g;
    $new_tags =~ s/,$old_tag,/,$new_tag,/g;
    $pub->tags($new_tags);
  }

  my $update = $self->_collect_data($pubs,['tags']);
  $c->stash->{data}    = {pubs => $update};

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
    my $update = $self->_collect_data( $data, [ 'folders', '_imported', 'citekey', 'created','pdf' ] );
    $c->stash->{data} = { pubs => $update };
    $c->stash->{data}->{pub_delta}        = 1;
    $c->stash->{data}->{pub_delta_ignore} = $grid_id;
  } else {
    my $update = $self->_collect_data( $data, ['folders'] );
    $c->stash->{data} = { pubs => $update };
  }

  #my $pubs = $self->_collect_data($data);
  #$c->stash->{data}    = {pubs => $pubs};

}

sub delete_from_folder : Local {
  my ( $self, $c ) = @_;

  my $folder_id = $c->request->params->{folder_id};

  my $data = $self->_get_selection($c);

  foreach my $pub (@$data) {
    my $new_folders = $c->model('Library')->delete_from_folder( $pub->_rowid, $folder_id );
    $pub->folders($new_folders);
  }

  my $pubs = $self->_collect_data($data,['folders']);
  $c->stash->{data}    = {pubs => $pubs};

}

sub batch_download : Local {
  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};
  my $plugin  = $c->session->{"grid_$grid_id"};

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

  my $pubs = $self->_collect_data( $data, ['_search_job'] );

  $c->stash->{data} = { pubs => $pubs, job_delta => 1 };

}

sub _get_selection {

  my ( $self, $c, $light_objects ) = @_;

  my $grid_id   = $c->request->params->{grid_id};
  my $selection = $c->request->params->{selection};
  my $plugin    = $c->session->{"grid_$grid_id"};

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
  my ( $self, $pubs, $fields ) = @_;

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
  return \%output;
}

1;
