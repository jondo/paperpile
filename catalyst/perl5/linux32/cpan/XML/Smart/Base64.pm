#############################################################################
## Name:        Base64.pm
## Purpose:     XML::Smart::Base64
## Author:      Graciliano M. P.
## Modified by:
## Created:     25/5/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package XML::Smart::Base64 ;
our $VERSION = '1.0' ;

no warnings ;

my ($BASE64_PM) ;
eval("use MIME::Base64 ()") ;
if ( defined &MIME::Base64::encode_base64 ) { $BASE64_PM = 1 ;}

#################
# ENCODE_BASE64 #
#################

sub encode_base64 {
  if ( $BASE64_PM ) { return &MIME::Base64::encode_base64($_[0]) ;}
  else { return &_encode_base64_pure_perl($_[0]) ;}
}

############################
# _ENCODE_BASE64_PURE_PERL #
############################

sub _encode_base64_pure_perl {
  my $res = "";
  my $eol = $_[1];
  $eol = "\n" unless defined $eol;
  pos($_[0]) = 0;                          # ensure start at the beginning
  while ($_[0] =~ /(.{1,45})/gs) {
	$res .= substr(pack('u', $1), 1);
	chop($res);
  }
  $res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
  # fix padding at the end
  my $padding = (3 - length($_[0]) % 3) % 3;
  $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
  # break encoded string into lines of no more than 76 characters each
  if (length $eol) {
	$res =~ s/(.{1,76})/$1$eol/g;
  }
  $res;
}

#################
# DECODE_BASE64 #
#################

sub decode_base64 {
  if ( $BASE64_PM ) { return &MIME::Base64::decode_base64($_[0]) ;}
  else { return &_decode_base64_pure_perl($_[0]) ;}
}


############################
# _DECODE_BASE64_PURE_PERL #
############################

sub _decode_base64_pure_perl {
  local($^W) = 0 ;
  my $str = shift ;
  my $res = "";

  $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
  if (length($str) % 4) {
	#require Carp;
	#Carp::carp("Length of base64 data not a multiple of 4")
  }
  $str =~ s/=+$//;                        # remove padding
  $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
  while ($str =~ /(.{1,60})/gs) {
	my $len = chr(32 + length($1)*3/4); # compute length byte
	$res .= unpack("u", $len . $1 );    # uudecode
  }
  $res;
}

#######
# END #
#######

1;


