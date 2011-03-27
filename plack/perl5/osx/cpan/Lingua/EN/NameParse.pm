=head1 NAME

Lingua::EN::NameParse - routines for manipulating a person's name

=head1 SYNOPSIS

    use Lingua::EN::NameParse qw(clean case_surname);

    # optional configuration arguments
    my %args =
    (
        salutation      => 'Dear',
        sal_default     => 'Friend',
        auto_clean      => 1,
        force_case      => 1,
        lc_prefix       => 1,
        initials        => 3,
        allow_reversed  => 1,
        joint_names     => 0,
        extended_titles => 0
    );

    my $name = new Lingua::EN::NameParse(%args);

    $error = $name->parse("MR AC DE SILVA");

    %name_comps = $name->components;
    $surname = $name_comps{surname_1}; # DE SILVA

    $correct_casing = $name->case_all; # Mr AC de Silva

    $correct_casing = $name->case_all_reversed ; # de Silva, AC

    $good_name = &clean("Bad Na9me   "); # "Bad Name"

    $name->salutation; # Dear Mr de Silva

    %my_properties = $name->properties;
    $number_surnames = $my_properties{number}; # 1
    $bad_input = $my_properties{non_matching};

    $name->report; # create a report listing all information about the parsed name

    $lc_prefix = 0;
    $correct_case = &case_surname("DE SILVA-MACNAY",$lc_prefix); # De Silva-MacNay


=head1 DESCRIPTION


This module takes as input a person or persons name in
free format text such as,

    Mr AB & M/s CD MacNay-Smith
    MR J.L. D'ANGELO
    Estate Of The Late Lieutenant Colonel AB Van Der Heiden

and attempts to parse it. If successful, the name is broken
down into components and useful functions can be performed such as :

   converting upper or lower case values to name case (Mr AB MacNay   )
   creating a personalised greeting or salutation     (Dear Mr MacNay )
   extracting the names individual components         (Mr,AB,MacNay   )
   determining the type of format the name is in      (Mr_A_Smith     )


If the name cannot be parsed you have the option of cleaning the name
of bad characters, or extracting any portion that was parsed and the
portion that failed.

This module can be used for analysing and improving the quality of
lists of names.


=head1 DEFINITIONS


The following terms are used by NameParse to define the components
that can make up a name.

   Precursor   - Estate of (The Late), Right Honourable ...
   Title       - Mr, Mrs, Ms., Sir, Dr, Major, Reverend ...
   Conjunction - word to separate names or initials, such as "And"
   Initials    - 1-3 letters, each with an optional space and/or dot
   Surname     - De Silva, Van Der Heiden, MacNay-Smith, O'Reilly ...
   Suffix      - Snr., Jnr, III, V ...

Refer to the component grammar defined within the code for a complete
list of combinations.

'Name casing' refers to the correct use of upper and lower case letters
in peoples names, such as Mr AB McNay.

To describe the formats supported by NameParse, a short hand representation
of the name is used. The following formats are currently supported :

    Mr_A_Smith_&_Ms_B_Jones
    Mr_&_Ms_A_&_B_Smith
    Mr_A_&_Ms_B_Smith
    Mr_&_Ms_A_Smith
    Mr_A_&_B_Smith
    Mr_John_Adam_Smith
    Mr_John_A_Smith
    Mr_J_Adam_Smith
    Mr_John_Smith
    Mr_A_Smith
    John_Adam_Smith
    John_A_Smith
    J_Adam_Smith
    John_Smith
    A_Smith


Precursors and suffixes are only applied to the following formats:

    Mr_John_A_Smith
    Mr_John_Smith
    Mr_John_Smith
    Mr_A_Smith
    John_Adam_Smith
    John_A_Smith
    J_Adam_Smith
    John_Smith
    A_Smith


=head1 METHODS

=head2 new

The C<new> method creates an instance of a name object and sets up
the grammar used to parse names. This must be called before any of the
following methods are invoked. Note that the object only needs to be
created ONCE, and should be reused with new input data. Calling C<new>
repeatedly will significantly slow your program down.

Various setup options may be defined in a hash that is passed as an optional
argument to the C<new> method. Note that all the arguments are optional. You
need to define the combination of arguments that are appropriate for your
usage.

   my %args =
   (
      salutation     => 'Dear',
      sal_default    => 'Friend',
      auto_clean     => 1,
      force_case     => 1,
      lc_prefix      => 1,
      initials       => 3,
      allow_reversed => 1
   );


   my $name = new Lingua::EN::NameParse(%args);


=over 4

=item salutation

The option defines the salutation word, such as "Dear" or "Greetings". It
must be defined if you are planning to use the C<salutation> method.

=item sal_default

This option defines the defaulting word to substitute for the title and
surname(s), when parsing fails to identify them. It is also used when a
precursor occurs. Examples are "Friend" or "Member". It must be defined if
you are planning to use the C<salutation> method. If an '&' or 'and' occurs
in the unmatched section then it is assumed that we are dealing with more than
one person, and an 's' is appended to the defaulting word.

=item force_case

This option will force the C<case_all> method to name case the entire input
string, including any unmatched sections that failed parsing. For example, in
"MR A JONES & ASSOCIATES", "& ASSOCIATES" will also be name cased. The casing
rules for unmatched sections are the same as for surnames. This is usually
the best option, although any initials in the unmatched section will not
be correctly cased. This option is useful when you know you data has invalid
names, but you cannot filter out or reject them.

=item auto_clean

When this option is set to a positive value, any call to the C<parse> method
that fails will attempt to 'clean' the name and then reparse it. See the
C<clean> method for details. This is useful for dirty data with embedded
unprintable or non alphabetic characters.

=item lc_prefix

When this option is set to a positive value, it will force the C<case_all>
and C<case_component> methods to lower case the first letter of each word that
occurs in the prefix portion of a surname. For example, Mr AB de Silva,
or Ms AS von der Heiden.

=item initials

Allows the user to control the number of letters that can occur in the initials.
Valid settings are 1,2 or 3. If no value is supplied a default of 2 is used.

=item allow_reversed

When this option is set to a positive value, names in reverse order will be
processed. The only valid format is the surname followed by a comma and the
rest of the name, which can be in any of the combinations allowed by non
reversed names. Some examples are:

Smith, Mr AB
Jones, Jim
De Silva, Professor A.B.

The program change the order of the name back to the non reversed format, and
then performs the normal parsing. Note that if the name can be parsed, the fact
that it's order was originally reversed, is not recorded as a property of the
name object.

=item joint_names

When this option is set to a positive value, joint names are accounted for:

Mr_A_Smith_&_Ms_B_Jones
Mr_&_Ms_A_&_B_Smith
Mr_A_&_Ms_B_Smith
Mr_&_Ms_A_Smith
Mr_A_&_B_Smith

Note that if this option is not specified, than by default joint names are
ignored. Disabling joint names speeds up the processing a lot.

=item extended_titles

When this option is set to a positive value, all combinations of titles,
such as Colonel, Mother Superior are used. If this value is not set, only
the following titles are accounted for:

    Mr
    Ms
    M/s
    Mrs
    Miss
    Dr
    Sir
    Dame
    Reverend
    Reverand
    Father
    Captain
    Capt
    Colonel
    Col
    General
    Gen
    Major
    Maj


Note that if this option is not specified, than by default extended titles
are ignored. Disabling  extended titles speeds up the processing.

=back

=head2 parse

    $error = $name->parse("MR AC DE SILVA");

The C<parse> method takes a single parameter of a text string containing a
name. It attempts to parse the name and break it down into the components
described above. If the name was parsed successfully, a 0 is returned,
otherwise a 1. This step is a prerequisite for the following functions.


=head2 case_all

    $correct_casing = $name->case_all;

The C<case_all> method converts the first letter of each component to
capitals and the remainder to lower case, with the following exceptions-

   initials remain capitalised
   surname spelling such as MacNay-Smith, O'Brien and Van Der Heiden are preserved
   - see C<surname_prefs.txt> for user defined exceptions

A complete definition of the capitalising rules can be found by studying
the component grammar defined within the code.

The method returns the entire cased name as text.

=head2 case_all_reversed

    $correct_casing = $name->case_all_reversed;

The C<case_all_reversed> method applies the same type of casing as
C<case_all>. However, the name is returned as surname followed by a comma
and the rest of the name, which can be any of the combinations allowed
for a name, except the title. Some examples are: "Smith, John", "De Silva, A.B."
This is useful for sorting names alphabetically by surname.

The method returns the entire reverse order cased name as text.


=head2 case_components

   %my_name = $name->components;
   $cased_surname = $my_name{surname_1};


The C<case_components> method does the same thing as the C<case_all> method,
but returns the name cased components in a hash. The following keys are used
for each component:

   precursor
   title_1
   title_2
   given_name_1
   given_name_2
   initials_1
   initials_2
   middle_name
   conjunction_1
   conjunction_2
   surname_1
   surname_2
   suffix

If a component has no matching data for a given name, it's values will be
set to the empty string.


=head2 components

   %name = $name->components;
   $surname = $my_name{surname_1};

The C<components> method does the same thing as the C<case_components> method,
but each component is returned as it appears in the input string, with no case
conversion.

=head2 case_surname

   $correct_casing = &case_surname("DE SILVA-MACNAY" [,$lc_prefix]);

C<case_surname> is a stand alone function that does not require a name
object. The input is a text string. An optional input argument controls the
casing rules for prefix portions of a surname, as described above in the
C<lc_prefix> section.

The output is a string converted to the correct casing for surnames.
See C<surname_prefs.txt> for user defined exceptions

This function is useful when you know you are only dealing with names that
do not have initials like "Mr John Jones". It is much faster than the case_all
method, but does not understand context, and cannot detect errors on strings
that are not personal names.


=head2 surname_prefs.txt

Some surnames can have more than one form of valid capitalisation, such as
MacQuarie or Macquarie. Where the user wants to specify one form as the default,
a text file called surname_prefs.txt should be created and placed in the same
location as the NameParse module. The text file should contain one surname per
line, in the capitalised form you want, such as

   Macquarie
   MacHado

NameParse will still operate if the file does not exist

=head2 salutation

The C<salutation> method converts a name into a personal greeting,
such as "Dear Mr & Mrs O'Brien".

If an error is detected during parsing, such as with the name
"AB Smith & Associates", the title (if it occurs) and the surname(s) are
replaced with a default word like "Friend" or "Member". If the input string
contains a conjunction, an 's' is added to the default.

If the name contains a precursor, a default salutation is also produced.


=head2 clean

   $good_name = &clean("Bad Na9me");

C<clean> is a stand alone function that does not require a name object.
The input is a text string and the output is the string with:

   all repeating spaces removed
   all characters not in the set (A-Z a-z - ' , . &) removed


=head2 properties

The C<properties> method returns all the properties of the name,
non_matching, number and type, as a hash.

=over 4

=item type

The type of format a name is in, as one of the following strings:

   Mr_A_Smith_&_Ms_B_Jones
   Mr_&_Ms_A_&_B_Smith
   Mr_A_&_Ms_B_Smith
   Mr_&_Ms_A_Smith
   Mr_A_&_B_Smith
   Mr_John_A_Smith
   Mr_John_Smith
   Mr_A_Smith
   John_Adam_Smith
   John_A_Smith
   J_Adam_Smith
   John_Smith
   A_Smith
   unknown


=item non_matching

Returns any unmatched section that was found.

=back

=head2 report

Create a formatted text report to standard output listing 
- the input string, 
- the name and value of each defined component 
- any non matching component


=head1 LIMITATIONS

The huge number of character combinations that can form a valid names makes
it is impossible to correctly identify them all. Firstly, there are many
ambiguities, which have no right answer.

   Macbeth or MacBeth, are both valid spellings
   Is ED WOOD E.D. Wood or Edward Wood
   Is 'Mr Rapid Print' a name or a company

One approach is to have large lookup files of names and words, statistical rules
and fuzzy logic to attempt to derive context. This approach gives high levels of
accuracy but uses a lot of your computers time and resources.

NameParse takes the approach of using a limited set of rules, based on the
formats that are commonly used by business to represent peoples names. This
gives us fairly high accuracy, with acceptable speed and program size.

NameParse will accept names from many countries, like Van Der Heiden,
De La Mare and Le Fontain. Having said that, it is still biased toward English,
because the precursors, titles and conjunctions are based on English usage.

Names with two or more words, but no separating hyphen are not recognized.
This is a real quandary as Indian, Chinese and other names can have several
components. If these are allowed for, any component after the surname
will also be picked up. For example in "Mr AB Jones Trading As Jones Pty Ltd"
will return a surname of "Jones Trading".

Because of the large combination of possible names defined in the grammar, the
program is not very fast, except for the more limited C<case_surname> subroutine.
See the "Future Directions" section for possible speed ups.

As the parser has a very limited understanding of context, the "John_Adam_Smith"
name type is most likely  to cause problems, as it contains no known tokens
like a title. A string such as "National Australia Bank" would be accepted
as a valid name, first name National etc. Supplying  a list of common pronouns
as exceptions could solve this problem.


=head1 REFERENCES

"The Wordsworth Dictionary of Abbreviations & Acronyms" (1997)

Australian Standard AS4212-1994 "Geographic Information Systems -
Data Dictionary for transfer of street addressing information"


=head1 FUTURE DIRECTIONS

   Add filtering of very long names
   Add diagnostic messages explaining why parsing failed
   Add transforming methods to do things like remove dots from initials
   Try to derive gender (Mr... is male, Ms, Mrs... is female)

Let the user select what level of complexity of grammar they need for
their data. For example, if you know most of your names are in a "John Smith"
format, you can avoid the ambiguity between two letter given names and
initials. Using a limited grammar subset will also be much faster.

Define grammar for other languages. Hopefully, all that would be needed is
to specify a new module with its own grammar, and inherit all the existing
methods. I don't have the knowledge of the naming conventions for non-english
languages.


=head1 SEE ALSO

L<Lingua::EN::AddressParse>, L<Lingua::EN::MatchNames>, L<Lingua::EN::NickNames>,
L<Lingua::EN::NameCase>, L<Parse::RecDescent>


=head1 TO DO


=head1 BUGS

The dot in a suffix of Jnr. or Snr. will be consumed as unmatched text,
and not be retained with the suffix.

=head1 CREDITS

Thanks to all the people who provided ideas and suggestions, including -

   QM Industries <http://www.qmi.com.au>
   Damian Conway,  author of Parse::RecDescent
   Mark Summerfield author of Lingua::EN::NameCase,
   Ron Savage, Alastair Adam Huffman, Douglas Wilson
   Peter Schendzielorz

=head1 AUTHOR

NameParse was written by Kim Ryan <kimryan at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008 Kim Ryan. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut

#-------------------------------------------------------------------------------

package Lingua::EN::NameParse;

use strict;

use Lingua::EN::NameGrammar;
use Parse::RecDescent;

use Exporter;
use vars qw (@ISA @EXPORT_OK);

our $VERSION   = '1.24';
@ISA       = qw(Exporter);
@EXPORT_OK = qw(&clean &case_surname);

#-------------------------------------------------------------------------------
# Create a new instance of a name parsing object. This step is time consuming
# and should normally only be called once in your program.

sub new
{
   my $class = shift;
   my %args = @_;

   my $name = {};
   bless($name,$class);

   # Default to 2 initials per name. Can be overwritten if user defines
   # 'initials' as a key in the hash supplied to new method.
   $name->{initials} = 2;

   my $current_key;
   foreach my $current_key (keys %args)
   {
      if ( $current_key eq 'salutation' or $current_key eq 'sal_default' )
      {
         $name->{$current_key} = &_case_word($args{$current_key});
      }
      else
      {
         $name->{$current_key} = $args{$current_key};
      }
   }

   my $grammar = &Lingua::EN::NameGrammar::_create($name);
   $name->{parse} = new Parse::RecDescent($grammar);

   return ($name);
}
#-------------------------------------------------------------------------------
sub parse
{
   my $name = shift;
   my ($input_string) = @_;

   chomp($input_string);

   # If reverse ordered names are allowed, swap the surname component, before
   # the comma, with the rest of the name. Rejoin the name, replacing comma
   # with a space.

   if ( $name->{allow_reversed} and $input_string =~ /,/ )
   {
      my ($first,$second) = split(/,/,$input_string);
      $input_string = join(' ',$second,$first);
   }

   $name->{components} = ();
   $name->{properties} = ();
   $name->{properties}{type} = 'unknown';
   $name->{error} = 0;

   $name->{input_string} = $input_string;

   $name = &_pre_parse($name);
   unless ( $name->{error} )
   {
       $name = &_assemble($name);
       &_validate($name);

       if ( $name->{error} and $name->{auto_clean} )
       {
          $name->{input_string} = &clean($name->{input_string});
          $name = &_assemble($name);
          &_validate($name);
       }
   }

   return($name,$name->{error});
}
#-------------------------------------------------------------------------------
# Clean the input string. Can be called as a stand alone function.

sub clean
{
   my ($input_string) = @_;

   # remove illegal characters
   $input_string =~ s/[^A-Za-z\-\'\.&\/ ]//go;

   # remove repeating spaces
   $input_string =~ s/  +/ /go ;

   # remove any remaining leading or trailing space
   $input_string =~ s/^ //;
   $input_string =~ s/ $//;

   return($input_string);
}
#-------------------------------------------------------------------------------
# Return all components in a hash

sub components
{
    my $name = shift;
    if ( $name->{properties}{type} eq 'unknown'  )
    {
        return(undef);
    }
    else
    {
        return(%{ $name->{components} });
    }
}
#-------------------------------------------------------------------------------
# Apply correct capitalisation to each component of a person's name.
# Return all cased components in a hash

sub case_components
{
    my $name = shift;

    if ( $name->{properties}{type} eq 'unknown'  )
    {
        return(undef);
    }
    else
    {
        my %orig_components = $name->components;

        my ($current_key,%cased_components);
        foreach $current_key ( keys %orig_components )
        {
            my $cased_value;
            if ( $current_key =~ /initials/ ) # initials_1, possibly initials_2
            {
                $cased_value = uc($orig_components{$current_key});
            }
            elsif ( $current_key =~ /surname|suffix/ )
            {
               $cased_value = &case_surname($orig_components{$current_key},$name->{lc_prefix});
            }
            else
            {
                $cased_value = &_case_word($orig_components{$current_key});
            }

            $cased_components{$current_key} = $cased_value;
        }
        return(%cased_components);
    }
}

#-------------------------------------------------------------------------------
# Hash of of lists, indicating the order that name components are assembled in.
# Each list element is itself the name of the key value in a name object.
# Used by the case_all, case_all_reversed and salutation methods.
# These hashes are created here globally, ais quite a large overhead is
# imposed if the are created locally, each time the method is invoked

my %component_order=
(
    'Mr_John_Smith_&_Ms_Mary_Jones' => ['title_1','given_name_1','surname_1','conjunction_1','title_2','given_name_2','surname_2'],
    'Mr_A_Smith_&_Ms_B_Jones' => ['title_1','initials_1','surname_1','conjunction_1','title_2','initials_2','surname_2'],
    'Mr_&_Ms_A_&_B_Smith'     => ['title_1','conjunction_1','title_2','initials_1','conjunction_1','initials_2','surname_1'],
    'Mr_A_&_Ms_B_Smith'       => ['title_1','initials_1','conjunction_1','title_2','initials_2','surname_1'],
    'Mr_&_Ms_A_Smith'         => ['title_1','conjunction_1','title_2','initials_1','surname_1'],
    'Mr_A_&_B_Smith'          => ['title_1','initials_1','conjunction_1','initials_2','surname_1'],
    'John_Smith_&_Mary_Jones' => ['given_name_1','surname_1','conjunction_1','given_name_2','surname_2'],
    'John_&_Mary_Smith'       => ['given_name_1','conjunction_1','given_name_2','surname_1'],
    'A_Smith_&_B_Jones'       => ['initials_1','surname_1','conjunction_1','initials_2','surname_2'],

    'Mr_John_A_Smith' => ['precursor','title_1','given_name_1','initials_1','surname_1','suffix'],
    'Mr_John_Smith'   => ['precursor','title_1','given_name_1','surname_1','suffix'],
    'Mr_A_Smith'      => ['precursor','title_1','initials_1','surname_1','suffix'],
    'John_Adam_Smith' => ['precursor','given_name_1','middle_name','surname_1','suffix'],
    'John_A_Smith'    => ['precursor','given_name_1','initials_1','surname_1','suffix'],
    'J_Adam_Smith'    => ['precursor','initials_1','middle_name','surname_1','suffix'],
    'John_Smith'      => ['precursor','given_name_1','surname_1','suffix'],
    'A_Smith'         => ['precursor','initials_1','surname_1','suffix']
);

my %reverse_component_order=
(
   'Mr_John_A_Smith'      => ['surname_1','given_name_1','initials_1','suffix'],
   'Mr_John_Smith'        => ['surname_1','given_name_1','suffix'],
   'Mr_A_Smith'           => ['surname_1','initials_1','suffix'],
   'John_Adam_Smith'      => ['surname_1','given_name_1','middle_name','suffix'],
   'John_A_Smith'         => ['surname_1','given_name_1','initials_1','suffix'],
   'J_Adam_Smith'         => ['surname_1','initials_1','middle_name','suffix'],
   'John_Smith'           => ['surname_1','given_name_1','suffix'],
   'A_Smith'              => ['surname_1','initials_1','suffix']
);

#-------------------------------------------------------------------------------
# Apply correct capitalisation to a person's entire name
# Return a string of all cased components in correct order

sub case_all
{
   my $name = shift;

   my @cased_name;

   unless ( $name->{properties}{type} eq 'unknown'  )
   {
      my %component_vals = $name->case_components;
      my @order = @{ $component_order{$name->{properties}{type} } };

      foreach my $component_key ( @order )
      {
         # As some components such as precursors are optional, they will appear
         # in the order array but may or may not have have a value, so only
         # process defined values
         if ( $component_vals{$component_key} )
         {
            push(@cased_name,$component_vals{$component_key});
         }
      }
   }

   if ( $name->{error} and $name->{force_case} )
   {
      # Despite errors, try to name case non-matching section. As the format
      # of this section is unknown, surname case will provide the best
      # approximation, but still fail on initials of more than 1 letter
      push(@cased_name,&case_surname($name->{properties}{non_matching},$name->{lc_prefix}));
   }

   return(join(' ',@cased_name));
}
#-------------------------------------------------------------------------------
# Apply correct capitalisation to a person's entire name 
# Return a string of all cased components in correct reversed order

sub case_all_reversed
{
   my $name = shift;

   my @cased_name_reversed;

   unless ( $name->{properties}{type} eq 'unknown'  )
   {
      my %component_vals = $name->case_components;
      my @reverse_order = @{ $reverse_component_order{$name->{properties}{type} } };

      foreach my $component_key ( @reverse_order )
      {
         # As some components such as precursors are optional, they will appear
         # in the order array but may or may not have have a value, so only
         # process defined values
         
         my $component_value = $component_vals{$component_key};
         if ( $component_value )
         {
            if ($component_key eq 'surname_1')
            {
                $component_value .= ',';
            }
            push(@cased_name_reversed,$component_value);
         }
      }
   }
   return(join(' ',@cased_name_reversed));
}
#-------------------------------------------------------------------------------
# The user may specify their own preferred spelling for surnames.
# These should be placed in a text file called surname_prefs.txt
# in the same location as the module itself.

BEGIN
{
   # Obtain the full path to NameParse module, defined in the %INC hash.
   my $prefs_file_location = $INC{"Lingua/EN/NameParse.pm"};
   # Now substitute the name of the preferences file
   $prefs_file_location =~ s/NameParse\.pm$/surname_prefs.txt/;

   if ( open(PREFERENCES_FH,"<$prefs_file_location") )
   {
      my @surnames = <PREFERENCES_FH>;
      foreach my $name ( @surnames )
      {
         chomp($name);
         # Build hash, lower case name is key for case insensitive
         # comparison, while value holds the actual capitalisation
         $Lingua::EN::surname_preferences{lc($name)} = $name;
      }
      close(PREFERENCES_FH);
   }
}
#-------------------------------------------------------------------------------
# Apply correct capitalisation to a person's surname. Can be called as a
# stand alone function.

sub case_surname
{
    my ($surname,$lc_prefix) = @_;

    # If the user has specified a preferred capitalisation for this
    # surname in the surname_prefs.txt, it should be returned now.
    if ($Lingua::EN::surname_preferences{lc($surname)} )
    {
        return($Lingua::EN::surname_preferences{lc($surname)});
    }

    # Lowercase everything
    $surname = lc($surname);

    # Now uppercase first letter of every word. By checking on word boundaries,
    # we will account for apostrophes (D'Angelo) and hyphenated names
    $surname =~ s/\b(\w)/\u$1/g;

    # Name case Macs and Mcs
    # Exclude names with 1-2 letters after prefix like Mack, Macky, Mace
    # Exclude names ending in a,c,i,o,z or j, typically Polish or Italian

    if ( $surname =~ /\bMac[a-z]{2,}[^a|c|i|o|z|j]\b/i  )
    {
        $surname =~ s/\b(Mac)([a-z]+)/$1\u$2/ig;

        # Now correct for "Mac" exceptions
        $surname =~ s/MacHin/Machin/;
        $surname =~ s/MacHlin/Machlin/;
        $surname =~ s/MacHar/Machar/;
        $surname =~ s/MacKle/Mackle/;
        $surname =~ s/MacKlin/Macklin/;
        $surname =~ s/MacKie/Mackie/;

        # Portuguese
        $surname =~ s/MacHado/Machado/;

        # Lithuanian
        $surname =~ s/MacEvicius/Macevicius/;
        $surname =~ s/MacIulis/Maciulis/;
        $surname =~ s/MacIas/Macias/;
    }
    elsif ( $surname =~ /\bMc/i )
    {
        $surname =~ s/\b(Mc)([a-z]+)/$1\u$2/ig;
    }
    # Exceptions (only 'Mac' name ending in 'o' ?)
    $surname =~ s/Macmurdo/MacMurdo/;


    if ( $lc_prefix )
    {
        # Lowercase first letter of every word in prefix. The trailing space
        # prevents the surname from being altered. Note that spellings like
        # d'Angelo are not accounted for.
        $surname =~ s/\b(\w+ )/\l$1/g;
    }

    # Correct for possessives such as "John's" or "Australia's". Although this
    # should not occur in a person's name, they are valid for proper names.
    # As this subroutine may be used to capitalise words other than names,
    # we may need to account for this case. Note that the s must be at the
    # end of the string
    $surname =~ s/(\w+)'S(\s+)/$1's$2/;
    $surname =~ s/(\w+)'S$/$1's/;

    # Correct for roman numerals, excluding single letter cases I,V and X,
    # which will work with the above code
    $surname =~ s/\b(I{2,3})\b/\U$1/i;  # 2nd, 3rd
    $surname =~ s/\b(IV)\b/\U$1/i;      # 4th
    $surname =~ s/\b(VI{1,3})\b/\U$1/i; # 6th, 7th, 8th
    $surname =~ s/\b(IX)\b/\U$1/i;      # 9th
    $surname =~ s/\b(XI{1,3})\b/\U$1/i; # 11th, 12th, 13th

    return($surname);
}
#-------------------------------------------------------------------------------
# Create a personalised greeting from one or two person's names
# Returns the salutation as a string, such as "Dear Mr Smith"

sub salutation
{
   my $name = shift;

   unless ( $name->{salutation} and  $name->{sal_default})
   {
      die ("No salutation word or default defined");
   }

   my @salutation;
   push(@salutation,$name->{salutation});

   # Personalised salutations cannot be created for Estates or people
   # without some title, refer to default salutation
   if
   (
      $name->{error} or
      ( $name->{components}{precursor} and  $name->{components}{precursor} =~ /Estate/i)  or
      not $name->{components}{title_1}
   )
   {
      # create salutation in the form: Dear Friend(s)?
      my $default = $name->{sal_default};

      # Despite an error, the presence of a conjunction probably
      # means we are dealing with 2 or more people.
      # For example Mr AB Smith & John Jones
      if ( $name->{input_string} =~ / (And|&) /i )
      {
         $default .= 's';
      }
      push(@salutation,$default);
   }
   else
   {
      # create salutation in the form: Dear <title(s)?> <surname(s)?>
      my %component_vals = $name->case_components;
      my @order = @{ $component_order{$name->{properties}{type} } };
      my ($component,@cased_components);
      foreach my $component ( @order )
      {
         unless
         (
            # ignore inital_1, initials_2, given_name_1, etc
            $component =~ /precursor|initial|given_name|middle_name|suffix/ or
            not $component_vals{$component} )
         {
            push(@salutation,$component_vals{$component});
            # shared initial and surname (eg brothers), so duplicate title_1
            if ( $name->{properties}{type} eq 'Mr_A_&_B_Smith' and $component eq 'conjunction_1' )
            {
               push(@salutation,$component_vals{title_1});
            }
         }
      }
   }
   return(join(' ',@salutation));
}
#-------------------------------------------------------------------------------
# Return all name properties in a hash

sub properties
{
   my $name = shift;
   return(%{ $name->{properties} });
}


#-------------------------------------------------------------------------------
# Create a text report to standard output listing 
# - the input string, 
# - the name of each defined component 
# - any non matching component

sub report
{
    my $name = shift;

    printf("%-17.17s : %-40.40s\n","Input",$name->{input_string});
    my %comps = $name->case_components;
    if ( %comps )
    {
        foreach my $comp ( sort keys %comps)
        {
            printf("%-17.17s : %s\n",$comp,$comps{$comp});
        }
    }
    my %props = $name->properties;
    if ( $props{type} )
    {
        printf("%-17.17s : %-40.40s\n","Name type",$props{type});
    }

    if ( $props{non_matching} )
    {
        printf("%-17.17s : %-40.40s\n","Parsing Error","Yes");
        printf("%-17.17s : %-40.40s\n","Non matching part",$props{non_matching});
    }
}
#-------------------------------------------------------------------------------

# PRIVATE METHODS

#-------------------------------------------------------------------------------
# Check that common reserved word (as found in company names) do not appear
sub _pre_parse
{
   my $name = shift;

   if ( $name->{input_string} =~ 
        /\bPty\.? Ltd\.?$|\bLtd\.?$|\bPLC$|Association|Department|National|Society/i )
   {
       $name->{error} = 1;
       $name->{properties}{non_matching} = $name->{input_string};
   }
   return($name);

}
#-------------------------------------------------------------------------------
# Initialise all components to empty string. Assemble hashes of components 
# and properties as part of the name object
# 
sub _assemble
{
   my $name = shift;

   my $parsed_name = $name->{parse}->full_name($name->{input_string});

   # Place components into a separate hash, so they can be easily returned
   # for the user to inspect and modify.

   # For correct matching, the grammar of each component must include the
   # trailing space that separates it from any following word. This should
   # now be removed from the components, and will be restored by the
   # case_all and salutation methods, if called.

   $name->{components}{precursor} = q{};
   if ( $parsed_name->{precursor} )
   {
      $name->{components}{precursor} = &_trim_space($parsed_name->{precursor});
   }

   $name->{components}{title_1} = q{};
   if ( $parsed_name->{title_1} )
   {
      $name->{components}{title_1} = &_trim_space($parsed_name->{title_1});
   }

   $name->{components}{title_2} = q{};
   if ( $parsed_name->{title_2} )
   {
      $name->{components}{title_2} = &_trim_space($parsed_name->{title_2});
   }

   $name->{components}{given_name_1} = q{};
   if ( $parsed_name->{given_name_1} )
   {
      $name->{components}{given_name_1} = &_trim_space($parsed_name->{given_name_1});
   }

   $name->{components}{given_name_2} = q{};
   if ( $parsed_name->{given_name_2} )
   {
      $name->{components}{given_name_2} = &_trim_space($parsed_name->{given_name_2});
   }


   $name->{components}{middle_name} = q{};
   if ( $parsed_name->{middle_name} )
   {
      $name->{components}{middle_name} = &_trim_space($parsed_name->{middle_name});
   }

   $name->{components}{initials_1} = q{};
   if ( $parsed_name->{initials_1} )
   {
      $name->{components}{initials_1} = &_trim_space($parsed_name->{initials_1});
   }

   $name->{components}{initials_2} = q{};
   if ( $parsed_name->{initials_2} )
   {
      $name->{components}{initials_2} = &_trim_space($parsed_name->{initials_2});
   }

   $name->{components}{conjunction_1} = q{};
   if ( $parsed_name->{conjunction_1} )
   {
      $name->{components}{conjunction_1} = &_trim_space($parsed_name->{conjunction_1});
   }

   $name->{components}{conjunction_2} = q{};
   if ( $parsed_name->{conjunction_2} )
   {
      $name->{components}{conjunction_2} = &_trim_space($parsed_name->{conjunction_2});
   }

   $name->{components}{surname_1} = q{};
   if ( $parsed_name->{surname_1} )
   {
      $name->{components}{surname_1} = &_trim_space($parsed_name->{surname_1});
   }

   $name->{components}{surname_2} = q{};
   if ( $parsed_name->{surname_2} )
   {
      $name->{components}{surname_2} = &_trim_space($parsed_name->{surname_2});
   }

   $name->{components}{suffix} = q{};
   if ( $parsed_name->{suffix} )
   {
      $name->{components}{suffix} = &_trim_space($parsed_name->{suffix});
   }


   $name->{properties}{non_matching} = q{};
   if ( $parsed_name->{non_matching} ) 
   {
      $name->{properties}{non_matching}  = $parsed_name->{non_matching};
   }

   $name->{properties}{number} = 0;     
   $name->{properties}{number} = $parsed_name->{number};
   $name->{properties}{type}   = $parsed_name->{type};

   return($name);
}
#-------------------------------------------------------------------------------
# Remove any trailing spaces

sub _trim_space
{
   my ($string) = @_;
   $string =~ s/ $//;
   return($string);
}
#-------------------------------------------------------------------------------
# Check if any name components have illegal characters, or do not have the
# correct syntax for a valid name.


sub _validate
{
   my $name = shift;

   if ( $name->{properties}{non_matching} )
   {
      $name->{error} = 1;
   }
   # illegal characters found
   elsif ( $name->{input_string} =~ /[^A-Za-z\-\'\.,&\/ ]/ )
   {
      $name->{error} = 1;
   }
   elsif ( not &_valid_name($name->{components}{given_name_1}) )
   {
      $name->{error} = 1;
   }
   elsif ( not &_valid_name($name->{components}{middle_name}) )
   {
      $name->{error} = 1;
   }
   
   elsif ( not &_valid_name($name->{components}{surname_1}) )
   {
      $name->{error} = 1;
   }
   elsif ( not &_valid_name($name->{components}{surname_2}) )
   {
      $name->{error} = 1;
   }
   else
   {
      $name->{error} = 0;
   }
}
#-------------------------------------------------------------------------------
# If the name has an assigned value, check that it contains a vowel sound,
# or matches the exceptions to this rule.
# Returns 1 if name is valid, otherwise 0

sub _valid_name
{
   my ($name) = @_;
   if ( not $name )
   {
      return(1);
   }
   # Names should have a vowel sound, 
   # valid exceptions are Ng, Tsz,Md, Cng,Hng,Chng etc
   elsif ( $name and $name =~ /[aeiouyj]|^(ng|tsz|md|(c?h|[pts])ng)$/i )
   {
      return(1);
   }
   else
   {
      return(0);
   }
}
#-------------------------------------------------------------------------------
# Upper case first letter, lower case the rest, for all words in string
sub _case_word
{
   my ($word) = @_;

   $word =~ s/(\w+)/\u\L$1/g;
   return($word);
}
#-------------------------------------------------------------------------------
return(1);
