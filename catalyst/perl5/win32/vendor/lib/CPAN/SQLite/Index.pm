package CPAN::SQLite::Index;
use strict;
use warnings;
use CPAN::SQLite::Info;
use CPAN::SQLite::State;
use CPAN::SQLite::Populate;
use CPAN::SQLite::DBI qw($tables);
use File::Spec::Functions qw(catfile);
use File::Basename;
use File::Path;
use LWP::Simple qw(getstore is_success);

our $VERSION = '0.199';
unless ($ENV{CPAN_SQLITE_NO_LOG_FILES}) {
  $ENV{CPAN_SQLITE_DEBUG} = 1;
}

our ($oldout);
my $log_file = 'cpan_sqlite_log.' . time;

sub new {
  my ($class, %args) = @_;
  if ($args{setup} and $args{reindex}) {
    die "Reindexing must be done on an exisiting database";
  }

  my $self = {index => undef, state => undef, %args};
  bless $self, $class;
}

sub index {
  my ($self, %args) = @_;
  my $setup = $self->{setup};

  if ($setup) {
    my $db_name = catfile($self->{db_dir}, $self->{db_name});
    if (-f $db_name) {
      warn qq{Removing existing $db_name\n};
      unlink $db_name or warn qq{Cannot unlink $db_name: $!};
    }
  }
  my $log = catfile($self->{log_dir}, $log_file);
  unless ($ENV{CPAN_SQLITE_NO_LOG_FILES}) {
    $oldout = error_fh($log);
  }

  if ($self->{update_indices}) {
    warn qq{Fetching index files ...\n};
    $self->fetch_cpan_indices() or do {
      warn qq{fetch_cpan_indices() failed};
      return;
    }
  }

  warn qq{Gathering information from index files ...\n};
  $self->fetch_info or do {
    warn qq{fetch_info() failed!};
    return;
  };
  unless ($setup) {
    warn qq{Obtaining current state of database ...\n};
    $self->state or do {
      warn qq{state() failed!};
      return;
    };
  }
  warn qq{Populating database tables ...\n};
  $self->populate or do {
    warn qq{populate() failed!};
    return;
  };
  return 1;
}

sub fetch_cpan_indices {
  my ($self, %args) = @_;
  my $CPAN = $self->{CPAN};
  my $indices = {'01mailrc.txt.gz' => 'authors',
		 '02packages.details.txt.gz' => 'modules',
		 '03modlist.data.gz' => 'modules',
		};
  foreach my $index (keys %$indices) {
    my $file = catfile($CPAN, $indices->{$index}, $index);
    next if (-e $file and -M $file < 1);
    my $dir = dirname($file);
    unless (-d $dir) {
      mkpath($dir, 1, 0755) or die "Cannot mkpath $dir: $!";
    }
    my @urllist = @{$self->{urllist}};
    foreach my $cpan(@urllist) {
      my $from = join '/', ($cpan, $indices->{$index}, $index);
      last if is_success(getstore($from, $file));
    }
    unless (-f $file) {
      warn qq{Cannot retrieve '$file'};
      return;
    }
  }
  return 1;
}

sub fetch_info {
  my $self = shift;
  my %wanted = map {$_ => $self->{$_}} qw(CPAN ignore keep_source_where);
  my $info = CPAN::SQLite::Info->new(%wanted);
  $info->fetch_info() or return;
  my @tables = qw(dists mods auths);
  my $index;
  foreach my $table(@tables) {
    my $class = __PACKAGE__ . '::' . $table;
    my $this = {info => $info->{$table}};
    $index->{$table} = bless $this, $class;
  }
  $self->{index} = $index;
  return 1;
}

sub state {
  my $self = shift;

  my %wanted = map {$_ => $self->{$_}} 
    qw(db_name index setup reindex db_dir);
  my $state = CPAN::SQLite::State->new(%wanted);
  $state->state() or return;
  $self->{state} = $state;
  return 1;
}

sub populate {
  my $self = shift;
  my %wanted = map {$_ => $self->{$_}} 
    qw(db_name index setup state db_dir);
  my $db = CPAN::SQLite::Populate->new(%wanted);
  $db->populate() or return;
  return 1;
}

sub error_fh {
  my $file = shift;
  open(my $tmp, '>', $file) or die "Cannot open $file: $!";
  close $tmp;
  open(my $oldout, '>&STDOUT');
  open(STDOUT, '>', $file) or die "Cannot tie STDOUT to $file: $!";
  select STDOUT; $| = 1;
  return $oldout;
}

sub DESTROY {
  unless ($ENV{CPAN_SQLITE_NO_LOG_FILES}) {
    close STDOUT;
    open(STDOUT, ">&$oldout");
  }
}

1;

__END__

=head1 NAME

CPAN::SQLite::Index - set up or update database tables.

=head1 SYNOPSIS

 my $index = CPAN::SQLite::Index->new(setup => 1);
 $index->index();

=head1 DESCRIPTION

This is the main module used to set up or update the
database tables used to store information from the
CPAN and ppm indices. The creation of the object

 my $index = CPAN::SQLite::Index->new(%args);

accepts two possible arguments:

=over 3

=item * setup =E<gt> 1

This (optional) argument specifies that the database is being set up.
Any existing tables will be dropped.

=item * reindex =E<gt> value

This (optional) argument specifies distribution names that
one would like to reindex in an existing database. These may
be specified as either a scalar, for a single distribution,
or as an array reference for a list of distributions.

=back

=head1 DETAILS

Calling

  $index->index();

will start the indexing procedure. Various messages
detailing the progress will written to I<STDOUT>,
which by default will be captured into a file 
F<cpan_sqlite_log.dddddddddd>, where the extension
is the C<time> that the method was invoked. Error messages
are not captured, and will appear in I<STDERR>.

The steps of the indexing procedure are as follows.

=over 3

=item * fetch index data

The necessary CPAN index files 
F<$CPAN/authors/01mailrc.txt.gz>,
F<$CPAN/modules/02packages.details.txt.gz>, and
F<$CPAN/modules/03modlist.data.gz> will be fetched
from the CPAN mirror specified by the C<$cpan> variable
at the beginning of L<CPAN::SQLite::Index>. If you are
using this option, it is recommended to use the
same CPAN mirror with subsequent updates, to ensure consistency 
of the database. As well, the information on the locations
of the CPAN mirrors used for Template-Toolkit and GeoIP
is written.

=item * get index information

Information from the CPAN indices is extracted through
L<CPAN::SQLite::Info>.

=item * get state information

Unless the C<setup> argument within the C<new>
method of L<CPAN::SQLite::Index> is specified,
this will get information on the state of the database
through L<CPAN::SQLite::State>.
A comparision is then made between this information
and that gathered from the CPAN indices, and if there's
a discrepency in some items, those items are marked
for either insertion, updating, or deletion, as appropriate.

=item * populate the database

At this stage the gathered information is used to populate
the database, through L<CPAN::SQLite::Populate>,
either inserting new items, updating
existing ones, or deleting obsolete items.

=back

=head1 SEE ALSO

L<CPAN::SQLite::Info>, L<CPAN::SQLite::State>, 
L<CPAN::SQLite::Populate>,
and L<CPAN::SQLite::Util>.
Development takes place on the CPAN-SQLite project
at L<http://sourceforge.net/projects/cpan-search/>.

=head1 COPYRIGHT

This software is copyright 2006 by Randy Kobes
E<lt>r.kobes@uwinnipeg.caE<gt>. Use and
redistribution are under the same terms as Perl itself.

=cut
