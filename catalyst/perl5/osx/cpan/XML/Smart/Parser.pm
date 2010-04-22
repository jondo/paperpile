#############################################################################
## Name:        Parser.pm
## Purpose:     XML::Smart::Parser
## Author:      Paul Kulchenko (paulclinger@yahoo.com)
## Modified by: Graciliano M. P.
## Created:     10/05/2003
## RCS-ID:      
## Copyright:   2000-2001 Paul Kulchenko
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
##
## This module is actualy XML::Parser::Lite (with some updates). It's here
## just for convenience.
##
## See original code at CPAN for full source and POD.
##
## This module will be used when XML::Parser is not installed.
#############################################################################

# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: Lite.pm,v 1.4 2001/10/15 21:25:05 paulk Exp $
#
# Changes: Graciliano M. P. <gm@virtuasites.com.br>
#
# ======================================================================

package XML::Smart::Parser ;

no warnings ;
use strict;
use vars qw($VERSION);
$VERSION = 1.2 ;

my(@parsed , @stack, $level) ;

 &compile();

sub new { 
  my $class = ($_[0] =~ /^[\w:]+$/) ? shift(@_) : __PACKAGE__ ;
  my $this = bless {} , $class ;

  my %args = @_ ;
  $this->setHandlers(%args) ;
  
  $this->{NOENTITY} = 1 ;

  return $this ;
}

sub setHandlers {
  my $this = shift ;
  my %args = @_;
    
  $this->{Init}  = $args{Init} || sub{} ;
  $this->{Start} = $args{Start} || sub{} ;
  $this->{Char}  = $args{Char} || sub{} ;
  $this->{End}   = $args{End} || sub{} ;
  $this->{Final} = $args{Final} || sub{} ;
  
  return 1 ;
}

sub regexp {
  my $patch = shift || '' ;
  my $package = __PACKAGE__ ;

  my $TextSE = "[^<]+";
  my $UntilHyphen = "[^-]*-";
  my $Until2Hyphens = "$UntilHyphen(?:[^-]$UntilHyphen)*-";
  my $CommentCE = "$Until2Hyphens>?";
  my $UntilRSBs = "[^\\]]*](?:[^\\]]+])*]+";
  my $CDATA_CE = "$UntilRSBs(?:[^\\]>]$UntilRSBs)*>";
  my $S = "[ \\n\\t\\r]+";
  my $NameStrt = "[A-Za-z_:]|[^\\x00-\\x7F]";
  my $NameChar = "[A-Za-z0-9_:.-]|[^\\x00-\\x7F]";
  my $Name = "(?:$NameStrt)(?:$NameChar)*";
  my $QuoteSE = "\"[^\"]*\"|'[^']*'";
  my $DT_IdentSE = "$S$Name(?:$S(?:$Name|$QuoteSE))*";
  my $MarkupDeclCE = "(?:[^\\]\"'><]+|$QuoteSE)*>";
  my $S1 = "[\\n\\r\\t ]";
  my $UntilQMs = "[^?]*\\?+";
  my $PI_Tail = "\\?>|$S1$UntilQMs(?:[^>?]$UntilQMs)*>";
  my $DT_ItemSE = "<(?:!(?:--$Until2Hyphens>|[^-]$MarkupDeclCE)|\\?$Name(?:$PI_Tail))|%$Name;|$S";
  my $DocTypeCE = "$DT_IdentSE(?:$S)?(?:\\[(?:$DT_ItemSE)*](?:$S)?)?>?";
  my $DeclCE = "--(?:$CommentCE)?|\\[CDATA\\[(?:($CDATA_CE)(?{${package}::char_CDATA(\$2)}))?|DOCTYPE(?:$DocTypeCE)?";
  my $PI_CE = "$Name(?:$PI_Tail)?";

  my $EndTagCE = "($Name)(?{${package}::end(\$3)})(?:$S)?>";
  my $AttValSE = "\"([^<\"]*)\"|'([^<']*)'";
  my $ElemTagCE = "($Name)(?:$S($Name)(?:$S)?=(?:$S)?(?:$AttValSE)(?{[\@{\$^R||[]},\$5=>defined\$6?\$6:\$7]}))*(?:$S)?(/)?>(?{${package}::start(\$4,\@{\$^R||[]})})(?{\${8} and ${package}::end(\$4)})";
  my $MarkupSPE = "<(?:!(?:$DeclCE)?|\\?(?:$PI_CE)?|/(?:$EndTagCE)?|(?:$ElemTagCE)?)";

  "(?:($TextSE)(?{${package}::char(\$1)}))$patch|$MarkupSPE";
}

sub compile {
  local $^W; 
  
  foreach (regexp(), regexp('??')) {
    eval qq{sub parse_re { use re "eval"; 1 while \$_[0] =~ m{$_}go }; 1} or die;
    last if eval { parse_re('<foo>bar</foo>'); 1 }
  };

  *compile = sub {};
}

sub parse {
  my $this = shift ;
  
  @parsed = () ;
  
  init();
  parse_re($_[0]);
  final();

  no strict qw(refs);
  
  my $final = pop(@parsed) ; pop(@parsed) ;

  for (my $i = 0 ; $i <= $#parsed ; $i+=2) {
    my $args = $parsed[$i+1] ;
    &{$this->{$parsed[$i]}}($this , (ref($args) ? @{$args} : $args) ) ;
  }

  @parsed = () ;

  return &{$this->{Final}}($this, @{$final}) ;
}

sub init {
  @stack = (); $level = 0;
  push(@parsed , 'Init' , [@_]) ;
  return ;
}

sub final {
  die "not properly closed tag '$stack[-1]'\n" if @stack;
  die "no element found\n" unless $level;
  push(@parsed , 'Final' , [@_]) ;
  return ;
} 

sub start {
  die "multiple roots, wrong element '$_[0]'\n" if $level++ && !@stack;
  push(@stack, $_[0]);
  push(@parsed , 'Start' , [@_]) ;
  return ;
}

sub char {
  push(@parsed , 'Char' , [@_]) , return if @stack;

  for (my $i=0; $i < length $_[0]; $i++) {
    die "junk '$_[0]' @{[$level ? 'after' : 'before']} XML element\n"
      if index("\n\r\t ", substr($_[0],$i,1)) < 0; # or should '< $[' be there
  }
  return ;
}

sub char_CDATA {
  &char( substr($_[0] , 0 , -3) ) ;
}

sub end {
  pop(@stack) eq $_[0] or die "mismatched tag '$_[0]'\n";
  push(@parsed , 'End' , [@_]) ;
  return ;
}

# ======================================================================

1;


