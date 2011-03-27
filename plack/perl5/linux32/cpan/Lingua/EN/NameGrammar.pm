=head1 NAME

Lingua::EN::NameGrammar - grammar tree for Lingua::EN::NameParse

=head1 SYNOPSIS

Internal functions called from NameParse.pm module

=head1 DESCRIPTION

Grammar tree of personal name syntax for Lingua::EN::NameParse module.

The grammar defined here is for use with the Parse::RecDescent module.
Note that parsing is done depth first, meaning match the shortest string first.
To avoid premature matches, when one rule is a sub set of another longer rule,
it must appear after the longer rule. See the Parse::RecDescent documentation
for more details.


=head1 AUTHOR

NameGrammar was written by Kim Ryan <kimryan at cpan dot org>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005 Kim Ryan. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.




=cut
#------------------------------------------------------------------------------

package Lingua::EN::NameGrammar;
use strict;


# Rules that define valid orderings of a names components

my $rules_start = q{ full_name : };

my $rules_joint_names =
q{

   # A (?) refers to an optional component, occurring 0 or more times.
   # Optional items are returned as an array, which for our case will
   # always consist of one element, when they exist.

   title given_name surname conjunction title given_name surname non_matching(?)
   {
      # block of code to define actions upon successful completion of a
      # 'production' or rule

      # Two separate people
      $return =
      {
         # Parse::RecDescent lets you return a single scalar, which we use as
         # an anonymous hash reference
         title_1       => $item[1],
         given_name_1  => $item[2],
         surname_1     => $item[3],
         conjunction_1 => $item[4],
         title_2       => $item[5],
         given_name_2  => $item[6],
         surname_2     => $item[7],
         non_matching  => $item[8][0],
         number        => 2,
         type          => 'Mr_John_Smith_&_Ms_Mary_Jones'
      }
   }
   |


   title initials surname conjunction title initials surname non_matching(?)
   {
      $return =
      {
         title_1       => $item[1],
         initials_1    => $item[2],
         surname_1     => $item[3],
         conjunction_1 => $item[4],
         title_2       => $item[5],
         initials_2    => $item[6],
         surname_2     => $item[7],
         non_matching  => $item[8][0],
         number        => 2,
         type          => 'Mr_A_Smith_&_Ms_B_Jones'
      }
   }
   |

   title initials conjunction initials surname non_matching(?)
   {
      # Two related people, shared title, separate initials,
      # shared surname. Example, father and son, sisters
      $return =
      {
         title_1       => $item[1],
         initials_1    => $item[2],
         conjunction_1 => $item[3],
         initials_2    => $item[4],
         surname_1     => $item[5],
         non_matching  => $item[6][0],
         number        => 2,
         type          => 'Mr_A_&_B_Smith'
      }
   }
   |

   title conjunction title initials conjunction initials surname non_matching(?)
   {
      # Two related people, own initials, shared surname

      $return =
      {
         title_1       => $item[1],
         conjunction_1 => $item[2],
         title_2       => $item[3],
         initials_1    => $item[4],
         conjunction_2 => $item[5],
         initials_2    => $item[6],
         surname_1     => $item[7],
         non_matching  => $item[8][0],
         number        => 2,
         type          => 'Mr_&_Ms_A_&_B_Smith'
      }
   }
   |

   title initials conjunction title initials surname non_matching(?)
   {
      # Two related people, own initials, shared surname
      $return =
      {
         title_1       => $item[1],
         initials_1    => $item[2],
         conjunction_1 => $item[3],
         title_2       => $item[4],
         initials_2    => $item[5],
         surname_1     => $item[6],
         non_matching  => $item[7][0],
         number        => 2,
         type          => 'Mr_A_&_Ms_B_Smith'
      }
   }
   |

   title conjunction title initials surname non_matching(?)
   {
      # Two related people, shared initials, shared surname
      $return =
      {
         title_1       => $item[1],
         conjunction_1 => $item[2],
         title_2       => $item[3],
         initials_1    => $item[4],
         surname_1     => $item[5],
         non_matching  => $item[6][0],
         number        => 2,
         type          => 'Mr_&_Ms_A_Smith'
      }
   }
   |

   given_name surname conjunction  given_name surname non_matching(?)
   {
      $return =
      {
         given_name_1  => $item[1],
         surname_1     => $item[2],
         conjunction_1 => $item[3],
         given_name_2  => $item[4],
         surname_2     => $item[5],
         non_matching  => $item[6][0],
         number        => 2,
         type          => 'John_Smith_&_Mary_Jones'
      }
   }
   |

   initials surname conjunction  initials surname non_matching(?)
   {
      $return =
      {
         initials_1    => $item[1],
         surname_1     => $item[2],
         conjunction_1 => $item[3],
         initials_2    => $item[4],
         surname_2     => $item[5],
         non_matching  => $item[6][0],
         number        => 2,
         type          => 'A_Smith_&_B_Jones'
      }
   }
   |

   given_name conjunction given_name surname non_matching(?)
   {
      $return =
      {
         given_name_1  => $item[1],
         conjunction_1 => $item[2],
         given_name_2  => $item[3],
         surname_2     => $item[4],
         non_matching  => $item[5][0],
         number        => 2,
         type          => 'John_&_Mary_Smith'
      }
   }
   |

};

my $rules_single_names =
q{


   precursor(?) title given_name single_initial surname suffix(?) non_matching(?)
   {
      $return =
      {
         precursor     => $item[1][0],
         title_1       => $item[2],
         given_name_1  => $item[3],
         initials_1    => $item[4],
         surname_1     => $item[5],
         suffix        => $item[6][0],
         non_matching  => $item[7][0],
         number        => 1,
         type          => 'Mr_John_A_Smith'
      }
   }
   |


   precursor(?) title given_name surname suffix(?) non_matching(?)
   {
      $return =
      {
         precursor     => $item[1][0],
         title_1       => $item[2],
         given_name_1  => $item[3],
         surname_1     => $item[4],
         suffix        => $item[5][0],
         non_matching  => $item[6][0],
         number        => 1,
         type          => 'Mr_John_Smith'
      }
   }
   |

   precursor(?) title initials surname suffix(?) non_matching(?)
   {
      $return =
      {
         precursor     => $item[1][0],
         title_1       => $item[2],
         initials_1    => $item[3],
         surname_1     => $item[4],
         suffix        => $item[5][0],
         non_matching  => $item[6][0],
         number        => 1,
         type          => 'Mr_A_Smith'
      }
   }
   |

   precursor(?)  given_name_min_2 middle_name surname suffix(?) non_matching(?)
   {
      $return =
      {
         precursor     => $item[1][0],
         given_name_1  => $item[2],
         middle_name   => $item[3],
         surname_1     => $item[4],
         suffix        => $item[5][0],
         non_matching  => $item[6][0],
         number        => 1,
         type          => 'John_Adam_Smith'
      }
   }
   |

   precursor(?) given_name_min_2 single_initial surname suffix(?) non_matching(?)
   {
      $return =
      {
         precursor     => $item[1][0],
         given_name_1  => $item[2],
         initials_1    => $item[3],
         surname_1     => $item[4],
         suffix        => $item[5][0],
         non_matching  => $item[6][0],
         number        => 1,
         type          => 'John_A_Smith'
      }
   }
   |
   
   precursor(?) single_initial middle_name surname suffix(?) non_matching(?)
   {
      $return =
      {
         precursor     => $item[1][0],
         initials_1    => $item[2],
         middle_name   => $item[3],
         surname_1     => $item[4],
         suffix        => $item[5][0],
         non_matching  => $item[6][0],
         number        => 1,
         type          => 'J_Adam_Smith'
      }
   }
   |   

   precursor(?) given_name surname suffix(?) non_matching(?)
   {
      $return =
      {
         precursor     => $item[1][0],
         given_name_1  => $item[2],
         surname_1     => $item[3],
         suffix        => $item[4][0],
         non_matching  => $item[5][0],
         number        => 1,
         type          => 'John_Smith'
      }
   }
   |

   precursor(?) initials surname suffix(?) non_matching(?)
   {
      $return =
      {
         precursor     => $item[1][0],
         initials_1    => $item[2],
         surname_1     => $item[3],
         suffix        => $item[4][0],
         non_matching  => $item[5][0],
         number        => 1,
         type          => 'A_Smith',
      }
   }
   |

   non_matching(?)
   {
      $return =
      {
         non_matching  => $item[1][0],
         number        => 0,
         type          => 'unknown'
      }
   }
};

#------------------------------------------------------------------------------
# Individual components that a name can be composed from. Components are
# expressed as literals or Perl regular expressions.

my $precursors =
q
{
    precursor : 

    /Estate Of (The Late )?/i |
    /His (Excellency|Honou?r) /i |
    /Her (Excellency|Honou?r) /i |
    /The Right Honou?rable /i |
    /The Honou?rable /i |
    /Right Honou?rable /i |
    /The Rt\.? Hon\.? /i |
    /The Hon\.? /i |
    /Rt\.? Hon\.? /i

};

my $titles =
q{

   title :

   /Mr\.? /i           |
   /Ms\.? /i           |
   /M\/s\.? /i         |
   /Mrs\.? /i          |
   /Miss\.? /i         |

   /Dr\.? /i           |
   /Sir /i             |
   /Dame /i            

};
   
my $extended_titles =
q{
                       |
   /Messrs /i          |   # plural or Mr
   /Mme\.? /i          |   # Madame
   /Mister /i          |
   /Mast(\.|er)? /i    |
   /Ms?gr\.? /i        |   # Monsignor
   /Lord /i            |
   /Lady /i            |

   /Madam(e)? /i       |

   # Medical
   /Doctor /i          |
   /Sister /i          |
   /Matron /i          |

   # Legal
   /Judge /i           |
   /Justice /i         |

   # Police
   /Det\.? /i          |
   /Insp\.? /i         |

   # Military
   /Brig(adier)? /i       |
   /Captain /i            |
   /Capt\.? /i            |
   /Colonel /i            |
   /Col\.? /i             |
   /Commander /i          |
   /Commodore /i          |
   /Cdr\.? /i             |   # Commander, Commodore
   /Field Marshall /i     |
   /Fl\.? Off\.? /i       |
   /Flight Officer /i     |
   /Flt Lt /i             |
   /Flight Lieutenant /i  |
   /Gen(\.|eral)? /i      |
   /Gen\. /i              |
   /Pte\. /i              |
   /Private /i            |
   /Sgt\.? /i             |
   /Sargent /i            |
   /Air Commander /i      |
   /Air Commodore /i      |
   /Air Marshall /i       |
   /Lieutenant Colonel /i |
   /Lt\.? Col\.? /i       |
   /Lt\.? Gen\.? /i       |
   /Lt\.? Cdr\.? /i       |
   /Lieutenant /i         |
   /(Lt|Leut|Lieut)\.? /i |
   /Major General /i      |
   /Maj\.? Gen\.?/i       |
   /Major /i              |
   /Maj\.? /i


   # Religious
   /Rabbi /i              |
   /Bishop /i             |
   /Brother /i            |
   /Chaplain /i           |
   /Father /i             |
   /Pastor /i             |
   /Mother Superior /i    |
   /Mother /i             |
   /Most Rever[e|a]nd /i  |
   /Very Rever[e|a]nd /i  |
   /Rever[e|a]nd /i       |
   /Mt\.? Revd\.? /i      |
   /V\.? Revd?\.? /i      |
   /Revd?\.? /i           |


   # Other
   /Prof(\.|essor)? /i    |
   /Ald(\.|erman)? /i
};

my $conjunction = q{ conjunction : /And |& /i };

# Used in the John_A_Smith and J_Adam_Smith name types. Although this 
# duplicates $initials_1, it is needed because this type of initial must 
# always be one character long, regardless of the length of initials set 
# by the user in the 'new' method.
my $single_initial = q{ single_initial: /[A-Z]\.? /i };

# Define given name combinations, specifying the minimum number of letters.
# The correct pair of rules is determined by the 'initials' key in the hash
# passed to the 'new' method.

# Jo, Jo-Anne, D'Artagnan, O'Shaugnessy La'Keishia
my $given_name_min_2 =
q{
    given_name: /[A-Z]{2,} /i | /[A-Z]{2,}\-[A-Z]{2,} /i | /[A-Z]{1,}\'[A-Z]{2,} /i
};

# Joe ...
my $given_name_min_3 =
q{
    given_name: /[A-Z]{3,} /i | /[A-Z]{2,}\-[A-Z]{2,} /i | /[A-Z]{1,}\'[A-Z]{2,} /i
};

my $given_name_min_4 =
q{
    given_name: /[A-Z]{4,} /i | /[A-Z]{2,}\-[A-Z]{2,} /i | /[A-Z]{1,}\'[A-Z]{3,} /i
};

# For use with John_Adam_Smith and John_A_Smith name types
my $fixed_length_given_name =
q{
    given_name_min_2 : /[A-Z]{2,} /i | /[A-Z]{2,}\-[A-Z]{2,} /i | /[A-Z]{1,}\'[A-Z]{2,} /i
};


# Define initials combinations specifying the minimum and maximum letters.
# Order from most complex to simplest,  to avoid premature matching.

# 'A' 'A.'
my $initials_1 = q{ initials: /[A-Z]\.? /i };

# 'A. B.' 'A.B.' 'AB' 'A B'

my $initials_2 =
q{
   initials:  /([A-Z]\. ){1,2}/i | /([A-Z]\.){1,2} /i | /([A-Z] ){1,2}/i | /([A-Z]){1,2} /i
};

# 'A. B. C. '  'A.B.C' 'ABC' 'A B C'
my $initials_3 =
q{
   initials: /([A-Z]\. ){1,3}/i |  /([A-Z]\.){1,3} /i | /([A-Z] ){1,3}/i | /([A-Z]){1,3} /i
};


# Jo, Jo-Anne, La'Keishia, D'Artagnan, O'Shaugnessy 
my $middle_name =
q{
   middle_name: 
   
   # Dont grab surname prefix too early. For example, John Van Dam could be
   # interpreted as middle name of Van and Surname of Dam. So exclude prefixs
   # from middle names
   ...!prefix /[A-Z]{2,} /i | /[A-Z]{2,}\-[A-Z]{2,} /i | /[A-Z]{1,}\'[A-Z]{2,} /i
   {
      $return = $item[2];
   }
};


my $full_surname =
q{
   # Use look-ahead to avoid ambiguity between surname and suffix. For example,
   # John Smith Snr, would detect Snr as the surname and Smith as the middle name
   surname : ...!suffix sub_surname second_name(?)
   {
      if ( $item[2] and $item[3][0] )
      {
         $return = "$item[2]$item[3][0]";
      }
      else
      {
         $return = $item[2];
      }
   }

   sub_surname : prefix(?) name
   {
      # To prevent warnings when compiling with the -w switch,
      # do not return uninitialized variables.
      if ( $item[1][0] )
      {
         $return = "$item[1][0]$item[2]";
      }
      else
      {
         $return = $item[2];
      }
   }

   second_name : '-' sub_surname
   {
      if ( $item[1] and $item[2] )
      {
         $return = "$item[1]$item[2]";
      }
   }

   # Patronymic, place name and other surname prefixes
   prefix:

      /[A|E]l /i         |   # Arabic, Greek,
      /Ap /i             |   # Welsh
      /Ben /i            |   # Hebrew

      /Dell([a|e])? /i   |   # ITALIAN
      /Dalle /i          |
      /D[a|e]ll'/i       |
      /Dela /i           |
      /Del /i            |
      /De (La |Los )?/i  |
      /D[a|i|u] /i       |
      /L[a|e|o] /i       |

      /[D|L|O]'/i        |   # Italian, Irish or French
      /St\.? /i          |   # abbreviation for Saint
      /San /i            |   # Spanish

      /Den /i            |   # DUTCH
      /Von (Der )?/i     |
      /Van (De(n|r)? )?/i

   # space needed for any following text
   name: /[A-Z]{2,} ?/i

};

my $suffix =
q{
   suffix:

      # word boundaries are used to stop partial matches from surnames such as 
      # the "VI" in "VINCE"

      /Esq(\.|uire)?\b ?/i |
      /Sn?r\.?\b ?/i | # Senior
      /Jn?r\.?\b ?/i | # Junior
      /PhD\.?\b ?/i  | 
      /MD\.?\b ?/i   | 
      /LLB\.?\b ?/i  | 


      /XI{1,3}\b ?/i | # 11th, 12th, 13th
      /X\b ?/i       | # 10th
      /IV\b ?/i      | # 4th
      /VI{1,3}\b ?/i | # 6th, 7th, 8th
      /V\b ?/i       | # 5th
      /IX\b ?/i      | # 9th
      /I{1,3}\b ?/i    # 1st, 2nd, 3rd
};

# Two or more charaters. This is set to 2 as a work around for the problem
# with detecting suffixes like Snr. and Jnr. The dot here gets picked up
# as non matching.

my $non_matching = q{ non_matching: /.{2,}/ };


#-------------------------------------------------------------------------------
# Assemble correct combination for grammar tree.

sub _create
{
   my $name = shift;

   my $grammar = $rules_start;

   if ( $name->{joint_names} )
   {
       $grammar .= $rules_joint_names;
   }    
   $grammar .= $rules_single_names . $precursors . $titles;

    if ( $name->{extended_titles} )
    {
        $grammar .= $extended_titles;
    }

   $grammar .= $conjunction;

   $grammar .= $single_initial;

   $name->{initials} > 3 and $name->{initials} = 3;
   $name->{initials} < 1 and $name->{initials} = 1;

   # Define limit of when a string is treated as an initial, or
   # a given name. For example, if initials are set to 2, MR TO SMITH
   # will have initials of T & O and no given name, but MR TOM SMITH will
   # have no initials, and a given name of Tom.

   if ( $name->{initials} == 1 )
   {
      $grammar .= $given_name_min_2 . $initials_1;
   }
   elsif ( $name->{initials} == 2 )
   {
      $grammar .= $given_name_min_3 . $initials_2;
   }
   elsif ( $name->{initials} == 3 )
   {
      $grammar .= $given_name_min_4 . $initials_3;
   }
   
   $grammar .= $fixed_length_given_name
             . $middle_name
             . $full_surname
             . $suffix
             . $non_matching
             ;

   return($grammar);
}
#-------------------------------------------------------------------------------
1;
