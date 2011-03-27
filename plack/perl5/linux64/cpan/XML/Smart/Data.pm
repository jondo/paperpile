#############################################################################
## Name:        Data.pm
## Purpose:     XML::Smart::Data - Generate XML data.
## Author:      Graciliano M. P.
## Modified by:
## Created:     28/09/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package XML::Smart::Data ;

our ($VERSION , @ISA) ;
$VERSION = '0.01' ;

require Exporter ;
@ISA = qw(Exporter) ;

our @EXPORT = qw(data) ;
our @EXPORT_OK = @EXPORT ;

use strict ;
no warnings ;

use XML::Smart::Entity qw(_add_basic_entity) ;

########
# DATA #
########

sub data {
  my $this = shift ;
  my ( %args ) = @_ ;
  
  my $tree ;
  
  if ( $args{tree} ) { $tree = $args{tree} ;}
  else { $tree = $this->tree ;}
  
  {
    my $addroot ;

    if ( $args{root} || ref $tree ne 'HASH' ) { $addroot = 1 ;}
    else {
      my $ks = keys %$tree ;
      my $n = 1 ;
      if (ref $$tree{'/nodes'} eq 'HASH')  { ++$n ;}
      if (ref $$tree{'/order'} eq 'ARRAY') { ++$n ;}
      #if (ref $$tree{'/nodes'} eq 'HASH')  { ++$n if (keys %{$$tree{'/nodes'}}) ;}
      #if (ref $$tree{'/order'} eq 'ARRAY') { ++$n if @{$$tree{'/order'}} ;}

      if ($ks > $n) { $addroot = 1 ;}
      else {
        my $k = (keys %$tree)[0] ;
        if (ref $$tree{$k} eq 'ARRAY' && $#{$$tree{$k}} > 0) {
          my ($c,$ok) ;
          foreach my $i ( @{$$tree{$k}} ) {
            if ( $i && &is_valid_tree($i) ) { $c++ ; $ok = $i ;}
            if ($c > 1) { $addroot = 1 ; last ;}
          }
          if (!$addroot && $ok) { $$tree{$k} = $ok ;}
        }
        elsif (ref $$tree{$k} =~ /^(?:HASH|)$/) {$addroot = 1 ;}
      }
    }
    
    if ($addroot) {
      my $root = $args{root} || 'root' ;
      $tree = {$root => $tree} ;
    }
  }
  
  if ( $args{lowtag} ) { $args{lowtag} = 1 ;}
  if ( $args{upertag} ) { $args{lowtag} = 2 ;}
  
  if ( $args{lowarg} ) { $args{lowarg} = 1 ;}
  if ( $args{uperarg} ) { $args{lowarg} = 2 ;}

  my ($data,$unicode) ;
  {
    my $parsed = {} ;
    &_data(\$data , $tree , '' , -1 , {} , $parsed , undef , undef , $args{noident} , $args{nospace} , $args{lowtag} , $args{lowarg} , $args{wild} , $args{sortall} ) ;
    $data .= "\n" if !$args{nospace} ;
    if ( &_is_unicode($data) ) { $unicode = 1 ;}
  }

  my $enc = 'iso-8859-1' ;
  if ($unicode) { $enc = 'utf-8' ;}
    
  my $meta ;
  if ( $args{meta} ) {
    my @metas ;
    if (ref($args{meta}) eq 'ARRAY') { @metas = @{$args{meta}} ;}
    elsif (ref($args{meta}) eq 'HASH') { @metas = $args{meta} ;}
    else { @metas = $args{meta} ;}
    
    foreach my $metas_i ( @metas ) {
      if (ref($metas_i) eq 'HASH') {
        my $meta ;
        foreach my $Key (sort keys %$metas_i ) {
          $meta .= " $Key=" . &_add_quote($$metas_i{$Key}) ;
        }
        $metas_i = $meta ;
      }
    }
    
    foreach my $meta ( @metas ) {
      $meta =~ s/^[<\?\s*]//s ;
      $meta =~ s/[\s\?>]*$//s ;
      $meta =~ s/^meta\s+//s ;
      $meta = "<?meta $meta ?>" ;
    }
    
    $meta = "\n" . join ("\n", @metas) ;
  }
  
  my $wild = $args{wild} ? ' [format: wild]' : '' ;
  
  my $metagen = qq`\n<?meta name="GENERATOR" content="XML::Smart/$XML::Smart::VERSION$wild Perl/$] [$^O]" ?>` ;
  if ( $args{nometagen} ) { $metagen = '' ;}
  
  my $length ;
  if ( $args{length} ) {
    $length = ' length="' . (length($metagen) + length($meta) + length($data)) . '"' ;
  }
  
  my $xml = qq`<?xml version="1.0" encoding="$enc"$length ?>` ;
  
  if ( $args{noheader} ) { $xml = '' ; $metagen = '' if $args{nometagen} eq '' ;}
  
  my $dtd ;
  
  if ( !$args{nodtd} && $$this->{DTD} ) {
    $dtd = ref $$this->{DTD} ? $$this->{DTD}->CutDTD : $$this->{DTD} ;
    $dtd =~ s/\s*$// ;
    $dtd = "\n$dtd" if $dtd ne '' && !$args{nospace} ;
  }
  
  $data = $xml . $metagen . $meta . $dtd . $data ;
  
  if ($xml eq '') { $data =~ s/^\s+//gs ;}
  
  if (wantarray) { return($data , $unicode) ;}
  return($data) ;
}

#################
# IS_VALID_TREE #
#################

sub is_valid_tree {
  my ( $tree ) = @_ ;
  my $found ;
  if (ref($tree) eq 'HASH') {
    foreach my $Key (sort keys %$tree ) {
      if ($Key eq '' || $Key eq '/order' || $Key eq '/nodes') { next ;}
      if (ref($$tree{$Key})) { $found = &is_valid_tree($$tree{$Key}) ;}
      elsif ($$tree{$Key} ne '') { $found = 1 ;}
      if ($found) { last ;}
    }
  }
  elsif (ref($tree) eq 'ARRAY') {
    foreach my $value (@$tree) {
      if (ref($value)) { $found = &is_valid_tree($value) ;}
      elsif ($value ne '') { $found = 1 ;}
      if ($found) { last ;}      
    }
  }
  elsif (ref($tree) eq 'SCALAR' && $$tree ne '') { $found = 1 ;}
  
  return $found ;
}

###############
# _IS_UNICODE #
###############

sub _is_unicode {
  if ($] >= 5.008001) {
    if ( utf8::is_utf8($_[0])) { return 1 ;}
  }
  elsif ($] >= 5.008) {
    require Encode ;
    if ( Encode::is_utf8($_[0])) { return 1 ;}
  }
  elsif ( $] >= 5.007 ) {
    my $is = eval(q`
      if ( $_[0] =~ /[\x{100}-\x{10FFFF}]/s) { return 1 ;}
      return undef ;
    `);
    $@ = undef ;
    return 1 if $is ;
  }
  else {
    ## No Perl internal support for UTF-8! ;-/
    ## Is better to handle as Latin1.
    return undef ;
  }

  return undef ;
}

#########
# _DATA #
#########

sub _data {
  my ( $data , $tree , $tag , $level , $prev_tree , $parsed , $ar_i , $node_type , @stat ) = @_ ;

  if (ref($tree) eq 'XML::Smart') { $tree = defined $$tree->{content} ? $$tree->{content} : $$tree->{point} ;}
  
  if ( ref($tree) ) {
    if ($$parsed{"$tree"}) { return ;}
    ++$$parsed{"$tree"} ;
  }
  
  my $ident = "\n" ;
  $ident .= '  ' x $level if !$stat[0] ;

  if ($stat[1]) { $ident = '' ;}
  $stat[1] -= 2 if $stat[1] > 1 ;
  
  my $tag_org = $tag ;
  $tag = $stat[4] ? $tag : &_check_tag($tag) ;
  if    ($stat[2] == 1) { $tag = "\L$tag\E" ;}
  elsif ($stat[2] == 2) { $tag = "\U$tag\E" ;}

  if (ref($tree) eq 'HASH') {
    my ($args,$args_end,$tags,$cont,$stat_1) ;
    
    my (@all_keys , %multi_keys) ;
    
    if ( !$stat[5] && $tree->{'/order'} ) {
      my %keys ;
      foreach my $keys_i ( @{$tree->{'/order'}} ) {
        if ( exists $$tree{$keys_i} && (!ref($$tree{$keys_i}) || ref($$tree{$keys_i}) eq 'HASH' || ref($$tree{$keys_i}) eq 'XML::Smart' || (ref($$tree{$keys_i}) eq 'ARRAY' && exists $$tree{$keys_i}[ $keys{$keys_i} ] ) ) ) {
          push(@all_keys , $keys_i) ;
          
          if ( ++$keys{$keys_i} == 2 && ref $$tree{$keys_i} eq 'ARRAY' ) {
            my @val = map { ( $_ ne '' ? 1 : () ) } @{ $$tree{$keys_i} } ;
            $multi_keys{$keys_i} = 1 if $#val > 0 ;
          }
        }
      }
      foreach my $keys_i ( sort keys %$tree ) {
        if ( !$keys{$keys_i} && exists $$tree{$keys_i} ) { push(@all_keys , $keys_i) ;}
      }
    }
    else { @all_keys = sort keys %$tree ;}
    
    my %array_i ;

    foreach my $Key ( @all_keys ) {
      if ($Key eq '' || $Key eq '/order' || $Key eq '/nodes') { next ;}

      if ( $Key eq '!--' && (!ref($$tree{$Key}) || ( ref($$tree{$Key}) eq 'HASH' && (keys %{$$tree{$Key}}) == 1 && (defined $$tree{$Key}{CONTENT} || defined $$tree{$Key}{content}) ) ) ) {
        my $ct = $$tree{$Key} ;
        if (ref $$tree{$Key}) { $ct = defined $$tree{$Key}{CONTENT} ? $$tree{$Key}{CONTENT} : $$tree{$Key}{content} ;} ;
        if ( $ct ne '' ) { $tags .= "$ident<!-- $ct -->" ;}
      }
      elsif (ref($$tree{$Key})) {
        my $k = $$tree{$Key} ;
        my $i ;
        if (ref $k eq 'XML::Smart') {
          $k = defined ${$$tree{$Key}}->{content} ? ${$$tree{$Key}}->{content} : ${$$tree{$Key}}->{point} ;
        }
        elsif ( ref $k eq 'ARRAY' && $multi_keys{$Key} ) {
          $i = $array_i{$Key}++ if $#{$k} > 0 ;
        }
        $args .= &_data(\$tags,$k,$Key, $level+1 , $tree , $parsed , $i , $$tree{'/nodes'}{$Key} , @stat) if $array_i{$Key} ne 'ok' ;
        $array_i{$Key} = 'ok' if $i eq '' && ref $k eq 'ARRAY' ;
      }
      elsif ( $$tree{'/nodes'}{$Key} ) {
        my $k = [$$tree{$Key}] ;
        $args .= &_data(\$tags,$k,$Key, $level+1 , $tree , $parsed , undef , $$tree{'/nodes'}{$Key} , @stat) ;
      }
      elsif (lc($Key) eq 'content') {
        if ( tied($$tree{$Key}) && $$tree{$Key} =~ /\S/s ) {
          $ident = '' ; $stat[1] += 2 ;
        }
        next if tied($$tree{$Key}) ;
        
        if ( $$tree{$Key} ne '' ) {
          my $p0 = length($tags) ;
          $tags .= $$tree{$Key} ;        
          $cont = [$p0, length($tags) - $p0] ;
        }
      }
      elsif ($Key =~ /^\/\.CONTENT\/\d+$/) { $tags .= $$tree{$Key} ;}
      elsif ( $stat[4] && $$tree{$Key} eq '') { $args_end .= " $Key" ;}
      else {
        my $tp = _data_type($$tree{$Key}) ;
        if    ($tp == 1) {
          my $k = $stat[4] ? $Key : &_check_key($Key) ;
          if    ($stat[3] == 1) { $k = "\L$Key\E" ;}
          elsif ($stat[3] == 2) { $k = "\U$Key\E" ;}
          $args .= " $k=" . &_add_quote($$tree{$Key}) ;
        }
        else {
          my $k = $stat[4] ? $Key : &_check_key($Key) ;
          if    ($stat[2] == 1) { $k = "\L$Key\E" ;}
          elsif ($stat[2] == 2) { $k = "\U$Key\E" ;}

          if ($tp == 2) {
            my $cont = $$tree{$Key} ; &_add_basic_entity($cont) ;
            $tags .= qq`$ident<$k>$cont</$k>` ;
          }
          elsif ($tp == 3) { $tags .= qq`$ident<$k><![CDATA[$$tree{$Key}]]></$k>`;}
          elsif ($tp == 4) {
            require XML::Smart::Base64 ;
            my $base64 = &XML::Smart::Base64::encode_base64($$tree{$Key}) ;
            $base64 =~ s/\s$//s ;
            $tags .= qq`$ident<$k dt:dt="binary.base64">$base64</$k>`;
          }
        }
      }
    }
    
    foreach my $Key ( keys %array_i ) {
      if ( $array_i{$Key} ne 'ok' && $#{ $$tree{$Key} } >= $array_i{$Key} ) {
        for my $i ( $array_i{$Key} .. $#{ $$tree{$Key} } ) {
          $args .= &_data(\$tags, $$tree{$Key} ,$Key, $level+1 , $tree , $parsed , $i , $$tree{'/nodes'}{$Key} , @stat) ;
        }
      }
    }
    
    if ( $cont ne '' ) {
      my ( $po , $p1 ) = @$cont ;
      my $cont = substr($tags , $po , $p1) ;
        
      my $tp = _data_type($cont) ;
      
      if ( $node_type =~ /^(\w+),(\d+),(\d*)$/ ) {
        my ( $node_tp , $node_set ) = ($1,$2) ;

        if ( !$node_set ) {
          if    ( $tp == 3 && $node_tp eq 'cdata'  ) { $tp = 0 ;}
          elsif ( $tp == 4 && $node_tp eq 'binary' ) { $tp = 0 ;}
        }
        else {
          if    ( $node_tp eq 'cdata'  ) { $tp = 3 ;}
          elsif ( $node_tp eq 'binary' ) { $tp = 4 ;}
        }
      }
      
      if ( $tp == 3 ) { $cont = "<![CDATA[$cont]]>" ;}
      elsif ( $tp == 4 ) {
        require XML::Smart::Base64 ;
        $cont = &XML::Smart::Base64::encode_base64($cont) ;
        $cont =~ s/\s$//s ;
        $args .= ' dt:dt="binary.base64"' ;
      }
      else { &_add_basic_entity($cont) ;}
      
      my $pe = $po + $p1 ;
      my $px = $pe ;
      while( substr($tags , $px , 1) =~ /\s/ ) { ++$px ;}

      if ( $px > $pe ) { substr($tags , $pe , $px-$pe) = '' ;}
      
      substr($tags , $po , $p1) = $cont ;
    }
    
    ##print "***$tag>> $args,$args_end,$tags,$cont,$stat_1 [@all_keys]\n" ;
    
    if ($args_end ne '') {
      $args .= $args_end ;
      $args_end = undef ;
    }

    if (!@all_keys) {
      $$data .= qq`$ident<$tag/>` if $tag ne '' ;
    }
    elsif ($args ne '' && $tags ne '') {
      $$data .= qq`$ident<$tag$args>` if $tag ne '' ;
      $$data .= $tags ;
      $$data .= $ident if !$cont ;
      $$data .= qq`</$tag>` if $tag ne '' ;
    }
    elsif ($args ne '') {
      $$data .= qq`$ident<$tag$args/>`;
    }
    elsif ($tags ne '') {
      $$data .= qq`$ident<$tag>` if $tag ne '' ;
      $$data .= $tags ;
      $$data .= $ident if !$cont ;
      $$data .= qq`</$tag>` if $tag ne '' ;
    }
    else {
      $$data .= qq`$ident<$tag></$tag>` if $tag ne '' ;
    }
  }
  elsif (ref($tree) eq 'ARRAY') {
    my ($c,$v,$tags) ;

    foreach my $value_i ( ($ar_i ne '' ? $$tree[$ar_i] : @$tree) ) {
      
      my $value = $value_i ;
      if (ref $value_i eq 'XML::Smart') { $value = $$value_i->{point} ;}
      
      my $do_val = 1 ;
      if ( $tag_org eq '!--' && ( !ref($value) || ( ref($value) eq 'HASH' && keys %{$value} == 1 && (defined $$value{CONTENT} || defined $$value{content}) ) ) ) {
        $c++ ;
        my $ct = $value ;
        if (ref $value) { $ct = defined $$value{CONTENT} ? $$value{CONTENT} : $$value{content} ;} ;
        $tags .= $ident . '<!--' . $ct . '-->' ;
        $v = $ct if $c == 1 ;
        $do_val = 0 ;
      }
      elsif (ref($value)) {
        if (ref($value) eq 'HASH') {
          $c = 2 ;
          &_data(\$tags,$value,$tag,$level, $tree , $parsed , undef , undef , @stat) ;
          $do_val = 0 ;
        }
        elsif (ref($value) eq 'SCALAR') { $value = $$value ;}
        elsif (ref($value) ne 'ARRAY') { $value = "$value" ;}
      }
      if ( $do_val && $value ne '') {
        my $tp = _data_type($value) ;
        
        if ( $node_type =~ /^(\w+),(\d+),(\d*)$/ ) {
          my ( $node_tp , $node_set ) = ($1,$2) ;
          if ( !$node_set ) {
            if    ( $tp == 3 && $node_tp eq 'cdata'  ) { $tp = 0 ;}
            elsif ( $tp == 4 && $node_tp eq 'binary' ) { $tp = 0 ;}
          }
          else {
            if    ( $node_tp eq 'cdata'  ) { $tp = 3 ;}
            elsif ( $node_tp eq 'binary' ) { $tp = 4 ;}
          }
        }
        
        if ($tp <= 2) {
          $c++ ;
          my $cont = $value ; &_add_basic_entity($value) ;
          &_add_basic_entity($cont) ;
          $tags .= qq`$ident<$tag>$cont</$tag>`;
          $v = $cont if $c == 1 ;
        }
        elsif ($tp == 3) {
          $c++ ;
          $tags .= qq`$ident<$tag><![CDATA[$value]]></$tag>`;
          $v = $value if $c == 1 ;
        }
        elsif ($tp == 4) {
          $c++ ;
          require XML::Smart::Base64 ;
          my $base64 = &XML::Smart::Base64::encode_base64($value) ;
          $base64 =~ s/\s$//s ;
          $tags .= qq`$ident<$tag dt:dt="binary.base64">$base64</$tag>`;
          $v = $value if $c == 1 ;
        }
      }
    }

    if ( $ar_i eq '' && $c <= 1 && ! $$prev_tree{'/nodes'}{$tag}) {
      my $k = $stat[4] ? $tag : &_check_key($tag) ;
      if    ($stat[3] == 1) { $k = "\L$k\E" ;}
      elsif ($stat[3] == 2) { $k = "\U$k\E" ;}
      delete $$parsed{"$tree"} if ref($tree) ;
      return " $k=" . &_add_quote($v) ;
    }
    else { $$data .= $tags ;}
  }
  elsif (ref($tree) eq 'SCALAR') {
    my $k = $stat[4] ? $tag : &_check_key($tag) ;
    if    ($stat[3] == 1) { $k = "\L$k\E" ;}
    elsif ($stat[3] == 2) { $k = "\U$k\E" ;}
    delete $$parsed{"$tree"} if ref($tree) ;
    return " $k=" . &_add_quote($$tree) ;
  }
  elsif (ref($tree)) {
    my $k = $stat[4] ? $tag : &_check_key($tag) ;
    if    ($stat[3] == 1) { $k = "\L$k\E" ;}
    elsif ($stat[3] == 2) { $k = "\U$k\E" ;}
    delete $$parsed{"$tree"} if ref($tree) ;
    return " $k=" . &_add_quote("$tree") ;
  }
  else {
    my $k = $stat[4] ? $tag : &_check_key($tag) ;
    if    ($stat[3] == 1) { $k = "\L$k\E" ;}
    elsif ($stat[3] == 2) { $k = "\U$k\E" ;}
    delete $$parsed{"$tree"} if ref($tree) ;
    return " $k=" . &_add_quote($tree) ;
  }

  delete $$parsed{"$tree"} if ref($tree) ;
  return ;
}

##############
# _DATA_TYPE #
##############

## 4 binary
## 3 CDATA
## 2 content
## 1 value

sub _data_type { &XML::Smart::_data_type ;}

##############
# _CHECK_TAG #
##############

sub _check_tag { &_check_key ;}

##############
# _CHECK_KEY #
##############

sub _check_key {
  if ($_[0] =~ /(?:^[.:-]|[^\w\:\.\-])/s) {
    my $k = $_[0] ;
    $k =~ s/^[.:-]+//s ;
    $k =~ s/[^\w\:\.\-]+/_/gs ;
    return( $k ) ;
  }
  return( $_[0] ) ;
}

##############
# _ADD_QUOTE #
##############

sub _add_quote {
  my ($data) = @_ ;
  $data =~ s/\\$/\\\\/s ;
  
  &_add_basic_entity($data) ;
  
  my $q1 = ($data =~ /"/s) ? 1 : undef ;
  my $q2 = ($data =~ /'/s) ? 1 : undef ;
  
  if (!$q1 && !$q2) { return( qq`"$data"` ) ;}
  
  if ($q1 && $q2) {
    $data =~ s/"/&quot;/gs ;
    return( qq`"$data"` ) ;
  }
  
  if ($q1) { return( qq`'$data'` ) ;}
  if ($q2) { return( qq`"$data"` ) ;}

  return( qq`"$data"` ) ;
}

#######
# END #
#######

1;


