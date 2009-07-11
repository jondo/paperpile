package Paperpile::Controller::Ajax::Settings;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Exceptions;
use File::Temp;
use File::Copy;
use File::Copy::Recursive qw(dirmove);
use File::Path;
use Data::Dumper;
use 5.010;

sub pattern_example : Local {

  my ( $self, $c ) = @_;

  my $paper_root = $c->request->params->{paper_root};
  my $library_db    = $c->request->params->{library_db};

  my $key_pattern        = $c->request->params->{key_pattern};
  my $pdf_pattern        = $c->request->params->{pdf_pattern};
  my $attachment_pattern = $c->request->params->{attachment_pattern};

  my %data = ();

  foreach my $field ('key_pattern', 'pdf_pattern', 'attachment_pattern'){
    while ($c->request->params->{$field} =~ /\[\s*(.*?)\s*\]/ig){
      if (not $1 =~ /^(firstauthor|lastauthor|authors|title|yy|yyyy|key)[:_0-9]*$/i){
        $data{$field}->{error}="Invalid pattern [$1]";
      }
    }
  }

  my $minimum = qr/\[(firstauthor|lastauthor|authors|title)[:_0-9]*\]/i;

  if (not $key_pattern =~ $minimum){
    $data{key_pattern}->{error}='Your pattern must include at least [firstauthor], [lastauthor], [authors] or [title]';
  }

  if (not $pdf_pattern =~ /\[key\]/i){
    if (not $pdf_pattern =~ $minimum){
      $data{pdf_pattern}->{error}='Your pattern must include at least [key], [firstauthor], [lastauthor], [authors] or [title]';
    }
  }

  if (not $attachment_pattern =~ /\[key\]/i){
    if (not $attachment_pattern =~ $minimum){
      $data{attachment_pattern}->{error}='Your pattern must include at least [key], [firstauthor], [lastauthor], [authors] or [title]';
    }
  }

  $paper_root=~s{/$}{}; # remove trailing /

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

  my $formatted_key        = $pub->format_pattern( $c->request->params->{key_pattern} );
  my $formatted_pdf        = $pub->format_pattern( $pdf_pattern, { key => $formatted_key } );
  my $formatted_attachment = $pub->format_pattern( $attachment_pattern, { key => $formatted_key } );

  my @tmp=split(/\//,$paper_root);

  $formatted_pdf=".../".$tmp[$#tmp]."/<b>$formatted_pdf.pdf</b>";
  $formatted_attachment=".../".$tmp[$#tmp]."/<b>$formatted_attachment/</b>";

  $data{key_pattern}->{string}        = $formatted_key;
  $data{pdf_pattern}->{string}        = $formatted_pdf;
  $data{attachment_pattern}->{string} = $formatted_attachment;

  $self->_submit( $c, {%data} );

}

sub update_patterns : Local {
  my ( $self, $c ) = @_;

  my $library_db         = $c->request->params->{library_db};
  my $paper_root         = $c->request->params->{paper_root};
  my $key_pattern        = $c->request->params->{key_pattern};
  my $pdf_pattern        = $c->request->params->{pdf_pattern};
  my $attachment_pattern = $c->request->params->{attachment_pattern};

  my $settings = $c->model('Library')->settings;
  $settings->{library_db} = $c->model('User')->get_setting('library_db');

  my $db_changed         = $library_db         ne $settings->{library_db};
  my $root_changed       = $paper_root         ne $settings->{paper_root};
  my $key_changed        = $key_pattern        ne $settings->{key_pattern};
  my $pdf_changed        = $pdf_pattern        ne $settings->{pdf_pattern};
  my $attachment_changed = $attachment_pattern ne $settings->{attachment_pattern};

  if ($key_changed) {
    $c->model('Library')->update_citekeys($key_pattern);
  }

  # Update files if either attachments or pdf pattern changed, or if
  # key pattern changed and either of them contains [key]
  my $update_files = 0;
  $update_files = 1 if ( $pdf_changed or $attachment_changed );
  $update_files = 1 if ( $key_changed and $pdf_pattern        =~ /\[key\]/ );
  $update_files = 1 if ( $key_changed and $attachment_pattern =~ /\[key\]/ );

  if ($update_files) {
    $c->forward('rename_files');
    $c->model('Library')->set_setting( 'pdf_pattern',        $pdf_pattern );
    $c->model('Library')->set_setting( 'attachment_pattern', $attachment_pattern );
  }

  if ($root_changed) {
    if ( dirmove( $settings->{paper_root}, $paper_root ) ) {
      $c->model('Library')->set_setting( 'paper_root', $paper_root );
    } else {
      FileError->throw("Could not move PDF directory to new location ($!)");
    }
  }

  if ($db_changed) {

    my $ok = 0;
    if ( not -e $library_db ) {
      $ok = move( $settings->{library_db}, $library_db );
    } else {
      $ok = 1;
    }

    if ($ok) {

      # update library_db in session variable and also all active plugins
      # that have stored a reference to the database file
      $c->session->{library_db} = $library_db;
      foreach my $key ( keys %{ $c->session } ) {
        next if not $key =~ /^grid_/;
        next if not $c->session->{$key}->plugin_name eq 'DB';
        if ( $c->session->{$key}->file eq $settings->{library_db} ) {
          $c->session->{$key}->file($library_db);
        }
      }

      # Force reload of tree
      delete $c->session->{tree};
      $c->model('User')->set_setting( 'library_db', $library_db );
    } else {
      FileError->throw("Could not change database file to library_db ($!)");
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

  my $model = $c->model('Library');

  $model->dbh->begin_work;

  my $old_root = $model->get_setting('paper_root');
  my $tmp_root = File::Temp::tempdir( 'paperpile-XXXXXXX', DIR => '/tmp', CLEANUP => 0 );

  eval {

    my $entries = $model->all;

    my %entries_with_attachments = ();

    foreach my $pub ( @{$entries} ) {

      if ( $pub->attachments ) {
        $entries_with_attachments{ $pub->_rowid } = $pub;
      }

      next if not $pub->pdf;

      my $source = File::Spec->catfile( $old_root, $pub->pdf );

      # if a pdf has been removed somehow we skip it and remove path from database
      if ( !-e $source ) {
        $model->dbh->do( "UPDATE Publications SET pdf='' WHERE rowid=" . $pub->_rowid );
        next;
      }

      my $relative_dest = $pub->format_pattern( $pdf_pattern, { key => $pub->citekey } ) . '.pdf';
      my $absolute_dest = File::Spec->catfile( $tmp_root, $relative_dest );

      $absolute_dest = Paperpile::Utils->copy_file( $source, $absolute_dest );
      $relative_dest = File::Spec->abs2rel( $absolute_dest, $tmp_root );

      my $path = $model->dbh->quote($relative_dest);

      $model->dbh->do( "UPDATE Publications SET pdf=$path WHERE rowid=" . $pub->_rowid );

    }

    my ( $pub_id, $attachment_id, $relative_source );

    my $select = $model->dbh->prepare("SELECT rowid, publication_id, file_name FROM Attachments;");
    $select->bind_columns( \$attachment_id, \$pub_id, \$relative_source );
    $select->execute;

    while ( $select->fetch ) {
      my $absolute_source = File::Spec->catfile( $old_root, $relative_source );

      if ( !-e $absolute_source ) {
        $model->dbh->do( "DELETE FROM Attachments WHERE rowid=" . $attachment_id );
        $model->dbh->do( "UPDATE Publications SET attachments=attachments-1 WHERE rowid=$pub_id");
        next;
      }

      my ( $volume, $dirs, $file_name ) = File::Spec->splitpath($absolute_source);

      my $pub = $entries_with_attachments{$pub_id};

      my $relative_dest = $pub->format_pattern( $attachment_pattern, { key => $pub->citekey } );
      $relative_dest = File::Spec->catfile( $relative_dest, $file_name );

      my $absolute_dest = File::Spec->catfile( $tmp_root, $relative_dest );

      $absolute_dest = Paperpile::Utils->copy_file( $absolute_source, $absolute_dest );
      $relative_dest = File::Spec->abs2rel( $absolute_dest, $tmp_root );

      my $path = $model->dbh->quote($relative_dest);

      $model->dbh->do( "UPDATE Attachments SET file_name=$path WHERE rowid=" . $attachment_id );

    }
  };

  if ($@) {
    $model->dbh->rollback;
    my $msg = $@;
    $msg = $@->msg if $@->isa('PaperpileError');
    FileError->throw("Could not apply changes ($msg)");
  }

  if ( not move( $old_root, "$old_root\_backup" ) ) {
    $model->dbh->rollback;
    FileError->throw("Could not apply changes (Error creating backup copy $old_root\_backup)");
  }

  if ( not move( $tmp_root, $old_root ) ) {
    $model->dbh->rollback;
    move( "$old_root\_backup", $old_root )
      or FileError->throw(
      'Could not apply changes and your library is broken now. This should never happen, contact support@paperpile.org if it has happened to you.'
      );
    FileError->throw(
      "Could not apply changes (Error creating new copy of directory tree in $old_root).");
  }

  $model->dbh->commit;
  rmtree("$old_root\_backup");
}

sub set_settings : Local{

  my ( $self, $c ) = @_;

  for my $field ('use_proxy','proxy','proxy_user','proxy_passwd','pager_limit') {
    $c->model('User')->set_setting($field, $c->request->params->{$field});
  }

}




sub _submit {

  my ( $self, $c, $data ) = @_;

  $c->stash->{data}    = $data;
  $c->stash->{success} = 'true';

  $c->detach('Paperpile::View::JSON');
}



1;
