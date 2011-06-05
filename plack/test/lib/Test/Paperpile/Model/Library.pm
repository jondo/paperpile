package Test::Paperpile::Model::Library;

use strict;
use Test::More;
use Test::Exception;

use utf8;
use Paperpile;
use Paperpile::Library::Publication;

use base 'Test::Paperpile';

sub class { 'Paperpile::Model::Library' }

sub startup : Test(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

sub insert_pubs : Tests(60) {

  my ($self) = @_;

  $self->setup_workspace;

  my $model = Paperpile::Utils->get_model('Library');
  my $dbh   = $model->dbh;

  ### Test if all fields are set

  my $data = {
    pubtype      => "Type",
    sortkey      => "Name used for sorting",
    title        => "Title",
    booktitle    => "Book title",
    series       => "Series",
    authors      => "Doe, John",
    editors      => "Editors",
    affiliation  => "Affiliation",
    journal      => "Journal",
    chapter      => "Chapter",
    volume       => "Volume",
    number       => "Number",
    issue        => "Issue",
    edition      => "Edition",
    pages        => "Pages",
    url          => "URL",
    howpublished => "How published",
    publisher    => "Publisher",
    organization => "Organization",
    school       => "University",
    address      => "Address",
    year         => "Year",
    month        => "Month",
    day          => "Day",
    eprint       => "Eprint",
    issn         => "ISSN",
    isbn         => "ISBN",
    pmid         => "Pubmed ID",
    lccn         => "LCCN",
    arxivid      => "ArXiv ID",
    doi          => "DOI",
    abstract     => "Abstract",
    keywords     => "Author key words",
    linkout      => "Website",
    note         => "Note",
    annote => "Annotation with UTF-8 characters: На берегу пустынных волн",
  };

  my $fulltext = {
    title    => "Title",
    author   => "Doe J",
    year     => "Year",
    journal  => "Journal",
    abstract => "Abstract",
    keyword  => "Author key words",
    notes    => "Annotation with UTF-8 characters: На берегу пустынных волн",
  };

  my $pub  = Paperpile::Library::Publication->new($data);
  my $guid = $pub->create_guid;

  $model->insert_pubs( [$pub], 1 );

  $self->row_ok( $model->dbh, "Publications", "guid == '$guid'", $data,     "Publications table" );
  $self->row_ok( $model->dbh, "Fulltext",     "guid == '$guid'", $fulltext, "Fulltext table" );
  like( $pub->_rowid, qr/\d+/, "Rowid is set" );
  is( $pub->_imported, 1, "Imported flag is set" );
  ok( $pub->created, "Created timestamp is set" );
  ok( $pub->citekey, "Citekey is set" );

  ### Test if missing guids are generated and duplicate sha1s are skipped

  $pub = Paperpile::Library::Publication->new(
    authors => "Do, J",
    title   => "Test Title",
    journal => "Test Journal"
  );

  my $sha1 = $pub->sha1;

  $model->insert_pubs( [$pub], 1 );
  ok( $pub->guid, "guid is set if not set before" );
  $self->row_ok( $model->dbh, "Publications", "sha1=='$sha1'", { authors => "Do, J" } );

  $model->insert_pubs( [$pub], 1 );
  is( $pub->_insert_skipped, 1, "Entry with duplicate sha1 is skipped." );


  ### Test label creation

  # Not user database: labels_tmp is set
  $pub = Paperpile::Library::Publication->new(
    authors    => "Mustermann, M",
    labels_tmp => 'New Testlabel',
  );

  $guid = $pub->create_guid;

  $model->insert_pubs( [$pub], 0 );

  $self->row_ok(
    $model->dbh, "Publications",
    "guid == '$guid'",
    { labels_tmp => 'New Testlabel', labels => '' },
    "Not user database: "
  );

  # User database: labels are imported and labels field is set
  $pub = Paperpile::Library::Publication->new(
    authors    => "Habicht, H",
    labels_tmp => 'New Testlabel',
  );

  $guid = $pub->create_guid;

  $model->insert_pubs( [$pub], 1 );

  my $row = $self->row_ok(
    $model->dbh, "Publications",
    "guid == '$guid'",
    { labels_tmp => '', labels_DEFINED => '' },
    "User database:"
  );

  my $label_guid = $row->{labels};

  $self->row_ok(
    $model->dbh, "Collections",
    "guid == '$label_guid'",
    { name => 'New Testlabel' },
    "Label in collection table:"
  );





}


1;
