#############################################################################
## Name:        HTMLParser.pm
## Purpose:     XML::Smart::HTMLParser
## Author:      Graciliano M. P.
## Modified by:
## Created:     29/05/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package XML::Smart::HTMLParser ;
use 5.006 ;

use strict qw(vars) ;
no warnings ;

our ($VERSION , @ISA) ;
$VERSION = '1.0' ;

#######
# NEW #
#######

sub new { 
  my $this = shift ;
  my $class = ref($this) || $this ;
  return $this if ref $this ;

  $this = bless {} => $class ;
  
  my %args = @_ ;
  $this->setHandlers(%args) ;
  
  $this->{NOENTITY} = 1 ;
  
  return $this ;
}

###############
# SETHANDLERS #
###############

sub setHandlers {
  my $this = shift ;
  my %args = @_;
    
  $this->{Init}  = $args{Init} || sub{} ;
  $this->{Start} = $args{Start} || sub{} ;
  $this->{Char}  = $args{Char} || sub{} ;
  $this->{End}   = $args{End} || sub{} ;
  $this->{Final} = $args{Final} || sub{} ;
  
  return( 1 ) ;
}

#########
# PARSE #
#########

sub parse {
  my $this = shift ;
  my $data = shift ;
  
  $data =~ s/\r\n?/\n/gs ;
  
  $data =~ s/^\s*<\?xml.*?>//gsi ;
  
  my @parsed ;
  
  while( $data =~ /(.*?)<(.*?)>/gsi ) {
    my $cont = $1 ;
    my $markup = $2 ;
    
    my ($more_q , @args) = &parse_tag($markup) ;
    
    while ($more_q) {
      my $more ;
      ($more) = ( $data =~ /\G(.*?)>/s ) ;
      pos($data) += length($more) + 1 ;
      $markup = $markup.'>'.$more ;
      ($more_q , @args) = &parse_tag($markup) ;
    }
    
    if ($cont =~ /\S/s) { push(@parsed , 'Char' , $cont) ;}
    
    if ($args[0] =~ /^\/(.*)/) { push(@parsed , 'End' , $1) ;}
    elsif (@args[-1] =~ /^\/$/) {
      pop @args ;
      push(@parsed , 'StartEnd' , [@args]) ;
    }
    else { push(@parsed , 'Start' , [@args]) ;}
  }
  
  {
  
    my (%close,@close,%open) ;
    for(my $i=$#parsed-1 ; $i >= 0 ; $i-=2) {
      my $type = $parsed[$i] ;
      
      if ($type eq 'End') {
        my $tag = $parsed[$i+1] ;
        $close{lc($tag)}++ ;
        push(@close , $i) ;
      }
      elsif ($type eq 'Start') {
        my $tag = @{$parsed[$i+1]}[0] ;
        
        if (!$close{lc($tag)}) {
          if (@{$parsed[$i+1]}[-1] eq '/' && $#{$parsed[$i+1]} % 2 ) {
            pop @{$parsed[$i+1]} ;
            $parsed[$i] = 'StartEnd' ;
          }
          elsif ($parsed[$i+2] ne 'Char') { $parsed[$i] = 'StartEnd' ;}
          else {
            push( @{ $open{@close[-1]} }  , 'End' , $tag) ;
          }
        }
        else {
          $close{lc($tag)}-- ;
          pop(@close) ;
        }
      }
    }
    
    if ( %open ) {
      my @parsed2 ;
      for(my $i=0 ; $i <= $#parsed ; ++$i) {
        push(@parsed2 , @{$open{$i}}) if $open{$i} ;
        push(@parsed2 , $parsed[$i]) ;
      }
      @parsed = @parsed2 ;
    }

  }

  &{$this->{Init}}($this) ;
  
  for (my $i = 0 ; $i <= $#parsed ; $i+=2) {
    my $type = $parsed[$i] ;
    my $args = $parsed[$i+1] ;
    
    if    ($type eq 'Start') { &{$this->{Start}}( $this , ref($args) ? @{$args} : $args )  ;}
    elsif ($type eq 'Char') { &{$this->{Char}}( $this , ref($args) ? @{$args} : $args )  ;}
    elsif ($type eq 'End') { &{$this->{End}}( $this , ref($args) ? @{$args} : $args )  ;}
    elsif ($type eq 'StartEnd') {
      &{$this->{Start}}( $this , ref($args) ? @{$args} : $args ) ;
      &{$this->{End}}( $this , ref($args) ? @{$args}[0] : $args ) ;
    }
  }
  
  return &{$this->{Final}}($this) ;
}

#############
# PARSE_TAG #
#############

sub parse_tag {
  my $args = shift ;
  
  #print "[$args]\n" ;
  
  if ($args =~ /^!--/s) {
    if ($args !~ /--$/s) { return('--') ;}
    
    $args =~ s/^!--//s ;
    $args =~ s/--$//s ;
    
    return('' , '!--' , 'CONTENT' , $args ) ;
  }
  
  
  my @args ;
  my ($type , $type_last) = (-1,-1) ;
  
  while($args =~ /(?:^\s*)?(?:
    (
     \w+:\/\/[^'"\s]+  ## URI without quotes
     |
     [\w:\.-]+    ## words
    )

  |
  ([^'"=\s]+)    ## unquoted values
  |
  (=) ## equal between name and value
  |
    ## Quote: '...'
    ('
      (?:
        '
        |
        (?:(?:\\')?[^'])+(?:'{1,2}|.*)
      )
    )
  
  |
    ## Quote: "..."
    ("
      (?:
        "
        |
        (?:(?:\\")?[^"])+(?:"{1,2}|.*)
      )
    )

  )/gsx) {
    my $got ;
    if    ($1 ne '') { $got = $1 ;}
    elsif ($2 ne '') { $got = $2 ;}
    elsif ($3 ne '') { $got = $3 ;}
    elsif ($4 ne '') { $got = $4 ;}
    elsif ($5 ne '') { $got = $5 ;}
    else { next ;}
    
    if ($got =~ /^(['"])/s) {
      my $q = $1 ;
      if ($got !~ /$q$/s || $got =~ /\\$q$/s) { return($q) ;}
      else { $got =~ s/^$q//s ; $got =~ s/$q$//s ;}
    }
    if ($got eq '=') { $type = 1 ;}
    else {
      if ($type_last == 0 && $type == 0) { push(@args , '') ;}
      push(@args , $got) ;
      $type_last = $type ;
      $type = 0 ;
    }
  }
  
  #print "@args\n" ;
  
  return( '' , @args ) ;
}

#######
# END #
#######

1;


