package Biblio::CSL;

use 5.010000;
use strict;
use warnings;
use Moose;
use XML::Smart;
use Switch;
use utf8;
binmode STDOUT, ":utf8";

require Exporter;

use Data::Dumper;    # TODO: just for debugging;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
  $VERSION
);

# TODO: better as read-only attribute?
our $VERSION = "0.01";

# input xml data file in mods format
has 'mods' => (
  is		=> 'rw',
  isa       => 'Str',
  reader    => 'get_mods',
  writer    => 'set_mods',
  required  => 1
);

# input csl style file
has 'csl' => (
  is       => 'rw',
  isa      => 'Str',
  reader   => 'get_csl',
  writer   => 'set_csl',
  required => 1
);

# output format
has 'format' => (
  is       => 'rw',
  isa      => 'Str',
  reader   => 'get_format',
  writer   => 'set_format',
  default  => 'txt',
  trigger  => \&_set_format,
  required => 1
);

# list of IDs
# several IDs within a citation are separated by comma
# several individual citations are seperated by space
# e.g. "a,b,c d e f,g" for \cite{a,b,c} \cite{d} \cite{e} \cite{e} \cite{f,g}  
has 'IDs' => (
  is       => 'rw',
  isa      => 'Str',
  default  => '',
  reader   => 'get_IDs',
  writer   => 'set_IDs',
  required => 0
);

# sorted array of strings, 
# after transformation it contains the list of citations
has 'citations' => (
  is       => 'rw',
  isa      => 'ArrayRef[Str]',
  required => 0
);

# the overall number of citations
has '_citationsSize' => (
  is        => 'rw',
  isa       => 'Int',
  default   => 0,
  required  => 0
);

# sorted array of strings, 
# after transformation it contains the biliography, each reference as one entry
has 'biblio' => (
  is       => 'rw',
  isa      => 'ArrayRef[Str]',
  required => 0
);

# citation counter,  number of currently parsed biblio entry
has '_biblioNumber' => (
  is        => 'rw',
  isa       => 'Int',
  default   => 0,
  required  => 0
);

# the overall number of biblio entries
has '_biblioSize' => (
  is        => 'rw',
  isa       => 'Int',
  default   => 0,
  required  => 0
);

# string that holds the current entry of the bibliography
has '_biblio_str' => (
  is        => 'rw',
  isa       => 'Str',
  default   => "",
  required  => 0
);

# hashref of the mods hash 
has '_m' => (
  is       => 'rw',
  isa      => 'XML::Smart',
  required => 0
);

# hashref of the csl hash
has '_c' => (
  is       => 'rw',
  isa      => 'XML::Smart',
  required => 0
);

# hash that stores the current set variables
# key: name of variables
# value: content-string
# whenever a variable is set, the name and the content of the variable is kept in the hash
# TODO: no't know yet if I should just add the key, or if I also should keep the actual value
has '_var' => (
    is       => 'rw',
    required => 0
);

# is called after construction
# e.g. useful to validate attributes
sub BUILD {
    my $self = shift;

    if (! -e $self->get_mods ) {
        die "ERROR: The MODS file '", $self->get_mods, "' does not exist!";
    }
    elsif (! -e $self->get_csl ) {
        die "ERROR: The CSL file '", $self->get_csl, "' does not exist!";
    }
      
    # generate the central hash structures
    $self->_m(XML::Smart->new($self->get_mods));
    $self->_c(XML::Smart->new($self->get_csl));
    
    #print Dumper $self->_m; exit;
    #print Dumper $self->_c; exit;

    # initialize some attributes
    $self->_citationsSize(_setCitationsSize($self));
    $self->_biblioSize(_setBiblioSize($self));

    # do we have a biblio entry for each citation and vice versa?
    #if($self->_citationsSize != $self->_biblioSize) {
    #    print STDERR  "Warning: the number of citations and the size of the bibliography differ, but should be equal.";
    #}
}

# trigger to check that the format is validly set to a supported type
sub _set_format {
    my ($self, $format, $meta_attr) = @_;

    if ($format ne "txt") {
        die "ERROR: Unknown output format\n";
    }
}

# set the attribute _citationsSize
sub _setCitationsSize {
    my ($self) = @_;
    
    my $str = $self->get_IDs();
    
    $str =~ s/\,/ /g;
    my @tmp = split /\s+/, $str;
    
    return scalar(@tmp);    
}

# returns the overall number of citations
sub getCitationsSize {
    my $self = shift;
    
    return $self->_citationsSize;
}


# set the attribute _biblioSize
sub _setBiblioSize {
    my ($self) = @_;
    
    my $ret = 0;
    
    if($self->_m->{modsCollection}) { 
        my @tmp = $self->_m->{modsCollection}->{mods}->('@');
        
        # complicated, but necessary 
        # because $ret = scalar(..) wouldn't pass the Moose type-constraint checks.
        for(my $i=0; $i<=$#tmp; $i++) { 
            $ret++;
        }
    }
    else { # no collection, transform just a single mods        
        $ret = 1;
    }
    
    return $ret;
}

# returns the size of the bibliography
sub getBiblioSize {
    my $self = shift;
    
    return $self->_biblioSize;
}

######################################################
### class methods

# return citations as string
sub citationsToString {
    my $self = shift;
    
    my $str = "";
    foreach my $item ( @{$self->citations} ) {
        $str .= $item."\n";
    }
    
    return $str;
}

# return  bibliography as string
sub biblioToString {
    my $self = shift;
    
    my $str = "";
    if($self->biblio) {
        foreach my $item ( @{$self->biblio} ) {
            $str .= $item."\n";
        }
    }
    return $str;
}

# do the transformation of the mods file given the csl style file
sub transform {
    my $self = shift;
    
    # handle citations
    if($self->getCitationsSize>0) {
        if($self->_c->{style}->{citation} ) {
            _parseCitations($self);
        }
        else {
            die "ERROR: CSL-element 'citation' not available?";
        }
    }
    
    # handle bibliography
    if($self->_m->{modsCollection}) { # transform the complete collection
        foreach my $mods ($self->_m->{modsCollection}->{mods}->('@')) {
            #print Dumper $mods; exit;
            transformEach($self, $mods); # TODO: only 1 param: self, $mods or $mods->pointer???
        }
    }
    else { # no collection, transform just a single mods        
        transformEach($self->_m->{mods}, $self); # TODO: only 1 param: self
    }
}


###########################
## private methods

# case $self->_c->{style}->{citation}
# TODO: needs to be revised, does not work with chicago-author-date.csl
sub _parseCitations {
    my $self = shift;
    
    # shorten the whole thing
    my $ptr = $self->_c->{style}->{citation}->pointer;
    #print Dumper $ptr;
        
    my ($prefix, $suffix, $collapse) = ("", "", 0);
    $prefix = $ptr->{layout}->{prefix} if(exists $ptr->{layout}->{prefix});
    $suffix = $ptr->{layout}->{suffix} if(exists $ptr->{layout}->{suffix});
    
    # should we display numbers (e.g. 1, 2, 3, ...) or string-labels (e.g. Rose:09)?
    my $numbers = 0;
    
    if(exists $ptr->{layout}->{text}) {
        if(exists $ptr->{layout}->{text}->{variable}) { # a first way to specify citation-number
            switch($ptr->{layout}->{text}->{variable}) {
                case "citation-number" {
                    $numbers = 1;
                }
                else {
                    die "ERROR: The CSL-attribute style->citation->layout->text->variable eq '".($ptr->{layout}->{text}->{variable})."' is not implemented, yet.";
                }
            }
        }
    }
    elsif(exists $ptr->{option}) { # second posibility of specifying citation-number
        if(exists $ptr->{option}->{value}) {
            switch($ptr->{option}->{value}) {
                case "citation-number" {
                    $numbers = 1;
                }
                else {
                    die "ERROR: The CSL-attribute style->citation->option->value eq '".($ptr->{option}->{value})."' is not implemented, yet.";
                }
            }
        }
    }
    
    # check for collapse mode
    if(exists $ptr->{option}->{name}) {
        switch($ptr->{option}->{name}) {
            case "collapse" {
                $collapse = 1;
            }
            else {
                die "ERROR: The CSL-attribute style->citation->option->name eq '".($ptr->{option}->{name})."' is not implemented, yet.";
            }
        }
    }
        
    my @list = split /\s+/, $self->get_IDs();
    my $citation_i = 0;
    foreach my $l (@list) {
        my $ret_id = ""; # result id that will be returned (stored in the citations array).
        
        # add prefix
        $ret_id .= $prefix;
        
        my @ids = split /\,/, $l;
        
        my $qtIDs = scalar @ids;
        if($qtIDs<3) {        
            for(my $i=0; $i<$qtIDs; $i++) {
                $citation_i++;
                $ids[$i] = $citation_i if($numbers);
                $ret_id .= $ids[$i];
                $ret_id .= $ptr->{layout}->{delimiter} if($i<($qtIDs-1) && exists $ptr->{layout}->{delimiter});
            }
        }
        else { # >= 3 && collapse -> [1-3]
            # take care of the first and the last element
            if($numbers) {
                $citation_i++;
                $ids[0] = $citation_i;
                $ids[$qtIDs-1] = $qtIDs+$citation_i-1;
                $citation_i=$ids[$qtIDs-1]; # set for next round
            }
            
            $ret_id .= $ids[0]."-".$ids[$qtIDs-1];
        }
        
        # add suffix
        $ret_id .= $suffix;
        
        #print "$ret_id\n";    
        push @{$self->{citations}}, $ret_id; # store the citation
    }
}


# parse a single mods entry
sub transformEach() {
    my ($self, $mods) = @_;
    
    if(exists $self->_c->{style}) {
        # here we only handle the bibliography, the citations have already been generated.
        if(exists $self->_c->{style}->{bibliography} ) {
            if(exists $self->_c->{style}->{bibliography}->{layout} ) {  
                # lets go
                _parseChildElements($self, $mods, $self->_c->{style}->{bibliography}->{layout}->pointer, "transformEach(parsing layout)");
                
                # check for "line-formatting" element, attribute-name is {"line-spacing" | "entry-spacing" }.
                my $opt = 0;
                if($opt = $self->_c->{style}->{bibliography}->{option}("name", "eq", "line-spacing")->pointer) {
                    if(exists $opt->{value}) {
                        for(my $i=0; $i < $opt->{value}; $i++) {
                            $self->{_biblio_str} .= "\n"; # add newlines
                        }
                    }
                }
                
                if($opt = $self->_c->{style}->{bibliography}->{option}("name", "eq", "entry-spacing")->pointer ) {
                    if(exists $opt->{value}) {
                        for(my $i=0; $i < $opt->{value}; $i++) {
                            $self->{_biblio_str} .= " "; # add spaces 
                        }
                    }
                }
                
                # the string is ready, add the current entry to the bibliography result-array
                push @{$self->{biblio}}, $self->{_biblio_str};
                $self->{_biblio_str}="";
            }
            else {
                die "ERROR: CSL-element 'layout' not available?";
            }
        }
        else {
            die "ERROR: CSL-element 'bibliography' not available?";
        }
    }
    else {
        die "ERROR: CSL-element 'style' not available?";
    }    
}


# parses relevant major CSL elements while generating the bibliography
sub _parseChildElements {
    my ($self, $mods, $ptr, $from) = @_;
    
    if(ref($ptr) eq "HASH") {
        if(exists $ptr->{prefix}) {
            $self->{_biblio_str} .= $ptr->{prefix};
        }
    }
    
    my @order;
    if(ref($ptr) eq "HASH") {
        if(exists $ptr->{'/order'}) {
            @order = _uniqueArray(\@{$ptr->{'/order'}});
        }
        else {
            @order = keys %{$ptr};
        }
    }
    elsif(ref($ptr) eq "ARRAY") {
        foreach my $k (@$ptr) {
            _parseChildElements($self, $mods, $k, $from);
        }
    }
    else {
        die "ERROR: $ptr is neither hash nor array!";
    }
    
    foreach my $o (@order) {
        switch($o) {
            case '/order' { # cause of speed and to avoid printing the warn-msg
            }
            case '/nodes' { # cause of speed and to avoid printing the warn-msg
            }
            case 'name' { # cause of speed and to avoid printing the warn-msg
            }
            # because of nested macros
            case 'macro' {
                _parseMacro($self, $mods, $ptr->{$o});
            }
            # now all what is directly given by the CSL-standard
            case 'names' {
                _parseNames($self, $mods, $ptr->{$o});
            }
            case 'date' {
                #_parseDate($self, $mods, $ptr->{$o});
                _parseChildElements($self, $mods, $ptr->{$o},"_parseChildElements($o)");
            }
            case 'label' {
                _parseLabel($self, $mods, $ptr->{$o});
            }
            case 'text' {
                #_parseText($self, $mods, $ptr->{$o});
                _parseChildElements($self, $mods, $ptr->{$o}, "_parseChildElements($o)");
            }
            case 'choose' {
                _parseChoose($self, $mods, $ptr->{$o});
            }            
            case 'group' {
                _parseGroup($self, $mods, $ptr->{$o});
            }
            # additional non-top-level elements
            case 'variable' {
                _parseVariable($self, $mods, $ptr->{$o}, 0, "");
            }
            case 'prefix' { # not here, we do it above (=front)
            }
            case 'suffix' { # not here, we do it below (=end)
            }
            case 'date-part' {
                _parseDatePart($self, $mods, $ptr->{$o});
            }
            else {
               print "Warning ($from): '$o' not implemented, yet!\n";
            }
        }
        
        print "### _parseChildElements($o): _biblio_string after parsing $o: '$self->{_biblio_str}'\n";
    }
    
    if(ref($ptr) eq "HASH") {
        if(exists $ptr->{suffix}) {
            $self->{_biblio_str} .= $ptr->{suffix};
        }
    }
}


sub _parseMacro {
    my ($self, $mods, $macro_name) = @_;
    
    my $macro = $self->_c->{style}->{macro}('name','eq',$macro_name)->pointer;
    
    print "_parseMacro: $macro_name\n";
    #print Dumper $macro;
    
    _parseChildElements($self, $mods, $macro, "_parseMacro($macro_name)");
}


sub _parseLabel {
    my ($self, $mods, $l) = @_;
        # TODO
}
    

sub _parseNames {
    my ($self, $mods, $namesPtr) = @_;
    
    print "_parseNames\n";
    print Dumper $namesPtr;
    
    # remind set variables
    if(exists $namesPtr->{variable}) {
        $self->{_var}{$namesPtr->{variable}} = 1;        
        
        # cs-names = "author" | "editor" | "translator" | "recipient" | 
        #            "interviewer" | "publisher" | "composer" | "original-publisher" | "original-author" 
        #            | "container-author"
        #            # to be used when citing a section of a book, for example, to distinguish the author 
        #            # proper from the author of the containing work
        #            | "collection-editor" 
        #            # use for series editor
      
        switch($namesPtr->{variable}) {
            case 'author' {
                _parseNameAuthor($self, $mods, $namesPtr->{name});
            }
            case 'editor' {
                
            }
            case 'translator' {
                
            }
            case 'recipient' {
                
            }
            case 'interviewer' {
                
            }
            case 'publisher' {
                
            }
            case 'composer' {
                
            }
            case 'original-publisher' {
                
            }
            case 'original-author' {
                
            }
            case 'container-author' {
                
            }
            case 'collection-editor' {
                
            }
            else {
                die "ERROR: The names-variable ".($namesPtr->{variable})." is not supported!";
            }
        }
    }
    else {
            die "ERROR: Names element without variable?";
    }
}

# get the author names
sub _parseNameAuthor {
    my($self, $mods, $name) = @_;
    
    print "_parseNameAuthor\n";
    
    if($mods->{name}) {
        #print Dumper $mods->{name};
        my @names = $mods->{name}->('@');
        my $qtNames = scalar(@names);
        my $round = $qtNames;

        my ($et_al_min , $et_al_use_first) = (0, 0);
        
        # read et-al options
        my @options = $self->_c->{style}->{bibliography}->{option}('@');
        foreach my $o ( @options ) {
           #print Dumper $o->pointer;
            switch($o->pointer->{name}) {
                case "et-al-min" { # the minimum number of contributors to use "et al"
                    $et_al_min = $o->pointer->{value};
                }
                case "et-al-use-first" { # the number of contributors to explicitly print under  "et al" conditions
                    $et_al_use_first = $o->pointer->{value};
                }                    
            }
        }

        # print the names
        my $i=0;
        foreach my $n ( @names ) {
            #print Dumper $n->pointer; exit;
            $i++;
            my $complete_name = "";
            
            # either not enough for et-al or we use the first authors until we reach $et_al_use_first
            if($qtNames < $et_al_min || (($qtNames >= $et_al_min) && ($qtNames-$round)<$et_al_use_first) ) {
                my $family_name = $n->{namePart}('type', 'eq', 'family');
                my @given_names = $n->{namePart}('type', 'eq', 'given');
                #print Dumper @given_names;
                                    
                my $and = "";
                if($name->{and} eq "text" ) {
                    $and = "and ";
                }
                elsif($name->{and} eq "symbol" ) {
                    $and = "&";
                }
                
                #print "names and=$and";exit;
                
                if(exists $name->{'name-as-sort-order'}) {
                    if($name->{'name-as-sort-order'} eq "all") { # all -> Doe, John                                             
                        #print Dumper $n->{namePart}->[1]->pointer; exit;
                        $complete_name = $family_name.$name->{'sort-separator'};
                        
                        if(exists $name->{'initialize-with'}) {
                            foreach my $gn (@given_names) {
                                my @nameParts = split /\s+/, $gn;
                                for(my $i=0; $i<=$#nameParts; $i++) { # shorten each name part to its initial and add the respective char, e.g. Rose -> R.
                                    if($nameParts[$i] =~ /^(\S)/) {
                                        $nameParts[$i] = $1;
                                        $complete_name .= $nameParts[$i].$name->{'initialize-with'};
                                    }
                                }
                            }
                            $complete_name =~ s/\s+$//g; # remove endstanding spaces
                        }
                        else {
                            foreach my $gn (@given_names) {
                                $complete_name .= $gn;
                            }
                        }
                    }
                    # only the first name is written as Wash, Stefan the rest is written as 
                    elsif($name->{'name-as-sort-order'} eq "first") {
                        if($i==1) { # Wash, Stefan
                            $complete_name = $family_name.$name->{'sort-separator'};
                            foreach my $gn (@given_names) {
                                my @nameParts = split /\s+/, $gn;
                                for(my $i=0; $i<=$#nameParts; $i++) {
                                    $complete_name .= $nameParts[$i];
                                }
                            }
                        }
                        else { # Stefan Wash
                            foreach my $gn (@given_names) {
                                my @nameParts = split /\s+/, $gn;
                                for(my $i=0; $i<=$#nameParts; $i++) {
                                    $complete_name .= $nameParts[$i]." ";
                                }                            
                            }
                            $complete_name .= $family_name;
                        }
                    }
                    else { # attribute given, but phrase is not supported?
                    }
                }
                else { # attribute not given -> "John Doe"
                    ### not tested yet
                    #foreach my $gn (@given_names) {
                    #       my @nameParts = split /\s+/, $gn;
                    #        for(my $i=0; $i<=$#nameParts; $i++) {
                    #            $complete_name .= $nameParts[$i];
                    #        }
                    #}
                    #$complete_name .= $family_name;
                }                                    
                
                if(exists $name->{'delimiter-precedes-last'}) {
                    if($name->{'delimiter-precedes-last'} eq 'always') {
                        $complete_name .= $name->{delimiter} if($round>1);
                        $complete_name .= $and if($round==2);
                    }
                    elsif($name->{'delimiter-precedes-last'} eq 'never') {
                        if($qtNames == 2 && $round>1) {
                            $complete_name .= $and;
                        }
                        else {
                            $complete_name .= $name->{delimiter} if($round>1);
                            $complete_name .= $and if($round==2);
                        }
                    }
                    else { # attribute exists but the given phrase is not supported
                        
                    }
                }
                else {
                    
                }
            }
            
            $round--;
            
            #print $complete_name;
            $self->{_biblio_str} .= $complete_name; # add the name to the biblio result-string
        }
        
        # add "et al." string
        if($qtNames >= $et_al_min) {
            print "adding et al!\n";
            
            $self->{_biblio_str} .= "et al"; # TODO: 'et al' OR 'et al.'? (with or without dot?)
        }
    }
}

sub _parseDatePart {
    my ($self, $mods, $dp) = @_;
    
    print "_parseDatePart\n";
    #print Dumper $dp;
    
    if(ref($dp) eq "HASH") {
        if(exists $dp->{name}) {
            switch($dp->{name}) { # month | day | year-other
                case "month" { # 1. 
                    # TODO
                }
                case "day" { # 2.
                    # TODO
                }
                case "year" { # 3.1
                    # unfortunately there are several ways to define the year:
                    my $year = "";
                    if(exists $mods->{relatedItem}->{part}->{date}) {
                        $year = $mods->{relatedItem}->{part}->{date};
                    }
                    elsif(exists $mods->{relatedItem}->{originInfo}->{dateIssued}) {
                        $year = $mods->{relatedItem}->{originInfo}->{dateIssued};
                        if($year =~ /(\d\d\d\d)$/) {
                            $year = $1;
                        }
                    }
                    else {
                        die "ERROR: How else should I get the year info?";
                    }
                    
                    # now we have the long year, e.g. 2000.
                    # perhaps we have to shorten it                    
                    if(exists $dp->{form}) {
                        switch($dp->{form}) {
                            case "short" {
                                
                            }
                            case "long" {
                                
                            }
                            else {
                                die "ERROR: The CSL-attribute style->bibliography->layout->date->date-part->form eq '".($dp->{form})."' is not implemented, yet.";
                            }
                        }
                    }
                    
                    # the year is ready, add it 
                    $self->{_biblio_str} .= $year;
                    
                }
                case "other" { # 3.2
                    
                }
                else {
                    die "ERROR: The CSL-attribute style->bibliography->layout->date->date-part->name eq '".($dp->{'date-part'}->{name})."' is not implemented, yet.";
                }
            }
        }
    }
    elsif(ref($dp) eq "ARRAY") {
        foreach my $dp (@$dp) {
            _parseDatePart($self, $mods, $dp);
        }
    }
    else {
        die "ERROR: Date-part is neither hash nor array?";
    }
}


sub _parseChoose {
    my ($self, $mods, $choosePtr) = @_;
    
    print "_parseChoose\n";
    #print Dumper $choosePtr;
    
    my @order;
    if(ref($choosePtr) eq "HASH") {
        if(exists $choosePtr->{'/order'}) {
            @order = _uniqueArray(\@{$choosePtr->{'/order'}});
        }
        else {
            #die "ERROR: Choose has no /order or /nodes entry?";
            @order = keys %$choosePtr;
        }
    }
    elsif(ref($choosePtr) eq "ARRAY") {
        foreach my $c (@{$choosePtr}) {
            _parseChoose($self, $mods, $c);
        }
    }
    else {
        die "ChoosePtr is neither a hash nor an array?";
    }
    # TODO: if, elsif, else needs to be implemented!
    
    my $goOn = 1;
    foreach my $o (@order) {
        print "-- $o --\n";
        if( $o eq "if" && _checkCondition($self, $mods, $choosePtr->{$o})==1 ) {
            print "within if\n";
            _parseChildElements($self, $mods, $choosePtr->{$o}, "_parseConditionContent(if)");
            $goOn=0; # we have seen the "if", so no else-if and no else
        }
        elsif($goOn==1 && $o eq "else-if" && _checkCondition($self, $mods, $choosePtr->{$o})==1) {
            print "within else-if\n";
            _parseChildElements($self, $mods, $choosePtr->{$o}, "_parseConditionContent(else-if)");
            $goOn=0; # we have seen the "else-if", so no else
        }
        elsif($goOn==1 && $o eq "else") { # no conditions just the else statement
            print "within else\n";
            _parseChildElements($self, $mods, $choosePtr->{$o}, "_parseConditionContent(else)");
            $goOn=0;
        }
    }
}


# returns 1 when condition is true otherwise 0
sub _checkCondition {
    my ($self, $mods, $condiPtr) = @_;
    
    #print Dumper $condiPtr;

    print " - check condition - \n";

    my @order;
    if(ref($condiPtr) eq "HASH") {
        if(exists $condiPtr->{'/order'}) {
            @order = _uniqueArray(\@{$condiPtr->{'/order'}});
        }
        #elsif(exists $condiPtr->{'/nodes'}) {
        #    push @order, $condiPtr->{'/nodes'};
        #}
        else {
            #die "ERROR: Condition has no /order or /nodes entry?";
            @order = keys %$condiPtr;
        }
    }
    elsif(ref($condiPtr) eq "ARRAY") {
        foreach my $c (@{$condiPtr}) {
            _checkCondition($self, $mods, $c);
        }
    }
    else {
        die "CondiPtr is neither a hash nor an array?";
    }

    my $truth = 0; # increment if subcondiion is true
    my $qtSubconditions = 0;
    my $match = "";
    foreach my $o (@order) { 
        switch($o) {# for each subcondition
            case 'type' {
                $truth += _checkType($self, $mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'variable' {
                $truth += _checkVariable($self, $mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'is_numeric' {
                $truth += _checkIsNumeric($self, $mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'is_date' {
                $truth += _checkIsDate($self, $mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'position' {
                $truth += _checkPosition($self, $mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'disambiguate' {
                $truth += _checkDisambiguate($self, $mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'locator' {
                $truth += _checkLocator($self, $mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'match' {
                $match = $condiPtr->{match};
            }
        }
    }
    
    switch($match) {
        print "truth=$truth qtSubconditions=$qtSubconditions match='$match'\n";
        case "" {
            
        }
        case "all" {
            if($truth == $qtSubconditions) {
                return 1;
            }
        }
        case "any" {
            if($truth > 0) { # at least 1
                return 1;
            }
        }
        case "none" {            
            if($truth == 0) { # no match
                return 1;
            }
            else {
                return 0;
            }
        }
        else {
            die "ERROR: match='$condiPtr->{match}' is not supported!";
        }
    }
    
    if($truth == $qtSubconditions) {
        return 1;
    }
    
    return 0;
}

# check if the current mods is of the respective type
# returns 1 if the check was positive else 0
sub _checkType {
    my ($self, $mods, $type) = @_;

    print "_checkType: $type\n";

    my %alias=( 
        'academic journal' => 'article-journal',
        'journalArticle' => 'article-journal',
    );

    # if it is the same, we take it right-away  
    if ($mods->{genre} eq $type) {
        return 1;
    } 
    else {
        # We look if we can match an alias, if not return 0
        if ($alias{$mods->{genre}}) {
            return ($alias{$mods->{genre}} eq $type);
        } 
        else {
            return 0;
        }
    }
}

sub _checkVariable {
    my ($self, $mods, $v) = @_;
    
    print "_checkVariable: $v\n";
    
    my @s = split / /, $v;
    foreach my $entry (@s) {
        if(exists ${$self->{_var}}{$entry}) {
            return 1;
        }
    }
    
    return 0;
}

sub _checkIsNumeric {
    my ($self, $mods, $n) = @_;
    
    print "_checkIsNumeric: TODO! $n\n";
    #TODO
    
    return 0;    
}

sub _checkIsDate {
    my ($self, $mods, $d) = @_;
    
    print "_checkIsDate: TODO! $d\n";
    #TODO
    
    return 0;    
}

sub _checkPosition {
    my ($self, $mods, $p) = @_;
    
    print "_checkPosition: TODO! $p\n";
    #TODO
    
    return 0;    
}

sub _checkDisambiguate {
    my ($self, $mods, $t) = @_;
    
    print "_checkDisambiguate: TODO! $t\n";
    #TODO
    
    return 0;    
}

sub _checkLocator {
    my ($self, $mods, $l) = @_;
    
    print "_checkLocator: TODO! $l\n";
    #TODO
    
    return 0;    
}

# parse csl group element
# A group can have subgroups.
# Therefore, we provide the groupStr
# containing the result string for the complete group.
# At the first call of _parseGroup the string is empty.
# In subgroups we extend the string, recursively.
# Furhermore, we need the number of overall printed elements in the recursion
# Maybe, we need more thinking here ;-)
sub _parseGroup {
    my ($self, $mods, $g, $elemNumber) = @_;
    
    print "_parseGroup\n";
    
    if(ref($g) eq "HASH") {
        #$self->{_biblio_str} .= $g->{'prefix'}  if(exists $g->{'prefix'});
        
        # index of the group element

        # cause text could appear more than once in the ordering
        # but if it contains more than once
        # it is represented as array and has its own loop
        my @order = _uniqueArray(\@{$g->{'/order'}});
        
        foreach my $k (@order) {
            switch($k) { # formatting | delimiter | TODO:
                case 'group' {
                    $elemNumber = _parseGroup($self, $mods, $g->{$k}, $elemNumber);
                }
                case 'text' { # TODO _parseText!
                    my $delimiter = "";
                    
                    if(ref($g->{$k}) eq "HASH") {
                        $elemNumber++;
                        if($elemNumber>1 && exists $g->{'delimiter'}) {
                            $delimiter = $g->{'delimiter'};
                            $self->{_biblio_str} .= $g->{'delimiter'};
                        }
                        
                        # can appear either as hash
                        if(exists $g->{$k}->{variable}) {
                            _parseVariable($self, $mods, $g->{$k}, $elemNumber, $delimiter);
                        }
                    }
                    elsif(ref($g->{$k}) eq "ARRAY") {
                        # or as array
                        foreach my $v (@{$g->{$k}}) {
                            $elemNumber++;
                            if($elemNumber>1 && exists $g->{'delimiter'}) {
                                $delimiter = $g->{'delimiter'};
                                $self->{_biblio_str} .= $g->{'delimiter'};
                            }
                        
                            if(exists $v->{variable}) {
                                _parseVariable($self, $mods, $v, $elemNumber, $delimiter);
                            }
                        }
                    }
                    
                }
                case 'macro' {
                    _parseMacro($self, $mods, $g->{$k});
                }
                else {
                   #die "ERROR: The CSL-attribute ...group->{'".($k)."'} is not available?";
                }
            }        
        }

        $self->{_biblio_str} .= $g->{'suffix'} if(exists $g->{'suffix'});
        
        return $elemNumber;
    }
    elsif(ref($g) eq "ARRAY") {
        #print "group-array (".(scalar @$g).")\n";
        foreach my $this_group (@$g) {
            $elemNumber = _parseGroup($self, $mods, $this_group, $elemNumber);
        }
    }
    else {
        die "ERROR: Group is neither hash nor array?";
    }
    
    print "### _biblio_string after group: '$self->{_biblio_str}'\n";
    
    return $elemNumber;
}


sub _parseVariable {
    my ($self, $mods, $v, $elemNumber, $delimiter) = @_;
    
    print "_parseVariable: $v\n";
    
    #$self->{_biblio_str} .= $v->{prefix} if (exists $v->{prefix});
    
    # set the variable at the "availability"-hash.
    ${$self->{_var}}{$v}=1;
    
    switch($v) {
        ## the primary title for the cited item
        case "title" {
                print "within parsing title\n";
                if(exists $mods->{titleInfo}->{title}) {
                    print "mods title: $mods->{titleInfo}->{title}\n";
                    $self->{_biblio_str} .= $mods->{titleInfo}->{title};
                }
                else {
                    die "ERROR: No title tag? How should I else get the title?";
                }
        }
        ## the secondary title for the cited item; for a book chapter, this 
        ## would be a book title, for an article the journal title, etc.
        # the article title is handled elsewhere, here we have to care about
        #  $mods->{relatedItem}->{titleInfo}
        case 'container-title' {
            print "within parsing container-title\n";
            if(! ref($v)) { # its hust the string and that is the order to get the container-title.
                if(exists $mods->{relatedItem}->{titleInfo}->{title}) {
                        $self->{_biblio_str} .= $mods->{relatedItem}->{titleInfo}->{title};
                }
            }            
            elsif(ref($v) eq "HASH") {
                # short title?
                if(exists $v->{form}) {
                    switch($v->{form}) {
                        case "short" {
                            $self->{_biblio_str} .= $mods->{relatedItem}->{titleInfo}->('type','eq','abbreviated')->{title};
                        }
                        case "long" {
                            if(exists $mods->{relatedItem}->{titleInfo}->{title}) {
                                $self->{_biblio_str} .= $mods->{relatedItem}->{titleInfo}->{title};
                            }
                        }
                        else {
                            die "ERROR: Unknown container-title form '".($v->{form})."'";
                        }
                    }
                }
                else {
                    if(exists $mods->{relatedItem}->{titleInfo}->{title}) {
                        $self->{_biblio_str} .= $mods->{relatedItem}->{titleInfo}->{title};
                    }
                }
            }
            elsif(ref($v) eq "ARRAY") {
                die "ERROR. container-title is array, not implemented, yet!";
            }
        }
        ## the tertiary title for the cited item; for example, a series title
        case 'collection-title' {
            print "within parsing collection-title\n";
            
        }
        ## collection number; for example, series number
        case 'collection-number' {
        }
        ## title of a related original version; often useful in cases of translation
        case 'original-title' {
        }
        ## the name of the publisher
        case 'publisher' {
        }
        ## the location of the publisher
        case 'publisher-place' {
        }
        ## the name of the archive
        case 'archive' {
        }
        ## the location of the archive
        case 'archive-place' {
        }
        ## the location within an archival collection (for example, box and folder)
        case 'archive_location' {
        }
        ## the name or title of a related event such as a conference or hearing
        case 'event' {
        }
        ## the location or place for the related event
        case 'event-place' {
        }
        ##
        case 'page' {
            print "within parsing page\n";
            if(exists $mods->{relatedItem}->{part}->{extent}->{unit}) {
                if($mods->{relatedItem}->{part}->{extent}->{unit} eq "pages") {
                    if(exists $mods->{relatedItem}->{part}->{extent}->{start} && exists $mods->{relatedItem}->{part}->{extent}->{end}) {
                        if($mods->{relatedItem}->{part}->{extent}->{start} eq $mods->{relatedItem}->{part}->{extent}->{end}) {
                            $self->{_biblio_str} .= $mods->{relatedItem}->{part}->{extent}->{start};
                        }
                        else {
                            $self->{_biblio_str} .= $mods->{relatedItem}->{part}->{extent}->{start}."-".$mods->{relatedItem}->{part}->{extent}->{end};
                        }
                    }
                    else {
                        die "ERROR: No start and end page in the mods file?";
                    }
                }
                else {
                    die "ERROR: No 'pages' attribut in the mods file?";
                }
            }
            else {
                # remove endstanding spaces and potential delimiters because we can not find the page entry.
                $self->{_biblio_str} =~ s/\s+$//g;
                $self->{_biblio_str} =~ s/,$//g if($elemNumber>1 && $delimiter ne "");
            }
        }
        ## a description to locate an item within some larger container or 
        ## collection; a volume or issue number is a kind of locator, for example.
        case 'locator' {
        }
        ## version description
        case 'version' {
        }
        ## volume number for the container periodical
        case 'volume' {
            print "within parsing volume\n";
            if(exists $mods->{relatedItem}->{part}->{detail}->{type}) {
                if($mods->{relatedItem}->{part}->{detail}->{type} eq "volume") {
                    if(exists $mods->{relatedItem}->{part}->{detail}->{number}) {
                        $self->{_biblio_str} .= $mods->{relatedItem}->{part}->{detail}->{number};
                    }
                    elsif(exists $mods->{relatedItem}->{part}->{detail}->{text}) {
                        $self->{_biblio_str} .= $mods->{relatedItem}->{part}->{detail}->{text};
                    }
                    else {
                        die "ERROR: Volume type is given, but no volume or text tag is found for the volume number? (mods-entry ".($self->_biblioNumber).")";
                    }
                }
                else {
                    die "ERROR: Unknown volume type '".($mods->{relatedItem}->{part}->{detail}->{type})."'. Maybe not implemented, yet?";
                }
            }
            else {
                # remove endstanding spaces and potential delimiters because we can not find the volume entry.
                $self->{_biblio_str} =~ s/\s+$//g;
                $self->{_biblio_str} =~ s/,$//g if($elemNumber>1 && $delimiter ne "");
            }
        } 
        ## refers to the number of items in multi-volume books and such
        case 'number-of-volumes' {
        } 
        ## the issue number for the container publication
        case 'issue' {
        } 
        ##
        case 'chapter-number' {
        } 
        ## medium description (DVD, CD, etc.)
        case 'medium' {
        } 
        ## the (typically publication) status of an item; for example 'forthcoming'
        case 'status' {
        } 
        ## an edition description
        case 'edition' {
        } 
        ## a section description (for newspapers, etc.)
        case 'section' {
        } 
        ##
        case 'genre' {
            print "within parsing genre\n";
        } 
        ## a short inline note, often used to refer to additional details of the resource
        case 'note' {
        } 
        ## notes made by a reader about the content of the resource
        case 'annote' {
        } 
        ##
        case 'abstract' {
        } 
        ##
        case 'keyword' {
        } 
        ## a document number; useful for reports and such
        case 'number' {
        }
        ## for related referenced resources; this is here for legal case 
        ## histories, but may be relevant for other contexts.
        case 'references' {
        } 
        ##
        case 'URL' {
        } 
        ##
        case 'DOI' {
        } 
        ##
        case 'ISBN' {
        } 
        ##
        case 'call-number' {
        } 
        ## the number used for the in-text citation mark in numeric styles
        case 'citation-number' {
            $self->{_biblioNumber}++;
            $self->{_biblio_str} .= $self->{_biblioNumber};
            
            # hardcoded space, some styles have a space at this point, others don't
            $self->{_biblio_str} .= " " if($self->{_biblio_str} !~ /\s$/);
        } 
        ## the label used for the in-text citation mark in label styles
        case 'citation-label' {
        }
        ## The number of a preceding note containing the first reference to
        ## this item. Relevant only for note-based styles, and null for first references.
        case 'first-reference-note-number' {
        }
        ## The year suffix for author-date styles; e.g. the 'a' in '1999a'.
        case 'year-suffix' {
        }        
    }
    
    #$self->{_biblio_str} =~ s/\s$//g; # remove endstanding (maybe hardcoded) gaps
    #$self->{_biblio_str} .= $v->{suffix} if (exists $v->{suffix});
    #$self->{_biblio_str} =~ s/\s\s/ /g; # 2 to 1
}

# returns an array with unique entries
sub _uniqueArray {
    my $array_ref = shift;
    my %seen;
    my @new_array;
    foreach my $a (@$array_ref) {
        if(! exists $seen{$a}) {
            $seen{$a}=1;
            push @new_array, $a;
        }
    }
    return @new_array;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# print the current version of the modul
sub version {
  print "This is XML::CSL version ", $VERSION, "\n";
}

1;
__END__
