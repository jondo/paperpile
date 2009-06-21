package Paperpile::Controller::Ajax::CRUD;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use HTML::TreeBuilder;
use HTML::FormatText;
use 5.010;

sub insert_entry : Local {
  my ( $self, $c ) = @_;

  my $data = $self->_get_selection($c);

  my %output=();

  $c->model('Library')->create_pubs($data);

  foreach my $pub (@$data){
    $output{$pub->sha1}={_imported=>1,
                         citekey=>$pub->citekey,
                         _rowid=>$pub->_rowid,
                         created=>$pub->created
                        };
  }

  $c->stash->{data} = {%output};

  $c->forward('Paperpile::View::JSON');

}

sub complete_entry : Local{

  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};
  my $sha1      = $c->request->params->{sha1};
  my $plugin = $c->session->{"grid_$grid_id"};

  my $pub = $plugin->find_sha1($sha1);
  $pub=$plugin->complete_details($pub);

  $c->stash->{data} = $pub->as_hash;

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub new_entry: Local {

  my ( $self, $c ) = @_;

  my $attach_pdf = $c->request->params->{attach_pdf};

  my %fields=();

  foreach my $key (%{$c->request->params}){
    next if $key=~/^_/;
    $fields{$key}=$c->request->params->{$key};
  }

  my $pub=Paperpile::Library::Publication->new({%fields});

  $c->model('Library')->create_pubs([$pub]);

  if ($attach_pdf){
    $c->model('Library')->attach_file( $attach_pdf, 1, $pub->_rowid, $pub);
  }

  $c->stash->{data} = $pub->as_hash;
  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');


}

sub delete_entry : Local {
  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};
  my $plugin = $c->session->{"grid_$grid_id"};

  my $data = $self->_get_selection($c);

  $c->model('Library')->delete_pubs($data);

  $plugin->total_entries($plugin->total_entries - scalar(@$data));

  $c->forward('Paperpile::View::JSON');

}

sub update_entry : Local {
  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $rowid     = $c->request->params->{rowid};
  my $sha1      = $c->request->params->{sha1};

  # get old data
  my $plugin = $c->session->{"grid_$grid_id"};
  my $pub = $plugin->find_sha1($sha1);
  my $data=$pub->as_hash;

  # apply new values to old entry
  foreach my $field (keys %{$c->request->params}){
    next if $field=~/grid_id/;
    $data->{$field}=$c->request->params->{$field};
  }

  my $newPub=Paperpile::Library::Publication->new($data);

  $c->model('Library')->update_pub($newPub);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}


sub update_notes : Local {
  my ( $self, $c ) = @_;

  my $rowid = $c->request->params->{rowid};
  my $sha1  = $c->request->params->{sha1};
  my $html  = $c->request->params->{html};

  $c->model('Library')->update_field( 'Publications', $rowid, 'notes', $html );

  my $tree      = HTML::TreeBuilder->new->parse($html);
  my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 72 );
  my $text      = $formatter->format($tree);

  $c->model('Library')->update_field( 'Fulltext_full', $rowid, 'notes', $text );
  $c->model('Library')->update_field( 'Fulltext_citation', $rowid, 'notes', $text );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub add_tag : Local {
  my ( $self, $c ) = @_;

  my $tag= $c->request->params->{tag};

  my $data = $self->_get_selection($c);

  # First import entries that are not already in the database
  my @to_be_imported=();
  foreach my $pub (@$data){
    push @to_be_imported, $pub if !$pub->_imported;
  }

  $c->model('Library')->create_pubs(\@to_be_imported);

  my %output=();

  foreach my $pub (@$data){
    my @tags = split( /,/, $pub->tags );
    push @tags, $tag;
    my %seen = ();
    @tags = grep { !$seen{$_}++ } @tags;
    my $new_tags=join( ',', @tags );
    $c->model('Library')->update_tags($pub->_rowid, $new_tags);
    $pub->tags($new_tags);
    $output{$pub->sha1}={_imported=>1,
                         _rowid=>$pub->_rowid,
                         citekey=>$pub->citekey,
                         created=>$pub->created,
                         tags=>$new_tags,
                        };
  }

  $c->stash->{data} = {%output};
  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub remove_tag : Local {
  my ( $self, $c ) = @_;

  my $tag  = $c->request->params->{tag};
  my $data = $self->_get_selection($c);

  my %output=();

  foreach my $pub (@$data) {
    my $new_tags = $pub->tags;
    $new_tags =~ s/^$tag,//g;
    $new_tags =~ s/^$tag$//g;
    $new_tags =~ s/,$tag$//g;
    $new_tags =~ s/,$tag,/,/g;
    $c->model('Library')->update_tags( $pub->_rowid, $new_tags );
    $pub->tags($new_tags);
    $output{$pub->sha1}={tags=>$new_tags};

  }

  $c->stash->{data} = {%output};
  $c->forward('Paperpile::View::JSON');

}

sub update_tags : Local {
  my ( $self, $c ) = @_;

  my $rowid     = $c->request->params->{rowid};
  my $sha1      = $c->request->params->{sha1};
  my $tags      = $c->request->params->{tags};

  $c->model('Library')->update_tags($rowid, $tags);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub style_tag : Local {
  my ( $self, $c ) = @_;

  my $tag   = $c->request->params->{tag};
  my $style = $c->request->params->{style};

  $c->model('Library')->set_tag_style( $tag, $style );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}


sub new_tag : Local {
  my ( $self, $c ) = @_;

  my $tag = $c->request->params->{tag};
  my $style = $c->request->params->{style};

  $c->model('Library')->new_tag($tag,$style);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub delete_tag : Local {
  my ( $self, $c ) = @_;

  my $tag = $c->request->params->{tag};

  $c->model('Library')->delete_tag($tag);

  foreach my $pub (@{$self->_get_cached_data($c)}){
    my $new_tags=$pub->tags;
    $new_tags =~ s/^$tag,//g;
    $new_tags =~ s/^$tag$//g;
    $new_tags =~ s/,$tag$//g;
    $new_tags =~ s/,$tag,/,/g;
    $pub->tags($new_tags);
  }

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub rename_tag : Local {
  my ( $self, $c ) = @_;

  my $old_tag = $c->request->params->{old_tag};
  my $new_tag = $c->request->params->{new_tag};

  $c->model('Library')->rename_tag($old_tag,$new_tag);

  foreach my $pub (@{$self->_get_cached_data($c)}){
    my $new_tags=$pub->tags;
    $new_tags =~ s/^$old_tag,/$new_tag,/g;
    $new_tags =~ s/^$old_tag$/$new_tag/g;
    $new_tags =~ s/,$old_tag$/,$new_tag/g;
    $new_tags =~ s/,$old_tag,/,$new_tag,/g;
    $pub->tags($new_tags);
  }

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub generate_edit_form : Local {
  my ( $self, $c ) = @_;

  my $pub = Paperpile::Library::Publication->new();

  my $pubtype = $c->request->params->{pubtype};

  my %config=Paperpile::Utils::get_config;

  my @output=();

  foreach my $field (split(/\s+/,$config{pubtypes}->{$pubtype}->{all})){
    push @output, {name=>$field, fieldLabel=>$config{fields}->{$field}};
  }

  my $form=[@output];

  $c->stash->{form} = $form;

  $c->forward('Paperpile::View::JSON');

}

sub move_in_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};

  my $data = $self->_get_selection($c);

  # First import entries that are not already in the database
  my @to_be_imported = ();
  foreach my $pub (@$data) {
    push @to_be_imported, $pub if !$pub->_imported;
  }

  $c->model('Library')->create_pubs( \@to_be_imported );

  my %output;

  if ( $node_id ne 'FOLDER_ROOT' ) {
    my $newFolder = $node_id;

    foreach my $pub (@$data) {
      my @folders = split( /,/, $pub->folders );
      push @folders, $newFolder;
      my %seen = ();
      @folders = grep { !$seen{$_}++ } @folders;
      my $new_folders = join( ',', @folders );
      $c->model('Library')->update_folders( $pub->_rowid, $new_folders );
      $output{ $pub->sha1 } = {
        _imported => 1,
        _rowid    => $pub->_rowid,
        citekey   => $pub->citekey,
        created   => $pub->created,
        folders   => $pub->folders,
      };

    }
  } else {
    foreach my $pub (@to_be_imported) {
      $output{ $pub->sha1 } = {
        _imported => 1,
        _rowid    => $pub->_rowid,
        citekey   => $pub->citekey,
        created   => $pub->created,
      };
    }

  }

  $c->stash->{data}    = {%output};
  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}


sub delete_from_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};
  my $folder_id     = $c->request->params->{folder_id};

  my $data = $self->_get_selection($c);

  foreach my $pub (@$data){
    $c->model('Library')->delete_from_folder( $pub->_rowid, $folder_id );
  }

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub _get_selection {

  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $selection = $c->request->params->{selection};
  my $plugin = $c->session->{"grid_$grid_id"};

  my @data = ();

  if ($selection eq 'ALL'){
    @data = @{$plugin->all};
  } else {
    my @tmp;
    if ( ref($selection) eq 'ARRAY' ) {
      @tmp = @$selection;
    } else {
      push @tmp, $selection;
    }
    for my $sha1 (@tmp) {
      my $pub = $plugin->find_sha1($sha1);
      push @data, $pub;
    }
  }

  return [@data];

}

sub _get_cached_data {

  my ( $self, $c ) = @_;

  my @list=();

  foreach my $var (keys %{$c->session}){
    next if !($var=~/^grid_/);
    my $plugin=$c->session->{$var};
    foreach my $pub (values %{$plugin->_hash}){
      push @list, $pub;
    }
  }

  return [@list];

}

1;
