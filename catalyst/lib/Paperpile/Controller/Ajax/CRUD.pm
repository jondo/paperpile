package Paperpile::Controller::Ajax::CRUD;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use MooseX::Timestamp;
use HTML::TreeBuilder;
use HTML::FormatText;
use 5.010;

sub insert_entry : Local {
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

  my %output=();

  foreach my $pub (@data){
    $pub->created(timestamp);
    $pub->times_read(0);
    $pub->last_read(timestamp); ## for the time being
    $pub->_imported(1);
  }

  $c->model('User')->create_pubs(\@data);

  foreach my $pub (@data){
    $output{$pub->sha1}={_imported=>1,
                         citekey=>$pub->citekey,
                         _rowid=>$pub->_rowid,
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

  $pub->created(timestamp);
  $pub->times_read(0);
  $pub->attachments(0);
  $pub->last_read(timestamp); ## for the time being

  $c->model('User')->create_pubs([$pub]);

  if ($attach_pdf){
    $c->model('User')->attach_file( $attach_pdf, 1, $pub->_rowid, $pub);
  }

  $c->stash->{data} = $pub->as_hash;
  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');


}

sub delete_entry : Local {
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

  $c->model('User')->delete_pubs([@data]);

  $plugin->total_entries($plugin->total_entries - scalar(@data));

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

  $c->model('User')->update_pub($newPub);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}


sub update_notes : Local {
  my ( $self, $c ) = @_;

  my $rowid = $c->request->params->{rowid};
  my $sha1  = $c->request->params->{sha1};
  my $html  = $c->request->params->{html};

  $c->model('User')->update_field( 'Publications', $rowid, 'notes', $html );

  my $tree      = HTML::TreeBuilder->new->parse($html);
  my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 72 );
  my $text      = $formatter->format($tree);

  $c->model('User')->update_field( 'Fulltext_full', $rowid, 'notes', $text );
  $c->model('User')->update_field( 'Fulltext_citation', $rowid, 'notes', $text );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub update_tags : Local {
  my ( $self, $c ) = @_;

  my $rowid     = $c->request->params->{rowid};
  my $sha1      = $c->request->params->{sha1};
  my $tags      = $c->request->params->{tags};

  $c->model('User')->update_tags($rowid, $tags);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub style_tag : Local {
  my ( $self, $c ) = @_;

  my $tag   = $c->request->params->{tag};
  my $style = $c->request->params->{style};

  $c->model('User')->set_tag_style( $tag, $style );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}


sub new_tag : Local {
  my ( $self, $c ) = @_;

  my $tag = $c->request->params->{tag};
  my $style = $c->request->params->{style};

  $c->model('User')->new_tag($tag,$style);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}



sub delete_tag : Local {
  my ( $self, $c ) = @_;

  my $tag = $c->request->params->{tag};

  $c->model('User')->delete_tag($tag);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub rename_tag : Local {
  my ( $self, $c ) = @_;

  my $old_tag = $c->request->params->{old_tag};
  my $new_tag = $c->request->params->{new_tag};

  $c->model('User')->rename_tag($old_tag,$new_tag);

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







1;
