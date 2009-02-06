package Bibutils;
use Moose;

use 5.010000;
use Carp;
use XSLoader;
use Data::Dumper;

our $VERSION = '0.01';
XSLoader::load( 'Bibutils', $VERSION );

has 'in_file'    => ( is => 'rw', isa => 'Str' );
has 'out_file'   => ( is => 'rw', isa => 'Str' );
has 'in_format'  => ( is => 'rw', isa => 'Str' );
has 'out_format' => ( is => 'rw', isa => 'Str' );
has '_bibpointer' => ( is => 'rw' );

sub read{
  my $self=shift;

  $self->_bibpointer(Bibutils::c_read($self->in_file, $self->in_format));
}

sub write{
  my $self=shift;

  Bibutils::c_write($self->out_file, $self->out_format, $self->_bibpointer);

}

sub get_data {
  my $self = shift;

  my @bibs = ();

  my $N = Bibutils::c_get_n_entries( $self->_bibpointer );

  foreach my $i ( 0 .. $N - 1 ) {

    my @fields = ();

    my $n = Bibutils::c_get_n_fields( $self->_bibpointer, $i );
    foreach my $j ( 0 .. $n - 1 ) {

      my ( $tag, $data, $level ) = (
        c_get_field_tag( $self->_bibpointer, $i, $j ),
        c_get_field_data( $self->_bibpointer, $i, $j ),
        c_get_field_level( $self->_bibpointer, $i, $j )
      );

      push @fields, { tag => $tag, data => $data, level => $level };
    }
    push @bibs,[@fields];
  }

  return [@bibs];
}

sub set_data {
  my ( $self, $data ) = @_;

  my $N = @$data;

  $b = Bibutils::c_new();

  foreach my $i ( 0 .. $N -1 ) {
    my $fields=Bibutils::fields_new();
    my $n=@{$data->[$i]};

    foreach my $j (0..$n-1){
      Bibutils::fields_add($fields,
                           $data->[$i]->[$j]->{tag},
                           $data->[$i]->[$j]->{data},
                           $data->[$i]->[$j]->{level},
                          );
    }

    Bibutils::bibl_addref( $b, $fields )

  }

  $self->_bibpointer($b);

}

sub cleanup {
  my $self = shift;
  Bibutils::bibl_free($self->_bibpointer);

  $self->_bibpointer(undef);


}

sub error{
  return Bibutils::c_get_error();
}

no Moose;

use constant {
  'OK'                  => 0,
  'ERR_BADINPUT'        => -1,
  'ERR_MEMERR'          => -2,
  'ERR_CANTOPEN'        => -3,
  'FORMAT_VERBOSE'      => 1,
  'RAW_WITHCHARCONVERT' => 4,
  'RAW_WITHMAKEREFID'   => 8,
  'CHARSET_UNKNOWN'     => -1,
  'CHARSET_UNICODE'     => -2,
  'CHARSET_GB18030'     => -3,
  'CHARSET_DEFAULT'     => 66,
  'SRC_DEFAULT'         => 1,
  'SRC_FILE'            => 1,
  'SRC_USER'            => 2,
  'MODSIN'              => 100,
  'BIBTEXIN'            => 101,
  'RISIN'               => 102,
  'ENDNOTEIN'           => 103,
  'COPACIN'             => 104,
  'ISIIN'               => 105,
  'MEDLINEIN'           => 106,
  'ENDNOTEXMLIN'        => 107,
  'BIBLATEXIN'          => 108,
  'MODSOUT'             => 200,
  'BIBTEXOUT'           => 201,
  'RISOUT'              => 202,
  'ENDNOTEOUT'          => 203,
  'ISIOUT'              => 204,
  'WORD2007OUT'         => 205,
  'ADSABSOUT'           => 206,
  'LASTOUT'             => 207,
};

1;

__END__

# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Bibutils - Perl wrapper for the Bibutils library

=head1 SYNOPSIS

  use Bibutils;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Bibutils, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Stefan Washietl, E<lt>wash@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Stefan Washietl

This library is free software; you can redistribute it and/or
    modify it under the same terms as Perl itself, either Perl version 5.10.0
    or,
  at your option, any later version of Perl 5 you may have available
    .

=cut
