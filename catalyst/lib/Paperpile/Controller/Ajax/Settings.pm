package Paperpile::Controller::Ajax::Settings;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use File::Temp;
use File::Copy;
use File::Copy::Recursive qw(dirmove);
use File::Path;
use Data::Dumper;
use 5.010;

sub pattern_example : Local {
  my ( $self, $c ) = @_;

  my $pattern = $c->request->params->{pattern};
  my $key     = $c->request->params->{key};

  # Add full validation later
  if (!$pattern){
    $self->_submit( $c, { string => undef, error => 'Pattern must not be empty.' } );
  }

  my %book = (
    pubtype   => 'INBOOK',
    title     => 'Fundamental Algorithms',
    booktitle => 'The Art of Computer Programming',
    authors   => 'Knuth, D.E.',
    volume    => '1',
    pages     => '10-119',
    publisher => 'Addison-Wesley',
    city      => 'Reading',
    address   => "Massachusetts",
    year      => '2007',
    month     => 'Jan',
    isbn      => '0-201-03803-X',
    notes     => 'These are my notes',
    tags      => 'programming, algorithms',
  );

  my $pub = Paperpile::Library::Publication->new( {%book} );

  my $formatted_key = $pub->format_pattern($key);

  my $string = $pub->format_pattern( $pattern, { key => $formatted_key } );

  $self->_submit( $c, { string => $string } );

}

sub update_patterns : Local {
  my ( $self, $c ) = @_;

  my $user_db            = $c->request->params->{user_db};
  my $paper_root         = $c->request->params->{paper_root};
  my $key_pattern        = $c->request->params->{key_pattern};
  my $pdf_pattern        = $c->request->params->{pdf_pattern};
  my $attachment_pattern = $c->request->params->{attachment_pattern};

  my $settings = $c->model('User')->settings;
  $settings->{user_db} = $c->model('App')->get_setting('user_db');

  my $db_changed         = $user_db            ne $settings->{user_db};
  my $root_changed       = $paper_root         ne $settings->{paper_root};
  my $key_changed        = $key_pattern        ne $settings->{key_pattern};
  my $pdf_changed        = $pdf_pattern        ne $settings->{pdf_pattern};
  my $attachment_changed = $attachment_pattern ne $settings->{attachment_pattern};

  if ($key_changed) {
    $c->model('User')->update_citekeys($key_pattern);
  }

  # Update files if either attachments or pdf pattern changed, or if
  # key pattern changed and either of them contains [key]
  my $update_files = 0;
  $update_files = 1 if ( $pdf_changed or $attachment_changed );
  $update_files = 1 if ( $key_changed and $pdf_pattern        =~ /\[key\]/ );
  $update_files = 1 if ( $key_changed and $attachment_pattern =~ /\[key\]/ );

  if ($update_files) {
    $c->forward('rename_files');
    $c->model('User')->set_setting( 'pdf_pattern',        $pdf_pattern );
    $c->model('User')->set_setting( 'attachment_pattern', $attachment_pattern );
  }

  if ($root_changed) {
    if ( dirmove( $settings->{paper_root}, $paper_root ) ) {
      $c->model('User')->set_setting( 'paper_root', $paper_root );
    } else {
      die("Could not move directory to new location ($!)");
    }
  }

  if ($db_changed) {

    if (move( $settings->{user_db}, $user_db )){

      # update user_db in session variable and also all active plugins
      # that have stored a reference to the database file
      $c->session->{user_db} = $user_db;
      foreach my $key (keys %{$c->session}){
        next if not $key=~/^grid_/;
        $c->session->{$key}->file($user_db);
      }
      $c->model('App')->set_setting( 'user_db', $user_db );
    } else {
      die("Could not change database file to user_db ($!)");
    }
  }

  $c->stash->{data}    = {};
  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub rename_files : Private {

  my ( $self, $c ) = @_;

  my $pdf_pattern        = $c->request->params->{pdf_pattern};
  my $attachment_pattern = $c->request->params->{attachment_pattern};

  my $model= $c->model('User');

  $model->dbh->begin_work;

  my $old_root = $model->get_setting('paper_root');
  my $tmp_root = File::Temp::tempdir('paperpile-XXXXXXX', DIR=>'/tmp', CLEANUP => 0 );

  eval {

    my $entries=$model->all;

    my %entries_with_attachments=();

    foreach my $pub (@{$entries}){

      if ($pub->attachments){
        $entries_with_attachments{$pub->_rowid}=$pub;
      }

      next if not $pub->pdf;

      my $source = File::Spec->catfile( $old_root, $pub->pdf );
      my $relative_dest = $pub->format_pattern($pdf_pattern, {key=>$pub->citekey}).'.pdf';
      my $absolute_dest = File::Spec->catfile( $tmp_root, $relative_dest );

      $absolute_dest=Paperpile::Utils->copy_file($source, $absolute_dest);
      $relative_dest = File::Spec->abs2rel( $absolute_dest, $tmp_root ) ;

      my $path=$model->dbh->quote($relative_dest);

      $model->dbh->do("UPDATE Publications SET pdf=$path WHERE rowid=".$pub->_rowid);

    }

    my ($pub_id, $attachment_id, $relative_source);

    my $select=$model->dbh->prepare("SELECT rowid, publication_id, file_name FROM Attachments;");
    $select->bind_columns( \$attachment_id, \$pub_id, \$relative_source );
    $select->execute;

    while ( $select->fetch ) {
      my $absolute_source=File::Spec->catfile( $old_root, $relative_source );
      my ($volume,$dirs,$file_name) = File::Spec->splitpath( $absolute_source );

      my $pub = $entries_with_attachments{$pub_id};

      my $relative_dest = $pub->format_pattern( $attachment_pattern, { key => $pub->citekey } );
      $relative_dest = File::Spec->catfile( $relative_dest, $file_name);

      my $absolute_dest = File::Spec->catfile( $tmp_root, $relative_dest );

      $absolute_dest=Paperpile::Utils->copy_file($absolute_source, $absolute_dest);
      $relative_dest = File::Spec->abs2rel( $absolute_dest, $tmp_root );

      my $path=$model->dbh->quote($relative_dest);

      $model->dbh->do("UPDATE Attachments SET file_name=$path WHERE rowid=".$attachment_id);

    }
  };

  if ($@){
    $model->dbh->rollback;
    die($@);
  }

  if (not move($old_root,"$old_root\_backup")){
    $model->dbh->rollback;
    die("Could not make backup copy $old_root\_backup");
  }

  if (not move($tmp_root,$old_root)){
    $model->dbh->rollback;
    move("$old_root\_backup",$old_root) or die('When this error occurs you are really, really unlucky...');
    die("Could not make new copy of directory tree in $old_root.");
  }

  $model->dbh->commit;

  rmtree("$old_root\_backup");

}



sub _submit {

  my ( $self, $c, $data ) = @_;

  $c->stash->{data}    = $data;
  $c->stash->{success} = 'true';

  $c->detach('Paperpile::View::JSON');
}







1;
