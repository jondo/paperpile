#############################################################################
## Name:        Tree.pm
## Purpose:     XML::Smart::Tree
## Author:      Graciliano M. P.
## Modified by:
## Created:     10/05/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package XML::Smart::Tree ;

use XML::Smart::Entity qw(_parse_basic_entity) ;

use strict qw(vars) ;
no warnings ;

our ($VERSION) ;
$VERSION = '1.0' ;

  my %PARSERS = (
  XML_Parser => 0 ,
  XML_Smart_Parser => 0 ,
  XML_Smart_HTMLParser => 0 ,
  ) ;
  
  my $DEFAULT_LOADED ;
  
  use vars qw($NO_XML_PARSER);
  
  my ( $SIG_WARN , $SIG_DIE )  ;

sub _unset_sig_warn {
  $SIG_WARN = $SIG{__WARN__} ;
  $SIG_DIE = $SIG{__DIE__} ;
  $SIG{__WARN__} = sub {} ;
  $SIG{__DIE__} = sub {} ;
}

sub _reset_sig_warn {
  $SIG{__WARN__} = $SIG_WARN ;
  $SIG{__DIE__} = $SIG_DIE ;
}

###################
# LOAD_XML_PARSER #
###################

sub load_XML_Parser {
  return if $NO_XML_PARSER ;
  
  eval {
    _unset_sig_warn() ;
      eval('use XML::Parser ;') ;
    _reset_sig_warn() ;
    if ($@) { $@ = undef ; return( undef ) ;}
  } ;
  
  my ($xml , $tree) ;
  
  eval {
    _unset_sig_warn() ;
      no strict ;
      my $data = '<root><foo arg1="t1" arg2="t2" /></root>' ;
      $xml = XML::Parser->new(Style => 'Tree') ;
      $tree = $xml->parse($data) ;
    _reset_sig_warn() ;
  } ;
  
  if (!$tree || ref($tree) ne 'ARRAY') { return( undef ) ;}
  if ($tree->[1][2][0]{arg1} eq 't1') { return( 1 ) ;}
  return( undef ) ;
}

#########################
# LOAD_XML_SMART_PARSER #
#########################

sub load_XML_Smart_Parser {
  _unset_sig_warn() ;
    eval('use XML::Smart::Parser ;') ;
  _reset_sig_warn() ;
  if ($@) { $@ = undef ; return( undef ) ;}
  return(1) ;
}

#############################
# LOAD_XML_SMART_HTMLPARSER #
#############################

sub load_XML_Smart_HTMLParser {
  _unset_sig_warn() ;
    eval('use XML::Smart::HTMLParser ;') ;
  _reset_sig_warn() ;
  if ($@) { $@ = undef ; return( undef ) ;}
  return(1) ;
}

########
# LOAD #
########

sub load {
  my ( $parser ) = @_ ;
  my $module ;
  
  if ($parser) {
    $parser =~ s/:+/_/gs ;
    $parser =~ s/\W//g ;
    
    if    ($parser =~ /^(?:html?|wild)$/i) { $parser = 'XML_Smart_HTMLParser' ;}
    elsif ($parser =~ /^(?:re|smart)/i) { $parser = 'XML_Smart_Parser' ;}
    
    foreach my $Key ( keys %PARSERS ) {
      if ($Key =~ /^$parser$/i) { $module = $Key ; last ;}
    }
  }
  
  my $ok ;
  if ($module eq 'XML_Parser') {
    $PARSERS{XML_Parser} = 1 if &load_XML_Parser() ;
    $ok = $PARSERS{XML_Parser} ;
  }
  elsif ($module eq 'XML_Smart_Parser') {
    $PARSERS{XML_Smart_Parser} = 1 if !$PARSERS{XML_Smart_Parser} && &load_XML_Smart_Parser() ;
    $ok = $PARSERS{XML_Smart_Parser} ;
  }
  elsif ($module eq 'XML_Smart_HTMLParser') {
    $PARSERS{XML_Smart_HTMLParser} = 1 if !$PARSERS{XML_Smart_HTMLParser} && &load_XML_Smart_HTMLParser() ;
    $ok = $PARSERS{XML_Smart_HTMLParser} ;
  }
  
  if (!$ok && !$DEFAULT_LOADED) {
    $PARSERS{XML_Parser} = 1 if &load_XML_Parser() ;
    $module = 'XML_Parser' ;
    if ( !$PARSERS{XML_Parser} ) {
      $PARSERS{XML_Smart_Parser} = 1 if &load_XML_Smart_Parser() ;  
      $module = 'XML_Smart_Parser' ;
    }
    $DEFAULT_LOADED = 1 ;
  }
  
  return($module) ;
}

#########
# PARSE #
#########

sub parse {
  my $module = $_[1] ;
  
  my $data ;
  {
    my ($fh,$open) ;
    
    if (ref($_[0]) eq 'GLOB') { $fh = $_[0] ;}
    elsif ($_[0] =~ /^http:\/\/\w+[^\r\n]+$/s) { $data = &get_url($_[0]) ;}
    elsif ($_[0] =~ /<.*?>/s) { $data = $_[0] ;}
    else { open ($fh,$_[0]) ; binmode($fh) ; $open = 1 ;}
    
    if ($fh) {
      1 while( read($fh, $data , 1024*8 , length($data) ) ) ;
      close($fh) if $open ;
    }
  }
  
  if ($data !~ /<.*?>/s) { return( {} ) ;}
  
  if (!$module || !$PARSERS{$module}) {
    if    ( !$NO_XML_PARSER && $INC{'XML/Parser.pm'} && $PARSERS{XML_Parser}) { $module = 'XML_Parser' ;}
    elsif ($PARSERS{XML_Smart_Parser}) { $module = 'XML_Smart_Parser' ;}
  }
  
  my $xml ;
  if ($module eq 'XML_Parser') { $xml = XML::Parser->new() ;}
  elsif ($module eq 'XML_Smart_Parser') { $xml = XML::Smart::Parser->new() ;}
  elsif ($module eq 'XML_Smart_HTMLParser') { $xml = XML::Smart::HTMLParser->new() ;}
  else { croak("Can't find a parser for XML!") ;}
  
  shift(@_) ;
  if ( $_[0] =~ /^\s*(?:XML_\w+|html?|re\w+|smart)\s*$/i) { shift(@_) ;}

  my ( %args ) = @_ ;
  
  if ( $args{lowtag} ) { $xml->{SMART}{tag} = 1 ;}
  if ( $args{upertag} ) { $xml->{SMART}{tag} = 2 ;}
  if ( $args{lowarg} ) { $xml->{SMART}{arg} = 1 ;}
  if ( $args{uperarg} ) { $xml->{SMART}{arg} = 2 ;}
  if ( $args{arg_single} ) { $xml->{SMART}{arg_single} = 1 ;}  

  if ( $args{no_order} ) { $xml->{SMART}{no_order} = 1 ;}
  if ( $args{no_nodes} ) { $xml->{SMART}{no_nodes} = 1 ;}
  
  if ( $args{use_spaces} ) { $xml->{SMART}{use_spaces} = 1 ;}
  
  $xml->{SMART}{on_start} = $args{on_start} if ref($args{on_start}) eq 'CODE' ;
  $xml->{SMART}{on_char}  = $args{on_char}  if ref($args{on_char})  eq 'CODE' ;
  $xml->{SMART}{on_end}   = $args{on_end}   if ref($args{on_end})   eq 'CODE' ;
  
  $xml->setHandlers(
  Init => \&_Init ,
  Start => \&_Start ,
  Char  => \&_Char ,
  End   => \&_End ,
  Final => \&_Final ,
  ) ;
  
  my $tree = $xml->parse($data);
  return( $tree ) ;
}

###########
# GET_URL #
###########

sub get_url {
  my ( $url ) = @_ ;
  my $data ;
  
  require LWP ;
  require LWP::UserAgent ;

  my $ua = LWP::UserAgent->new();
  
  my $agent = $ua->agent() ;
  $agent = "XML::Smart/$XML::Smart::VERSION $agent" ;
  $ua->agent($agent) ;

  my $req = HTTP::Request->new(GET => $url) ;
  my $res = $ua->request($req) ;

  if ($res->is_success) { return $res->content ;}
  else { return undef ;}
}

##########
# MODULE #
##########

sub module {
  foreach my $Key ( keys %PARSERS ) {
    if ($PARSERS{$Key}) {
      my $module = $Key ;
      $module =~ s/_/::/g ;
      return( $module ) ;
    }
  }
  return('') ;
}

#########
# _INIT #
#########

sub _Init {
  my $this = shift ;
  $this->{PARSING}{tree} = {} ;
  $this->{PARSING}{p} = $this->{PARSING}{tree} ;
  
  return ;
}

##########
# _START #
##########

sub _Start {
  my $this = shift ;
  
  if ( $this->{LAST_CALL} eq 'char' ) { _Char_process( $this , delete $this->{CONTENT_BUFFER} ) ;}
  
  ##print "START>> @_\n" ;
  
  $this->{LAST_CALL} = 'start' ;
  
  my ($tag , %args) = @_ ;
  
  if    ( $this->{SMART}{tag} == 1 ) { $tag = lc($tag) ;}
  elsif ( $this->{SMART}{tag} == 2 ) { $tag = uc($tag) ;}
  
  $this->{PARSING}{p}{'/nodes'}{$tag} = 1 if !$this->{SMART}{no_nodes} ;
  
  push( @{$this->{PARSING}{p}{'/order'}} , $tag) if !$this->{SMART}{no_order} ;
  
  if ( $this->{SMART}{arg} ) {
    my $type = $this->{SMART}{arg} ;
    my %argsok ;
    foreach my $Key ( keys %args ) {
      my $k ;
      if    ($type == 1) { $k = lc($Key) ;}
      elsif ($type == 2) { $k = uc($Key) ;}
      
      if (exists $argsok{$k}) {
        if ( ref $argsok{$k} ne 'ARRAY' ) {
          my $key = $argsok{$k} ; 
          $argsok{$k} = [$key] ;
        }
        push(@{$argsok{$k}} , $args{$Key}) ;
      }
      else { $argsok{$k} = $args{$Key} ;}
    }
    
    %args = %argsok ;
  }
  
  if ( $this->{SMART}{arg_single} ) {
    foreach my $Key ( keys %args ) {
      $args{$Key} = 1 if !defined $args{$Key} ;
    }
  }
  
  ## Args order:
  if ( !$this->{SMART}{no_order} ) {
    my @order ; 
    for(my $i = 1 ; $i < $#_ ; $i+=2) { push( @order , $_[$i] ) ;}
    
    if ( $this->{SMART}{arg} ) {
      my $type = $this->{SMART}{arg} ;
      foreach my $order_i ( @order ) {
        if    ($type == 1) { $order_i = lc($order_i) ;}
        elsif ($type == 2) { $order_i = uc($order_i) ;}
      }
    }
    
    $args{'/order'} = \@order if @order ;
  }

  $args{'/tag'} = $tag ;
  $args{'/back'} = $this->{PARSING}{p} ;
  
  if ($this->{NOENTITY}) {
    foreach my $Key ( keys %args ) { &_parse_basic_entity( $args{$Key} ) ;}
  }
  
  if ( defined $this->{PARSING}{p}{$tag} ) {
    if ( ref($this->{PARSING}{p}{$tag}) ne 'ARRAY' ) {
      my $prev = $this->{PARSING}{p}{$tag} ;
      $this->{PARSING}{p}{$tag} = [$prev] ;
    }
    push(@{$this->{PARSING}{p}{$tag}} , \%args) ;
    
    my $i = @{$this->{PARSING}{p}{$tag}} ; $i-- ;
    $args{'/i'} = $i ;
    
    $this->{PARSING}{p} = \%args ;
  }
  else {
    $this->{PARSING}{p}{$tag} = \%args ;
    ## Change the pointer:
    $this->{PARSING}{p} = \%args ;
  }
  
  if ( $this->{SMART}{on_start} ) {
    my $sub = $this->{SMART}{on_start} ;
    &$sub($tag , $this->{PARSING}{p} , $this->{PARSING}{p}{'/back'} , undef , $this ) ;
  }
  
  return ;
}

#########
# _CHAR #
#########
#
# XML::Parser parse each line as a different call to _Char().
# For XML::Smart multiple calls to _Char() occurs only when the content
# have other nodes inside.
#

sub _Char { ##print "CHAR>>\n" ;
  my $this = shift ;
  $this->{CONTENT_BUFFER} .= $_[0] ;
  $this->{LAST_CALL} = 'char' ;
  return ;
}

sub _Char_process {
  my $this = shift ;
  ##print "CONT>> ##@_##\n" ;

  my $content = $_[0] ;
  
  if ( !$this->{SMART}{use_spaces} && $content !~ /\S+/s ) { return ;}

  ######
  
  if (! defined $this->{PARSING}{p}{'dt:dt'} && defined $this->{PARSING}{p}{'DT:DT'}) {
    $this->{PARSING}{p}{'dt:dt'} = delete $this->{PARSING}{p}{'DT:DT'} ;
  }
  
  if ( $this->{PARSING}{p}{'dt:dt'} =~ /binary\.base64/si ) {
    require XML::Smart::Base64 ;
    $content = &XML::Smart::Base64::decode_base64($content) ;
    delete $this->{PARSING}{p}{'dt:dt'} ;
    
    if ( $this->{PARSING}{p}{'/nodes'} ) {
      delete $this->{PARSING}{p}{'/nodes'}{'dt:dt'} ;
      my $nkeys = keys %{$this->{PARSING}{p}{'/nodes'}} ;
      if ($nkeys < 1) { delete $this->{PARSING}{p}{'/nodes'} ;}
    }
    
    if ( $this->{PARSING}{p}{'/order'} ) {
      my @order = @{$this->{PARSING}{p}{'/order'}} ;
      my @order_ok ;
      foreach my $order_i ( @order ) { push(@order_ok , $order_i) if $order_i ne 'dt:dt' ;}
      if (@order_ok) { $this->{PARSING}{p}{'/order'} = \@order_ok ;}
      else { delete $this->{PARSING}{p}{'/order'} ;}
    }
  }
  elsif ($this->{NOENTITY}) { &_parse_basic_entity($content) ;}
  
  ######
  
  if ( !exists $this->{PARSING}{p}{CONTENT} ) {
    $this->{PARSING}{p}{CONTENT} = $content ;
    push(@{$this->{PARSING}{p}{'/order'}} , 'CONTENT') if !$this->{SMART}{no_order} ;
  }
  else {
    if ( !tied $this->{PARSING}{p}{CONTENT} ) {
      my $cont = $this->{PARSING}{p}{CONTENT} ;
      $this->{PARSING}{p}{CONTENT} = '' ;
      my $tied = tie( $this->{PARSING}{p}{CONTENT} => 'XML::Smart::TieScalar' , $this->{PARSING}{p}) ;
      push(@{$this->{TIED_CONTENTS}} , $tied) ;
      
      $this->{PARSING}{p}{'/.CONTENT/x'} = 0 ;
      $this->{PARSING}{p}{"/.CONTENT/0"} = $cont ;
      
      my $cont_pos = 0 ;
      for my $key ( @{$this->{PARSING}{p}{'/order'}} ) {
        last if ($key eq 'CONTENT') ;
        ++$cont_pos ;
      }
      
      splice( @{$this->{PARSING}{p}{'/order'}} , $cont_pos,0, "/.CONTENT/0") if !$this->{SMART}{no_order} ;
    }

    my $x = ++$this->{PARSING}{p}{'/.CONTENT/x'} ;
    $this->{PARSING}{p}{"/.CONTENT/$x"} = $content ;
    push( @{$this->{PARSING}{p}{'/order'}} , "/.CONTENT/$x") if !$this->{SMART}{no_order} ;
  }
  
  if ( $this->{SMART}{on_char} ) {
    my $sub = $this->{SMART}{on_char} ;
    &$sub($this->{PARSING}{p}{'/tag'} , $this->{PARSING}{p} , $this->{PARSING}{p}{'/back'} , \$this->{PARSING}{p}{CONTENT} , $this ) ;
  }
  
  return ;
}

########
# _END #
########

sub _End { ##print "END>> @_[1] >> $_[0]->{PARSING}{p}{'/tag'}\n" ;
  my $this = shift ;
  
  if ( $this->{LAST_CALL} eq 'char' ) { _Char_process( $this , delete $this->{CONTENT_BUFFER} ) ;}
  $this->{LAST_CALL} = 'end' ;
  
  my $tag = shift ;
  
  if    ( $this->{SMART}{tag} == 1 ) { $tag = lc($tag) ;}
  elsif ( $this->{SMART}{tag} == 2 ) { $tag = uc($tag) ;}

  if ( $this->{PARSING}{p}{'/tag'} ne $tag ) { return ;}

  delete $this->{PARSING}{p}{'/tag'} ;
  
  my $back  = delete $this->{PARSING}{p}{'/back'} ;
  my $i = delete $this->{PARSING}{p}{'/i'} || 0 ;
  
  my $nkeys = keys %{$this->{PARSING}{p}} ;
  
  if ( $nkeys == 1 && exists $this->{PARSING}{p}{CONTENT} ) {
    if (ref($back->{$tag}) eq 'ARRAY') { $back->{$tag}[$i] = $this->{PARSING}{p}{CONTENT} ;}
    else { $back->{$tag} = $this->{PARSING}{p}{CONTENT} ;}
  }
  
  if ( $this->{PARSING}{p}{'/nodes'} && !%{$this->{PARSING}{p}{'/nodes'}} ) { delete $this->{PARSING}{p}{'/nodes'} ;}
  if ( $this->{PARSING}{p}{'/order'} && $#{$this->{PARSING}{p}{'/order'}} <= 0 ) { delete $this->{PARSING}{p}{'/order'} ;}
  
  delete $this->{PARSING}{p}{'/.CONTENT/x'} ;
  
  if ( $this->{SMART}{on_end} ) {
    my $sub = $this->{SMART}{on_end} ;
    &$sub($tag , $this->{PARSING}{p} , $back , undef , $this) ;
  }

  $this->{PARSING}{p} = $back ;
    
  return ;
}

##########
# _FINAL #
##########

sub _Final {
  my $this = shift ;
  my $tree = $this->{PARSING}{tree} ;
  
  foreach my $tied_cont ( @{$this->{TIED_CONTENTS}} ) {
    $tied_cont->_cache_keys ;
  }
  
  delete $this->{TIED_CONTENTS} ;
  delete $this->{LAST_CALL} ;
  
  delete($this->{PARSING}) ;
  return($tree) ;
}

#######
# END #
#######

1;


__END__






