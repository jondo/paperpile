#############################################################################
## Name:        MultiType.pm
## Purpose:     Object::MultiType
## Author:      Graciliano M. P.
## Modified by:
## Created:     10/05/2003
## RCS-ID:      
## Copyright:   (c) 2003 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Object::MultiType;
use 5.006 ;
use strict qw(vars) ;
our $VERSION = '0.05';

no warnings ;

 use overload (
 'bool' => '_OVER_bool' ,
 '""' => '_OVER_string' ,
 '='  => '_OVER_copy' ,
 '+'  => '_OVER_inc' ,
 '-'  => '_OVER_deinc' ,
 '0+'  => '_OVER_copy' ,
 '@{}'  => '_OVER_get_array' ,
 '%{}'  => '_OVER_get_hash' ,
 '&{}'  => '_OVER_get_code' ,
 '*{}'  => '_OVER_get_glob' , 
 'fallback' => 1 ,
 ) ;

sub is_saver { 0 ;}

#######
# NEW #
#######

sub new {
  my $class = shift ;
  my (%args) = @_ ;

  my $saver = Object::MultiType::Saver->new( $args{nodefault} ) ;
  my $this = \$saver ;
  bless($this,$class) ;
  
  if (!defined $args{boolsub} && defined $args{boolcode} ) { $args{boolsub} = $args{boolcode} ;}

  if ( exists $args{bool} ) { $saver->set_bool($args{bool}) ;}
  elsif ( $args{boolsub} ) {
    my $sub = $args{boolsub} ;
    $saver->set_bool(\$sub) ;
  }
  
  if (!defined $args{scalarsub} && defined $args{scalarcode} ) { $args{scalarsub} = $args{scalarcode} ;}

  if ( defined $args{scalar} ) { $saver->set_scalar($args{scalar}) ;}
  elsif ( $args{scalarsub} ) {
    my $sub = $args{scalarsub} ;
    $saver->set_scalar(\$sub) ;
  }
  
  if ( ref $args{array} eq 'ARRAY' ) { $saver->set_array($args{array}) ;}
  elsif ( $args{tiearray} ) {
    if ( $args{tieonuse} ) { $saver->{TIEONUSE}{a} = $args{tiearray} ;}
    else {
      my @array ; tie(@array,$args{tiearray},$$this) ;
      $saver->set_array(\@array) ;
    }
  }

  if    ( ref $args{hash} eq 'HASH' ) { $saver->set_hash($args{hash}) ;}
  elsif ( $args{tiehash} ) {
    if ( $args{tieonuse} ) { $saver->{TIEONUSE}{h} = $args{tiehash} ;}
    else {
      my %hash = 1 ; tie(%hash,$args{tiehash},$$this) ;
      $saver->set_hash(\%hash) ;    
    }
  }

  if ( ref $args{code} eq 'CODE' ) { $saver->set_code( $args{code} ) ;}
  
  if ( $args{tiehandle} ) {
    if (!$args{glob}) { local(*NULL) ; $args{glob} = \*NULL ;}

    if ( $args{tieonuse} ) { $saver->{TIEONUSE}{g} = $args{tiehandle} ;}
    else { tie($args{glob} , $args{tiehandle} , $$this) ;}
  }
  
  if ( ref $args{glob} eq 'GLOB' ) { $saver->set_glob( $args{glob} ) ;}
  
  return( $this ) ;
}

##############
# _OVER_BOOL #
##############

sub _OVER_bool {
  my $this = shift ;

  if ( !exists $$this->{b} ) {
    return $this->_OVER_string ;
  }
  
  my $bool = $$this->bool ;
  
  if (ref($bool) && ref($$bool) eq 'CODE') {
    my $sub = $$bool ;
    return &$sub($this) ;
  }
  
  if (ref($bool) eq 'SCALAR') { return( $$bool ) ;}
  
  return( $bool ) ;
}

##########
# STRING #
##########

sub _OVER_string {
  my $this = shift ;
  my $scalar = $$this->scalar ;
  
  if (ref($$scalar) eq 'CODE') {
    my $sub = $$scalar ;
    return &$sub($this) ;
  }
  else { return( $$scalar ) ;}
}

#############
# _OVER_INC #
#############

sub _OVER_inc {
  my $this = shift ;
  my $scalar = $$this->scalar ;
  
  my $n ;
  if (ref($$scalar) eq 'CODE') {
    my $sub = $$scalar ;
    $n = &$sub($this) ;
  }
  else { $n = substr($$scalar , 0 ) ;}
  
  $n += $_[0] ;
  return $n ;
}

###############
# _OVER_DEINC #
###############

sub _OVER_deinc {
  my $this = shift ;
  my $scalar = $$this->scalar ;
  
  my $n ;
  if (ref($$scalar) eq 'CODE') {
    my $sub = $$scalar ;
    $n = &$sub($this) ;
  }
  else { $n = substr($$scalar , 0 ) ;}
  
  $n -= $_[0] ;
  return $n ;
}

##############
# _OVER_COPY #
##############

sub _OVER_copy {
  my $this = shift ;
  my $scalar = $$this->scalar ;
  
  if (ref($$scalar) eq 'CODE') {
    my $sub = $$scalar ;
    return &$sub($this) ;
  }
  else { return( substr($$scalar , 0 ) ) ;}
}

#############
# GET_ARRAY #
#############

sub _OVER_get_array {
  my $this = shift ;
  
  if ( $$this->{TIEONUSE}{a} ) {
    my @array ; tie(@array, $$this->{TIEONUSE}{a} , $$this) ;
    $$this->set_array(\@array) ;
    $$this->{TIEONUSE}{a} = undef ;
  }
  
  return( $$this->array ) ;
}

############
# GET_HASH #
############

sub _OVER_get_hash {
  my $this = shift ;
  
  if ( $$this->{TIEONUSE}{h} ) {
    my %hash = 1 ; tie(%hash, $$this->{TIEONUSE}{h} ,$$this) ;
    $$this->set_hash(\%hash) ;
    $$this->{TIEONUSE}{h} = undef ;
  }
  
  return( $$this->hash ) ;
}

##################
# _OVER_GET_CODE #
##################

sub _OVER_get_code {
  my $this = shift ;

  if ( !$$this->{SUBCODE} ) {
    $$this->{SUBCODE}{self} = undef ;
    
    my $sub = $$this->code ;
    my $ref = $$this->{SUBCODE} ;
    
    $$this->{SUBCODE}{sub} = sub {
      if (wantarray) {
        my @ret = &$sub( $$ref{self} , @_) ;
        $$ref{self} = undef ;
        return( @ret ) ;
      }
      else {
        my $ret = &$sub( $$ref{self} , @_) ;
        $$ref{self} = undef ;
        return( $ret ) ;    
      }
    };

  }
  
  $$this->{SUBCODE}{self} = $this ;
  return( $$this->{SUBCODE}{sub} ) ;
}

##################
# _OVER_GET_GLOB #
##################

sub _OVER_get_glob {
  my $this = shift ;
  
  if ( $$this->{TIEONUSE}{g} ) {
    tie($$this->glob , $$this->{TIEONUSE}{g} , $$this) ;    
    $$this->{TIEONUSE}{g} = undef ;
  }
  
  return( $$this->glob ) ;
}

###########
# DESTROY #
###########

sub DESTROY {
  my $this = shift ;
  $$this->clean ;
}

############################
# OBJECT::MULTITYPE::SAVER #
############################

package Object::MultiType::Saver ;

use strict qw(vars) ;

sub is_saver { 1 ;}

sub new {
  my $class = shift ;
  my ( $nodefault ) = @_ ;
  
  my $this ;
  
  if ($nodefault) { $this = {} ;}
  else {
    local(*NULL);
    $this = {
    s => \'' ,
    a => [] ,
    h => {} ,
    c => sub{} ,  
    g => \*NULL ,
    } ;
  }  
  
  bless($this,$class);
  return( $this ) ;
}

sub bool   { return( $_[0]->{b} ) ;} 
sub scalar { return( $_[0]->{s} ) ;} 
sub array  { return( $_[0]->{a} ) ;}
sub hash   { return( $_[0]->{h} ) ;}
sub code   { return( $_[0]->{c} ) ;}
sub glob   { return( $_[0]->{g} ) ;}

sub set_bool  { $_[0]->{b} = $_[1] ;}

sub set_scalar {
  if ($#_ == 0) { $_[0]->{s} = undef ;}
  elsif (ref($_[1]) ne 'SCALAR' && ref($_[1]) ne 'REF') { $_[0]->{s} = \$_[1] ;}
  else { $_[0]->{s} = $_[1] ;}
}

sub set_array  { $_[0]->{a} = $_[1] ;}
sub set_hash   { $_[0]->{h} = $_[1] ;}
sub set_code   { $_[0]->{c} = $_[1] ;}
sub set_glob   { $_[0]->{g} = $_[1] ;}

sub clean {
  my $this = shift ;
  $this->set_bool() ;
  $this->set_scalar() ;
  $this->set_array() ;
  $this->set_hash() ;
  $this->set_code() ;
  $this->set_glob() ;
}

sub DESTROY { &clean ;}

#######
# END #
#######

1;
__END__

=head1 NAME

Object::MultiType - Perl Objects as Hash, Array, Scalar, Code and Glob at the same time.

=head1 SYNOPSIS

  use Object::MultiType ;

  my $scalar = 'abc' ;
  my @array  = qw(x y z);
  my %hash   = (A => 1 , B => 2) ;

  my $obj = Object::MultiType->new(
  scalar => \$scalar ,
  array  => \@array ,
  hash   => \%hash ,
  code   => sub{ return("I'm a sub ref!") ; }
  glob   => \*STDOUT ,
  ) ;
  
  print "Me as scalar: $obj\n" ;
  
  my $array_1 = $obj->[1] ;
  print "$array_1\n" ;
  
  my $hash_B = $obj->{B} ;
  print "$hash_B\n" ;
  
  my $hash = $$obj->hash ;
  foreach my $Key (sort keys %$hash ) {
    print "$Key = $$hash{$Key}\n" ;
  }
  
  &$obj(args) ;

=head1 DESCRIPTION

This module return an object that works like a Hash, Array, Scalar, Code and Glob object at the same time.

The usual way is to call it from your module at new():

  package FOO ;
  
  use Object::MultiType ;
  use vars qw(@ISA) ;
  @ISA = qw(Object::MultiType) ; ## Is good to 'Object::MultiType' be the last in @ISA!
  
  sub new {
    my $class = shift ;
    my $this = Object::MultiType->new() ;
    bless($this,$class) ;
  }

=head1 METHODS

** See the methods of the L<Saver|/SAVER> too.

=head2 new

B<Arguments>:

=over 10

=item bool

The I<boolean> reference. Default: undef

=item boolcode|boolsub

Set the sub/function (CODE reference) that will return/generate the I<boolean> value.

=item scalar

The SCALAR reference. If not sent a null SCALAR will be created.

=item scalarcode|scalarsub

Set the sub/function (CODE reference) that will return/generate the scalar data of the object.

=item array

The ARRAY reference. If not sent a null ARRAY will be created.

=item hash

The HASH reference. If not sent a null HASH will be created.

=item code

The CODE reference. If not sent a null sub{} will be created.

With this your object can be used as a sub reference:

  my $multi = Object::MultiType->new( code => sub { print "Args: @_\n" ;} ) ;
  &$multi();

Note that the first argument sent to the SUB is the object ($multi).

=item glob

The GLOB (HANDLE) reference. If not sent a null GLOB will be created.

** Note that you can't use the default (null) GLOB created when you don't paste this argument!
Since all the objects will share it, and was there just to avoid erros!

=item tiearray

Package name to create a TIEARRAY. The argument $$this is sent to tie().

tie() is called as:

  tie(@array,$args{tiearray},$$this) ;

Note that is hard to implement the tie methods for PUSH, POP, SHIFT, UNSHIFT, SPLICE...
Unless you make just an alias to another array through the tie methods.

** See B<tiehash> too.

=item tiehash

Package name to create a TIEHASH. The argument $$this is sent to tie().

tie() is called as:

  tie(%hash,$args{tiehash},$$this) ;

** $$this (the Saver) is sent, and not $this, to avoid the break of DESTROY (auto reference).

** $$this is a reference to the Saver object that save the SCALAR, ARRAY, HASH, CODE and GLOB.

  sub TIEHASH {
    my $class = shift ;
    my $multi = shift ; ## $$this

    my $scalarref = $multi->scalar ; ## \${*$multi}
    my $arrayref  = $multi->array  ; ## \@{*$multi}
    my $hashref   = $multi->hash   ; ## \%{*$multi}
    
    my $this = { s => $scalarref , a => $arrayref , h => $hashref } ;
    bless($this,$class) ;
  }

=item tiehandle

Make the object works like a tied glob (TIEHANDLE).

If used with I<glob> will tie() it. If I<glob> is not sent a NULL GLOB is used:

  my $multi = Object::MultiType->new(
  glob      => \*MYOUT ,               ## 'glob' is Optional.
  tiehandle => 'TieHandlePack' ,
  ) ;

=item tieonuse

The reference is only tied when it's used! So, the HASH, ARRAY or GLOB (handle)
are only tied if/when they are accessed.

=item nodefault

If set to true tell to not create the default references inside the Saver, and it
will have only the references paste (scalar, array, hash, code, glob).

** This is good to save memory.

=back

=head2 is_saver

Return 0. Good to see if what you have is the Saver or the MultiType object.

=head1 SAVER

The MultiType object has a Saver object (L<Object::MultiType::Saver|/Object::MultiType::Saver>),
that save all the different data type (references). This saver can be accessed from the main object:

  my $multi = Object::MultiType->new() ;
  
  my $saver = $$multi ;
  print $saver->scalar ;

B<If you want to save attributes in your Object and you use I<tiehash>, you can't set attributes directly in the MultiType object>!:

  sub new {
    my $class = shift ;
    my $this = Object::MultiType->new(tiehash => 'TieHashPack') ;

    ## Dont do that! This will call the STORE() at TIEHASH, and not save it in the object:
    $this->{flagx} = 1 ;
    
    bless($this,$class) ;
  }

So, if you use tiehash and want to save attributes (outside tie) use that:

    ## This save the attribute inside the Saver:
    $$this->{flagx} = 1 ;

Note that this set an attribute in the saver, and it has their own attributes!

  ## $saver = $$this ;

  $saver->{s} ## the sacalar ref.
  $saver->{a} ## the array ref.
  $saver->{h} ## the hash ref.
  $saver->{c} ## the code ref.  
  $saver->{g} ## the glob ref.  

** See I<"Direct access to the data types">.

=head1 DESTROY

When the object is DESTROIED, the Saver inside it is cleanned, so the tied objects can be DESTROIED automatically too.

=head1 Direct access to the data types

To access directly the reference of the different data types (SCALAR, ARRAY, HASH, CODE & GLOB) use:

  my $multi = Object::MultiType->new() ;

  my $saver = $$multi ;

  my $scalarref = $saver->scalar ; ## $saver->{s}
  my $arrayref  = $saver->array  ; ## $saver->{a}
  my $hashref   = $saver->hash   ; ## $saver->{h}
  my $coderef   = $saver->code   ; ## $saver->{c}
  my $globeref  = $saver->glob   ; ## $saver->{g}
  
  ## You can access the Saver directly from the main object:
  $$multi->hash  ;

Setting the data:

  $saver->set_bool( 1 ) ;
  $saver->set_scalar( 'xyz' ) ;
  $saver->set_array( [qw(x y z)] ) ;
  $saver->set_hash( {X => 1} ) ;
  $saver->set_code( sub{ print "XYZ\n" ; } ) ;
  $saver->set_glob( \*STDOUT ) ;  

=head1 As SCALAR

You can use it as SCALAR when you put it inside quotes or make a copy of it:

  my $multi = Object::MultiType->new( scalar => 'Foo' ) ;

  ## Quote:
  print "Me as scalar: $multi\n" ;
  
  ## Copy:
  my $str = $multi ;
  $str .= '_x' ; ## Copy made when you change it! Until that $str works like $multi.
  print "$str\n" ;

using the argument B<scalarsub> you can use a function that will generate the scalar data,
in the place of a reference to a SCALAR:

  my $multi = Object::MultiType->new(scalarsub => sub{ return 'generated data' ;} ) ;
  
  print "My scalar have $multi!\n" ;

=head1 As ARRAY

You can use it as ARRAY directly from the object:

  my $multi = Object::MultiType->new( array => [qw(FOO BAR)] ) ;
  my $array_0 = $multi->[0] ;
  $multi->[1] = 'foo' ;

=head1 As HASH

You can use it as HASH directly from the object:

  my $multi = Object::MultiType->new( hash => {key => 'foo'} ) ;
  my $k = $multi->{key} ;
  $multi->{foo} = 'bar' ;

=head1 With TIE

To use your ARRAY and HASH part tied, you can paste the reference already tied of the HASH or ARRAY,
or use the arguments tiehash and tiearray at L<new()|/new>:

  ## Using the reference:
  my %hash ;
  tie(%hash,'TieHash') ;
  my $multi = Object::MultiType->new(hash => \%hash) ;
  
  ## Or using directly the argument:
  my $multi = Object::MultiType->new(tiehash => 'TieHashPack') ;

Note that using tiehash or tiearray is better, since your tied HASH or ARRAY can see the object Saver and
the other data type of it. B<See the method L<new()|/new> and their arguments>.

Here's an example of a TieHash package that is called from Object::MultiType->new():

  ## The call inside Object::MultiType->new():
  tie(%hash,$args{tiehash},$$this) ;
  
  ## The package:
  package TieHash ;
  
  sub TIEHASH {
      my $class = shift ;
      my $Saver = shift ; ## Object::MultiType paste as $$this (only the Saver) to avoid break of DESTROY!
                          ## $this = Object::MultiType >> $$this = Object::MultiType::Saver
  
      my $scalarref = $Saver->scalar ;
      my $arrayref  = $Saver->array  ;

      ## Note that $Saver->hash will return the tied hash, and is not needed here!
      ## my $hashref   = $Saver->hash ;
      
      ## Saving the references inside the TIE object:
      my $this = { scalar => $scalarref , array => $arrayref , hash => {} } ;
            
      bless($this,$class) ;
  }
  
  sub FETCH    { my $this = shift ; return( 'key' ) ;}
  
  sub NEXTKEY  { my $this = shift ; return( 'key' ) ;}
  
  sub STORE    { my $this = shift ; $this->{hash}{$_[0]} = $_[1] }
  
  sub DELETE   { my $this = shift ; delete $this->{hash}{$_[0]} }
  
  sub CLEAR    { my $this = shift ; $this->{hash} = {} ;}
  
  sub EXISTS   { my $this = shift ; defined $this->{hash}{$_[0]} ;}
  
  sub FIRSTKEY { my $this = shift ; (sort keys %{$this->{hash}} )[0] }
  
  sub DESTROY  {}

B<Using tiehash, you need to save the attributes in the Saver, or you call the tie()>.

    $$this->{flagx} = 1 ;

=head1 Object::MultiType::Saver

This is a litte package where the Saver objects are created.
It will save the data types (SCALAR, ARRAY, HASH, CODE & GLOB) of the main objects (Object::MultiType).

B<METHODS:>

=head2 is_saver

Return 1. Good to see if what you have is the Saver or the MultiType object.

=head2 bool

Return the BOOL reference inside the Saver.

=head2 scalar

Return the SCALAR reference inside the Saver.

=head2 array

Return the ARRAY reference inside the Saver.

=head2 hash

Return the HASH reference inside the Saver.

=head2 code

Return the CODE/sub reference inside the Saver.

=head2 glob

Return the GLOB/HANDLE reference inside the Saver.

=head2 set_bool

Set the boolean reference inside the Saver.

=head2 set_scalar

Set the SCALAR reference inside the Saver.

=head2 set_array

Set the ARRAY reference inside the Saver.

=head2 set_hash

Set the HASH reference inside the Saver.

=head2 set_code

Set the CODE/sub reference inside the Saver.

=head2 set_glob

Set the GLOB/HANDLE reference inside the Saver.

=head2 clean

Clean all the references saved in the Saver.

=head1 SEE ALSO

L<overload>, L<perltie>, L<Scalar::Util>.

This module/class was created for L<XML::Smart>.

=head1 AUTHOR

Graciliano M. P. <gm@virtuasites.com.br>

I will appreciate any type of feedback (include your opinions and/or suggestions). ;-P

=head1 COPYRIGHT 

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut


