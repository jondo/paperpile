#############################################################################
## Name:        DTD.pm
## Purpose:     XML::Smart::DTD - Apply DTD over a XML::Smart object.
## Author:      Graciliano M. P.
## Modified by:
## Created:     25/05/2004
## RCS-ID:      
##
##          The DTD parser was based on XML-DTDParser-1.7
##          by Jenda@Krynicky.cz http://Jenda.Krynicky.cz
##
## Copyright:   (c) 2004 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package XML::Smart::DTD ;

our ($VERSION , @ISA) ;
$VERSION = '0.01' ;

use strict ;
no warnings ;

########
# VARS #
########

my $RE_quoted = qr/(?:"[^"\\]?"|"(?:(?:\\")|[^"])+(?!\\)[^"]?"|'[^'\\]?'|'(?:(?:\\')|[^'])+(?!\\)[^']')/s ;

my $namechar = qr/[#\x41-\x5A\x61-\x7A\xC0-\xD6\xD8-\xF6\xF8-\xFF0-9\xB7._:-]/;
my $name = qr/[\x41-\x5A\x61-\x7A\xC0-\xD6\xD8-\xF6\xF8-\xFF_:]$namechar*/ ;
my $nameX = qr/$name[.?+*]*/ ;

my $nmtoken = qr/$namechar+/ ;

my $AttType = qr/(?:CDATA|ID|IDREF|IDREFS|ENTITY|ENTITIES|NMTOKEN|NMTOKENS|\(.*?\)|NOTATION ?\(.*?\))/ ;
my $DefaultDecl = qr/(?:#REQUIRED|#IMPLIED|#FIXED)/ ;
my $AttDef = qr/($name)[ \t]+($AttType)(?:[ \t]+($DefaultDecl))?(?:[ \t]+($RE_quoted))?/ ;

#{
#  my (@sub) = ( join ("", <DATA>) =~ /\n\s*sub\s+(\w+)/gs );
#  foreach my $sub_i (sort @sub ) { print "=>head2 $sub_i\n" ;}
#}
#__DATA__

###############
# AUTOLOADERS #
###############

sub get_url {
  require XML::Smart::Tree ;
  *get_url = \*XML::Smart::Tree::get_url ;
  &XML::Smart::Tree::get_url(@_) ;
}

#######
# NEW #
#######

sub new {
  my $class = shift ;
  my $dtd = shift ;
  $dtd =~ s/^file:\/\/\/?// ;

  my $this = bless({} , $class) ;

  $this->{tree} = $this->ParseDTD($dtd) ;
  return $this ;
}

################################################################################

###############
# ELEM_EXISTS #
###############

sub elem_exists {
  my $this = shift ;
  my ( $tag ) = @_ ;
  return 1 if $this->{tree}{$tag} ;
  return undef ;
}

################
# CHILD_EXISTS #
################

sub child_exists {
  my $this = shift ;
  my ( $tag , $child ) = @_ ;
  return undef if !$this->{tree}{$tag} || !$this->{tree}{$tag}{children} ;
  return 1 if $this->{tree}{$tag}{children}{$child} ;
  return undef ;
}

################
# IS_ELEM_UNIQ #
################

sub is_elem_uniq {
  my $this = shift ;
  return ( $this->get_elem_opt(@_) =~ /^[\!]?$/ ) ? 1 : undef ;
}

######################
# IS_ELEM_CHILD_UNIQ #
######################

sub is_elem_child_uniq {
  my $this = shift ;
  return ( $this->get_elem_child_opt(@_) =~ /^[\!]?$/ ) ? 1 : undef ;
}

#################
# IS_ELEM_MULTI #
#################

sub is_elem_multi {
  my $this = shift ;
  return ( $this->get_elem_opt(@_) =~ /^[\+\*]$/ ) ? 1 : undef ;
}

#######################
# IS_ELEM_CHILD_MULTI #
#######################

sub is_elem_child_multi {
  my $this = shift ;
  return ( $this->get_elem_child_opt(@_) =~ /^[\+\*]$/ ) ? 1 : undef ;
}

###############
# IS_ELEM_REQ #
###############

sub is_elem_req {
  my $this = shift ;
  return ( $this->get_elem_opt(@_) =~ /^[\!\+]?$/ ) ? 1 : undef ;
}

#####################
# IS_ELEM_CHILD_REQ #
#####################

sub is_elem_child_req {
  my $this = shift ;
  return ( $this->get_elem_child_opt(@_) =~ /^[\!\+]?$/ ) ? 1 : undef ;
}

###############
# IS_ELEM_OPT #
###############

sub is_elem_opt {
  my $this = shift ;
  return ( $this->get_elem_opt(@_) =~ /^[\?\*]$/ ) ? 1 : undef ;
}

#####################
# IS_ELEM_CHILD_OPT #
#####################

sub is_elem_child_opt {
  my $this = shift ;
  return ( $this->get_elem_child_opt(@_) =~ /^[\?\*]$/ ) ? 1 : undef ;
}

################
# GET_ELEM_OPT #
################

sub get_elem_opt {
  my $this = shift ;
  my ( $tag ) = @_ ;
  return undef if !$this->{tree}{$tag} ;
  return $this->{tree}{$tag}{option} ;
}

######################
# GET_ELEM_CHILD_OPT #
######################

sub get_elem_child_opt {
  my $this = shift ;
  my ( $tag , $child ) = @_ ;
  return undef if !$this->{tree}{$tag} || !$this->{tree}{$tag}{children} ;
  return $this->{tree}{$tag}{children}{$child} ;
}

###############
# IS_ELEM_ANY #
###############

sub is_elem_any {
  my $this = shift ;
  my ( $tag ) = @_ ;
  return undef if !$this->{tree}{$tag} ;

  return 1 if $this->{tree}{$tag}{any} ;
  return undef ;
}

##################
# IS_ELEM_PCDATA #
##################

sub is_elem_pcdata {
  my $this = shift ;
  my ( $tag ) = @_ ;
  return undef if !$this->{tree}{$tag} ;
  return 1 if $this->{tree}{$tag}{content} ;
}

#################
# IS_ELEM_EMPTY #
#################

sub is_elem_empty {
  my $this = shift ;
  my ( $tag ) = @_ ;
  return undef if !$this->{tree}{$tag} ;

  return 1 if $this->{tree}{$tag}{empty} ;
  return undef ;
}

##################
# IS_ELEM_PARENT #
##################

sub is_elem_parent {
  my $this = shift ;
  my ( $tag , @chk_parent ) = @_ ;
  return undef if !$this->{tree}{$tag} ;

  my @parents = ref($this->{tree}{$tag}{parent}) eq 'ARRAY' ? @{$this->{tree}{$tag}{parent}} : () ;
  my %parents = map { $_ => 1 } @parents ;

  foreach my $chk_parent_i ( @chk_parent ) {
    next if $chk_parent_i eq '' ;
    return undef if !$parents{$chk_parent_i} ;
  }

  return 1 ;
}

###############
# ATTR_EXISTS #
###############

sub attr_exists {
  my $this = shift ;
  my ( $tag , @attrs ) = @_ ;
  return undef if !$this->{tree}{$tag} ;
  
  foreach my $attrs_i ( @attrs ) {
    return undef if !$this->{tree}{$tag}{attributes}{$attrs_i} ;
  }

  return 1 ;
}

###############
# IS_ATTR_REQ #
###############

sub is_attr_req {
  my $this = shift ;
  my ( $tag , $attr ) = @_ ;
  return undef if !$this->{tree}{$tag} || !$this->{tree}{$tag}{attributes}{$attr} ;
  
  my $opt = @{$this->{tree}{$tag}{attributes}{$attr}}[1] ;
  
  return 1 if $opt =~ /#REQUIRED/i ;
  return undef ;
}

###############
# IS_ATTR_FIX #
###############

sub is_attr_fix {
  my $this = shift ;
  my ( $tag , $attr ) = @_ ;
  return undef if !$this->{tree}{$tag} || !$this->{tree}{$tag}{attributes}{$attr} ;
  
  my $opt = @{$this->{tree}{$tag}{attributes}{$attr}}[1] ;
  
  return 1 if $opt =~ /#FIXED/i ;
  return undef ;
}

#################
# GET_ATTR_TYPE #
#################

sub get_attr_type {
  my $this = shift ;
  my ( $tag , $attr ) = @_ ;
  return undef if !$this->{tree}{$tag} || !$this->{tree}{$tag}{attributes}{$attr} ;
  
  my $type = @{$this->{tree}{$tag}{attributes}{$attr}}[0] ;
  return $type ;
}


################
# GET_ATTR_DEF #
################

sub get_attr_def {
  my $this = shift ;
  my ( $tag , $attr ) = @_ ;
  return () if !$this->{tree}{$tag} || !$this->{tree}{$tag}{attributes}{$attr} ;
  my $def = @{$this->{tree}{$tag}{attributes}{$attr}}[2] ;
  return $def ;
}

###################
# GET_ATTR_VALUES #
###################

sub get_attr_values {
  my $this = shift ;
  my ( $tag , $attr ) = @_ ;
  return () if !$this->{tree}{$tag} || !$this->{tree}{$tag}{attributes}{$attr} ;
  my $vals = @{$this->{tree}{$tag}{attributes}{$attr}}[3] ;
  
  return @$vals if ref $vals eq 'ARRAY' ;
  return () ;
}

##############
# GET_CHILDS #
##############

sub get_childs {
  my $this = shift ;
  my ( $tag ) = @_ ;
  return undef if !$this->{tree}{$tag} ;
  return @{$this->{tree}{$tag}{childrenARR}} if $this->{tree}{$tag}{childrenARR} && @{$this->{tree}{$tag}{childrenARR}} ;
  return () ;
}

##################
# GET_CHILDS_REQ #
##################

sub get_childs_req {
  my $this = shift ;
  my ( $tag ) = @_ ;
  
  my @childs = $this->get_childs($tag) ;
  
  my @childs_req ;
  foreach my $child_i ( @childs ) {
    push(@childs_req , $child_i) if $this->is_elem_child_req($tag , $child_i) ;
  }
  
  return @childs_req ;
}

#############
# GET_ATTRS #
#############

sub get_attrs {
  my $this = shift ;
  my ( $tag ) = @_ ;
  return undef if !$this->{tree}{$tag} || !$this->{tree}{$tag}{attr_order} ;
  
  my @attrs = @{$this->{tree}{$tag}{attr_order}} ;
  return @attrs ;
}

#################
# GET_ATTRS_REQ #
#################

sub get_attrs_req {
  my $this = shift ;
  my ( $tag ) = @_ ;
  
  my @attrs = $this->get_attrs($tag) ;
  
  my @attr_req ;
  foreach my $attrs_i ( @attrs ) {
    push(@attr_req , $attrs_i) if $this->is_attr_req($tag , $attrs_i) ;
  }
  
  return @attr_req ;
}

#########
# ERROR #
#########

sub error {
  my $this = shift ;
  
  if ( @_ ) { push( @{$this->{ERRORS}}  , @_) ;}
  
  return @{ $this->{ERRORS} } if $this->{ERRORS} && @{$this->{ERRORS}} ;
  return () ;
}

########
# TREE #
########

sub tree { return $_[0]->{tree} ; }

########
# ROOT #
########

sub root { return $_[0]->{root} ; }

############
# PARSEDTD #
############

sub ParseDTD {
  my $this = shift ;
  my $xml = read_data( shift(@_) ) ;
  $this->{DATA} = $xml ;
    
  my (%elements, %definitions) ;

  $xml =~ s/\s+/ /gs ;

  while ($xml =~ s{<!ENTITY\s+(?:(%)\s*)?($name)\s+SYSTEM\s*"(.*?)"\s*>}{}io) {
    my ($percent, $entity, $include) = ($1,$2,$3) ;
    $percent = '&' unless $percent;
    my $definition = read_data($include) ;
    $definition =~ s/\s+/ /gs ;
    $xml =~ s{\Q$percent$entity;\E}{$definition}g ;
  }

  $xml =~ s{<!--.*?-->}{}gs ;
  $xml =~ s{<\?.*?\?>}{}gs ;

  while ($xml =~ s{<!ENTITY\s+(?:(%)\s*)?($name)\s*"(.*?)"\s*>}{}io) {
    my ($percent, $entity, $definition) = ($1,$2,$3) ;
    $percent = '&' unless $percent ;
    $definitions{"$percent$entity"} = $definition ;
  }

  {
    my $replacements = 0 ;
    1 while ++$replacements < 1000 and $xml =~ s{([&%]$name);}{(exists $definitions{$1} ? $definitions{$1} : "$1\x01;")}ge;
    $this->error("Recursive <!ENTITY ...> or too many entities!") if $xml =~ m{([&%]$name);} ;
  }
  undef %definitions ;
  
  $xml =~ tr/\x01//d ;

  while ($xml =~ s{<!ELEMENT\s+($name)\s*(\(.*?\))([?*+]?)\s*>}{}io) {
    my ($element, $children, $option) = ($1,$2,$3);

    $elements{$element}->{childrenSTR} = $children . $option ;
    $children =~ s/\s//g ;
    
    if ($children eq '(#PCDATA)') { $children = '#PCDATA' ;}
    elsif ( $children =~ s/^\((#PCDATA(?:\|$name)+)\)$/$1/o && $option eq '*') {
      $children =~ s/\|/*,/g ;
      $children .= '*' ;
    }
    else { $children = simplify_children( $children, $option) ;}

    $this->error("<!ELEMENT $element (...)> is not valid!") unless $children =~ m{^#?$nameX(?:,$nameX)*$} ;

    $elements{$element}->{childrenARR} = [] ;

    foreach my $child (split ',', $children) {
      $child =~ s/([\?\*\+])$//
      and $option = $1
      or $option = '!' ;
      
      $elements{$element}->{children}->{$child} = $option ;
      push @{$elements{$element}->{childrenARR}}, $child unless $child eq '#PCDATA' ;
    }
    
    delete $elements{$element}->{childrenARR} if !@{$elements{$element}->{childrenARR}} ;
  }

  while ($xml =~ s{<!ELEMENT\s+($name)\s*(EMPTY|ANY)\s*>}{}io) {
    my ($element, $param) = ($1,$2) ;
    if ( uc($param) eq 'ANY') { $elements{$element}->{any} = 1 ;}
    elsif ( uc($param) eq 'EMPTY') { $elements{$element}->{empty} = 1 ;}
  }

  while ($xml =~ s{<!ATTLIST\s+($name)\s+(.*?)\s*>}{}io) {
    my ($element, $attributes) = ($1,$2);

    $this->error("<!ELEMENT $element ...> referenced by an <!ATTLIST ...> not found!") unless exists $elements{$element} ;
    
    while ($attributes =~ s/^\s*$AttDef//io) {
      my ($name,$type,$option,$default) = ($1,$2,$3,$4);
      
      if    ( $default =~ /^"(.*?)"$/ ) { $default = $1 ; $default =~ s/\\"/"/gs ;}
      elsif ( $default =~ /^'(.*?)'$/ ) { $default = $1 ; $default =~ s/\\'/'/gs ;}
      
      $elements{$element}->{attributes}->{$name} = [$type,$option,$default,undef];
      
      push(@{$elements{$element}->{attr_order}} , $name) ;
      
      if ($type =~ /^(?:NOTATION\s*)?\(\s*(.*?)\)$/) {
        $elements{$element}->{attributes}->{$name}->[3] = parse_values($1);
      }
    }
  }

  $xml =~ s/\s+/ /gs ;

  if ( $xml =~ /^\s*<\!DOCTYPE\s+($name)\s*\[\s*(.*)$/ ) {
    $this->{root} = $1 ;
    my $data = $2 ;
    $data =~ s/\s*]\s*>\s*$//gi ;
    $xml = $data ;
  }

  $this->error("UNPARSED DATA:\n$xml\n\n") if $xml =~ /\S/ ;

  foreach my $element (keys %elements) {
    foreach my $child (keys %{$elements{$element}->{children}}) {
      if ($child eq '#PCDATA') {
        delete $elements{$element}->{children}->{'#PCDATA'};
        $elements{$element}->{content} = 1;
      }
      else {
        $this->error("Element $child referenced by $element was not found!") unless exists $elements{$child} ;
        
        if (exists $elements{$child}->{parent}) { push @{$elements{$child}->{parent}}, $element ;}
        else { $elements{$child}->{parent} = [$element] ;}
        
        $elements{$child}->{option} = $elements{$element}->{children}->{$child} ;
      }
    }
    
    if ( !%{$elements{$element}->{children}} ) { delete $elements{$element}->{children} ;}
  }

  return \%elements ;
}

##########
# CUTDTD #
##########

sub CutDTD {
  my $this = shift ;
  if ( !@_ ) { push(@_ , $this->{DATA} ) ;}
  
  my $xml = read_data( shift(@_) ) ;
  
  my (%elements, %definitions) ;

  $xml =~ s/\r\n?/\n/gs ;
  
  my $dtd_data ;

  while ($xml =~ s{(<!ENTITY\s+(?:%\s*)?$name\s+SYSTEM\s*".*?"\s*>)}{}io) {
    $dtd_data .= "$1\n" ;
  }

  $xml =~ s{<!--.*?-->}{}gs ;
  $xml =~ s{<\?.*?\?>}{}gs ;

  while ($xml =~ s{(<!ENTITY\s+(?:%\s*)?$name\s*".*?"\s*>)}{}io) {
    $dtd_data .= "$1\n" ;
  }

  {
    my $replacements = 0 ;
    1 while ++$replacements < 1000 and $xml =~ s{([&%]$name);}{(exists $definitions{$1} ? $definitions{$1} : "$1\x01;")}ge;
    $this->error("Recursive <!ENTITY ...> or too many entities!") if $xml =~ m{([&%]$name);} ;
  }
  undef %definitions ;
  
  $xml =~ tr/\x01//d ;

  while ($xml =~ s{(<!ELEMENT\s+$name\s*\(.*?\)[?*+]?\s*>)}{}io) {
    $dtd_data .= "$1\n" ;
  }

  while ($xml =~ s{(<!ELEMENT\s+$name\s*(?:EMPTY|ANY)\s*>)}{}io) {
    $dtd_data .= "$1\n" ;
  }

  while ($xml =~ s{(<!ATTLIST\s+$name\s+.*?\s*>)}{}ios) {
    $dtd_data .= "$1\n" ;
  }

  if ( $xml =~ /^\s*<\!DOCTYPE\s+($name)\s*\[\s*/ ) {
    $dtd_data = "<!DOCTYPE $1 [\n$dtd_data]>\n" ;
  }

  return $dtd_data ;
}

####################
# FLATTEN_CHILDREN #
####################

sub flatten_children {
  my ( $children , $option ) = @_ ;

  if ($children =~ /\|/) {
    $children =~ s/(\|$name)/${1}?/gs ;
    $children =~ s{\|}{?,}g ;
  }

  if ($option) {
    $children =~ s/,/$option,/g ;
    $children .= $option ;
  }

  return $children ;
}

#####################
# SIMPLIFY_CHILDREN #
#####################

sub simplify_children {
  my ( $children, $option ) = @_;

  1 while $children =~ s{\(($nameX(?:[,|]$nameX)*)\)([\?\*\+]*)}{flatten_children($1, $2)}geo ;

  if ($option) {
    $children =~ s/,/$option,/g ;
    $children .= $option ;
  }

  foreach ($children) {
    s{\?\?}{?}g;
    s{\?\+}{*}g;
    s{\?\*}{*}g;
    s{\+\?}{*}g;
    s{\+\+}{+}g;
    s{\+\*}{*}g;
    s{\*\?}{*}g;
    s{\*\+}{*}g;
    s{\*\*}{*}g;
  }

  return $children ;
}

################
# PARSE_VALUES #
################

sub parse_values {
  my $def = shift ;
  
  $def =~ s/^\s*\(\s*// ;
  $def =~ s/\s*\)\s*$// ;
  $def = "|$def" ;
  
  my @def ;
  while( $def =~ /\s*|\s*(?:($RE_quoted)|([^\(\)\|]+))/gs ) {
    if ( defined $1 ) {
      my $q = $1 ;
      if    ( $q =~ /^"(.*?)"$/ ) { $q = $1 ; $q =~ s/\\"/"/gs ;}
      elsif ( $q =~ /^'(.*?)'$/ ) { $q = $1 ; $q =~ s/\\'/'/gs ;}
      push(@def , $q) ;
    }
    elsif ( defined $2 ) {
      my $d = $2 ;
      $d =~ tr/\x20\x09\x0D\x0A//d ; # get rid of whitespace
      push(@def , $d) ;
    }
  }
  
  foreach my $def_i ( @def ) {
    
  }

  return \@def ;
}

#############
# READ_DATA #
#############

sub read_data {
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
  
  return $data ;
}

################################################################################

#############
# APPLY_DTD #
#############

sub apply_dtd {
  my $xml = shift ;
  my $dtd = shift ;
  
  if ( ref($dtd) ne 'XML::Smart::DTD' ) { $dtd = XML::Smart::DTD->new($dtd , @_) ;}
  
  $$xml->{DTD} = $dtd ;

  return if !$dtd || !$dtd->tree || !%{ $dtd->tree } ;
  
  _apply_dtd($dtd , $xml->tree , undef , undef , {} , undef , undef , {} , @_) ;
}

sub _apply_dtd {
  my ($dtd , $tree , $tag , $ar_i , $prev_tree , $prev_tag , $prev_exists , $parsed , %opts) = @_ ;
  
  ##print "$tag>> $tree , $tag , $prev_tree , $prev_tag , $parsed >> $opts{no_delete}\n" ;
  
  if ( ref($tree) ) {
    if ($$parsed{"$tree"}) { return ;}
    ++$$parsed{"$tree"} ;
  }
  
  if (ref($tree) eq 'HASH') {
  
    if ( $tag ne '' && $dtd->elem_exists($tag) ) {
      if ( $dtd->is_elem_empty($tag) ) {
        $prev_tree->{$tag} = {} ;
      }
      elsif ( $dtd->is_elem_pcdata($tag) ) {
        if ( ref $prev_tree->{$tag} eq 'HASH' ) { $prev_tree->{$tag}{CONTENT} = '' if !defined $prev_tree->{$tag}{CONTENT} ;}
        else { $prev_tree->{$tag} = '' if !defined $prev_tree->{$tag} ;}
      }
      else {
        my @childs_req = $dtd->get_childs_req($tag) ;
        foreach my $childs_req_i ( @childs_req ) {
          if ( !exists $tree->{$childs_req_i} ) {
            $tree->{$childs_req_i} = {} ;
          }
        }
      
        my @attrs_req = $dtd->get_attrs_req($tag) ;
        foreach my $attrs_req_i ( @attrs_req ) {
          if ( !exists $tree->{$attrs_req_i} ) {
            $tree->{$attrs_req_i} = $dtd->get_attr_def($tag , $attrs_req_i) ;
          }
        }
        
        {
          my @order = ($dtd->get_attrs($tag) , $dtd->get_childs($tag)) ;
          
          if ( ! $tree->{'/order'} ) { $tree->{'/order'} = \@order ;}
          else {
            my %in_order ;
            {
              my %n ; %in_order = map { $_ => (++$n{$_}) } @{ $tree->{'/order'} } ;
            }
            
            my (@new_order , %order) ;
            foreach my $order_i ( @order ) {
              push(@new_order , (($order_i) x ($in_order{$order_i} || 1))) ;
              $order{$order_i} = 1 ;
            }
            
            foreach my $order_i ( @{ $tree->{'/order'} } ) {
              next if $order{$order_i} ;
              push(@new_order , $order_i) ;
            }
            
            $tree->{'/order'} = \@new_order ;
          }
          
        }
        
        
      }
            
    }
  
    foreach my $Key ( keys %$tree ) {
      if ($Key eq '' || $Key eq '/order' || $Key eq '/nodes' || $Key eq 'CONTENT') { next ;}
      
      if ( ($tag eq '' && $dtd->elem_exists($Key)) || ($tag ne '' && $dtd->child_exists($tag , $Key)) ) {
        if ( $tree->{'/nodes'}{$Key} =~ /^(\w+,\d+),(\d*)/ ) { $tree->{'/nodes'}{$Key} = "$1,1" ;}
        else { $tree->{'/nodes'}{$Key} = 1 ;}
        
        if ( !ref($tree->{$Key}) ) {
          my $content = $tree->{$Key} ;
          $tree->{$Key} = {} if !ref $tree->{$Key} ;
          $tree->{$Key}{CONTENT} = $content if $content ne '' ;
        }
        elsif ( ref($tree->{$Key}) eq 'ARRAY' ) {
          if ( $tag ne '' && !$dtd->is_elem_child_multi($tag , $Key) ) {
            $tree->{$Key} = $tree->{$Key}[0] ;
          }
        }
        
        _apply_dtd($dtd , $tree->{$Key} , $Key , undef , $tree , $tag , 1, $parsed , %opts) ;
      }
      elsif ( $tag ne '' && $dtd->attr_exists($tag , $Key) ) {
        delete $tree->{'/nodes'}{$Key} ;
        if ( ref($tree->{$Key}) eq 'HASH' && exists $tree->{$Key}{CONTENT} && (keys %{$tree->{$Key}}) == 1 ) {
          my $content = $tree->{$Key}{CONTENT} ;
          $tree->{$Key} = $content ;
        }
        
        if ( ref $tree->{$Key} ) {
          if ( ref $tree->{$Key} eq 'ARRAY' ) { $tree->{$Key} = $tree->{$Key}[0] ;}        
          if ( ref $tree->{$Key} eq 'HASH' ) { $tree->{$Key} = $tree->{$Key}{CONTENT} ;}
        }
        
        if ( $tag ne '' && $tree->{$Key} eq '' ) {
          $tree->{$Key} = $dtd->get_attr_def($tag , $Key) ;
        }
      }
      else {
        if ( $prev_exists && !$opts{no_delete} ) { delete $tree->{$Key} ;}
        else {
          _apply_dtd($dtd , $tree->{$Key} , $Key , undef , $tree , $tag , undef , $parsed , %opts) ;
        }

      }
    }
  }
  elsif (ref($tree) eq 'ARRAY') {
    my $i = -1 ;
    foreach my $tree_i ( @$tree ) {
      ++$i ;
      _apply_dtd($dtd , $tree_i , $tag , $i , $prev_tree , $prev_tag , $prev_exists , $parsed , %opts) ;
    }
  }
  else {
    if ( $tag ne '' && $dtd->elem_exists($tag) ) {
      if ( $prev_tree->{'/nodes'}{$tag} =~ /^(\w+,\d+),(\d*)/ ) { $prev_tree->{'/nodes'}{$tag} = "$1,1" ;}
      else { $prev_tree->{'/nodes'}{$tag} = 1 ;}
      
      if ( !ref($prev_tree->{$tag}) || ( ref($prev_tree->{$tag}) eq 'HASH' && !exists $prev_tree->{$tag}{CONTENT}) ) {
        my $content = $prev_tree->{$tag} ;
        $prev_tree->{$tag} = {} if !ref $prev_tree->{$tag} ;
        $prev_tree->{$tag}{CONTENT} = $content if $content ne '' ;
      }
    }
    elsif ( $tag ne '' && $dtd->attr_exists($prev_tag , $tag) ) {
      delete $prev_tree->{'/nodes'}{$tag} ;
      if ( ref($prev_tree->{$tag}) eq 'HASH' && exists $prev_tree->{$tag}{CONTENT} && (keys %{$prev_tree->{$tag}}) == 1 ) {
        my $content = $prev_tree->{$tag}{CONTENT} ;
        $prev_tree->{$tag} = $content ;
      }
    }
  }

  delete $$parsed{"$tree"} if ref($tree) ;
  
  return 1 ;
}

#######
# END #
#######

1;

__END__

=head1 NAME

XML::Smart::DTD - DTD parser for XML::Smart.

=head1 DESCRIPTION

This will parse DTD and provides methods to access the information stored in the DTD.

=head1 USAGE

  use XML::Smart::DTD ;

  my $dtd = XML::Smart::DTD->new('some.dtd') ;
  
  if ( $dtd->child_exists('tag1','subtag1') ) {
  ...
  }

  use Data::Dumper ;
  print Dumper( $dtd->tree ) ;

=head1 new

=head1 METHODS

=head2 attr_exists ( TAG , ATTR )

Return I<TRUE> if the attribute exists in the element TAG.

=head2 child_exists ( TAG , CHILD )

Return I<TRUE> if the child exists in the element TAG.

=head2 elem_exists ( TAG )

Return I<TRUE> if the element TAG exists.

=head2 error

Return the error list.

=head2 get_attr_def ( TAG , ATTR )

Return the default value of an attribute

=head2 get_attr_type ( TAG , ATTR )

Return the attribute type.

=head2 get_attr_values ( TAG , ATTR )

Return the defined values of an attribute.

=head2 get_attrs ( TAG )

Return the attribute list of a element.

=head2 get_attrs_req ( TAG )

Return the required attribute list of a element.

=head2 get_childs ( TAG )

Return the child list of an element.

=head2 get_childs_req ( TAG )

Return the required child list of an element.

=head2 get_elem_opt ( TAG )

Return the occurrence option of an element:

  !  REQUIRED AND ONLY ONE MATCH
  +  1 or more
  *  0 or more
  ?  0 or 1

=head2 get_elem_child_opt ( TAG , CHILD )

Same of I<get_elem_opt()> but this element as a child of an element.

=head2 is_attr_fix ( TAG , ATTR )

Return I<TRUE> if an attribute is I<FIXED>.

=head2 is_attr_req ( TAG , ATTR )

Return I<TRUE> if an attribute is I<REQUIRED>.

=head2 is_elem_any ( TAG )

Return I<TRUE> if an element is I<ANY>.

=head2 is_elem_child_multi ( TAG , CHILD )

Return I<TRUE> if an element can have multiple occurrences as a child of TAG.

=head2 is_elem_child_opt ( TAG , CHILD )

Return I<TRUE> if an element is optional as a child of TAG.

=head2 is_elem_child_req ( TAG , CHILD )

Return I<TRUE> if an element is optional as a child of TAG.

=head2 is_elem_child_uniq ( TAG , CHILD )

Return I<TRUE> if an element is required and unique as a child of TAG.

=head2 is_elem_pcdata ( TAG )

Return I<TRUE> if an element is I<PCDATA> (have content).

=head2 is_elem_empty ( TAG )

Return I<TRUE> if an element is I<EMPTY> (doesn't have attributes, content or children).

=head2 is_elem_multi ( TAG )

Return I<TRUE> if an element can have multiple occurrences globally.

=head2 is_elem_opt ( TAG )

Return I<TRUE> if an element is optional globally.

=head2 is_elem_parent ( TAG , @PARENTS )

Return I<TRUE> if the list of @PARENTS can be parent of element TAG.

=head2 is_elem_req

Return I<TRUE> if an element is required globally.

=head2 is_elem_uniq

Return I<TRUE> if an element is unique and required globally.

=head2 root

Return the root name of the DTD.

=head2 tree

Return the HASH tree of the DTD.

=head1 SEE ALSO

L<XML::Smart>, L<XML::DTDParser>.

=head1 AUTHOR

Graciliano M. P. <gm@virtuasites.com.br>

I will appreciate any type of feedback (include your opinions and/or suggestions). ;-P

=head1 THANKS

Thanks to Jenda@Krynicky.cz http://Jenda.Krynicky.cz that is the author of L<XML::DTDParser>.

=head1 COPYRIGHT

The DTD parser was based on XML-DTDParser-1.7 by Jenda@Krynicky.cz http://Jenda.Krynicky.cz

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

