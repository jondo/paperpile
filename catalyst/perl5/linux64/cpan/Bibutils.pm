package Bibutils;
use Moose;

use 5.010000;
use Carp;
use XSLoader;
use File::Temp qw/ :seekable /;
use Encode qw /decode_utf8/;


use Data::Dumper;

our $VERSION = '0.01';
XSLoader::load( 'Bibutils', $VERSION );

has 'in_file'    => ( is => 'rw', isa => 'Str' );
has 'out_file'   => ( is => 'rw', isa => 'Str' );
has 'in_format'  => ( is => 'rw', isa => 'Str' );
has 'out_format' => ( is => 'rw', isa => 'Str' );
has '_bibpointer' => ( is => 'rw' );


sub read {
  my $self=shift;

  $self->_bibpointer(Bibutils::c_read($self->in_file, $self->in_format));
  return 1; # Check error codes if it really was successfull
}

sub write {
  my ( $self, $settings ) = @_;

  my $s=$self->_process_settings($settings);

  Bibutils::c_write( $self->out_file, $self->out_format, $self->_bibpointer,
                     $s->{charsetout},
                     $s->{latexout},
                     $s->{utf8out},
                     $s->{xmlout},
                     $s->{format_opts}
                   );
  return 1;    # Check error codes if it really was successfull
}

sub as_string{

  my ( $self, $settings ) = @_;

  my $s=$self->_process_settings($settings);

  my $fh = File::Temp->new();
  my $file = $fh->filename;

  $fh->unlink_on_destroy( 1 );

  Bibutils::c_write($file, $self->out_format, $self->_bibpointer,
                    $s->{charsetout},
                    $s->{latexout},
                    $s->{utf8out},
                    $s->{xmlout},
                    $s->{format_opts}
                   );

  $fh->seek(0,SEEK_SET);

  my $string='';

  $string.=$_ foreach  (<$fh>);

  return $string;

}


sub get_data {
  my $self = shift;

  my @bibs = ();

  my $bibpointer =  $self->_bibpointer;

  my $N = Bibutils::c_get_n_entries( $bibpointer );

  foreach my $i ( 0 .. $N - 1 ) {

    my @fields = ();

    my $n = Bibutils::c_get_n_fields( $bibpointer, $i );
    foreach my $j ( 0 .. $n - 1 ) {

      my ( $tag, $data, $level ) = (
        c_get_field_tag( $bibpointer, $i, $j ),
        c_get_field_data( $bibpointer, $i, $j ),
        c_get_field_level( $bibpointer, $i, $j )
      );

      push @fields, { tag => $tag, data => decode_utf8($data), level => $level };
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

sub _process_settings {

  my ( $self, $settings ) = @_;

  # 999 indicates the c-backend to use the defaults as suggested by the bibutils library
  my $default_settings = {
    charsetout  => 999,
    latexout    => 999,
    utf8out     => 999,
    xmlout      => 999,
    format_opts => 999
  };

  # Format options are specified via OR operations and the following options are supported
  # (see bibtexout.h for their original definition)
  my $format_codes = {
    bibout_finalcomma => 2,
    bibout_singledash => 4,
    bibout_whitespace => 8,
    bibout_brackets   => 16,
    bibout_uppercase  => 32,
    bibout_strictkey  => 64,
    modsout_dropkey   => 2,
    wordout_dropkey   => 2,
  };

  my $s = $default_settings;

  if ($settings) {
    for my $key ( keys %$settings ) {
      if (exists $format_codes->{$key}){
        # if nothing was set before init first to 0
        $s->{format_opts}=0 if $s->{format_opts}==999;
        # apply code to bitmask
        $s->{format_opts}|=$format_codes->{$key};
      }

      $s->{$key} = $settings->{$key};
    }
  }

  return {%$s};
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
