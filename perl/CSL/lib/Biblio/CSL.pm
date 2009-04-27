package Biblio::CSL;

use 5.010000;
use strict;
use warnings;
use Moose;
use XML::Smart;
use Switch;

require Exporter;

use Data::Dumper;    # TODO: just for debugging

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
  reader   => 'get_IDs',
  writer   => 'set_IDs',
  required => 1
);

# switch to put citation generation on (=1) or off (=0).
# TODO: Do we need such a switch for the bibliography, too?
has 'generateCitations' => (
  is        => 'rw',
  isa       => 'Int',
  default   => "1",
  required  => 0
);

# sorted array of strings, 
# after transformation it contains the list of citations
my @_citations = (); # the actual container
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
# the reference and its container are linked in the BUILD method
my @_biblio = (); # the actual container
has 'biblio' => (
  is       => 'rw',
  isa      => 'ArrayRef',
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
    
    # register result-arrays
    $self->citations(\@_citations);
    $self->biblio(\@_biblio);    
      
    # generate the central hash structures
    $self->_m(XML::Smart->new($self->get_mods));
    $self->_c(XML::Smart->new($self->get_csl));
    
    #print Dumper $self->_m; exit;
    #print Dumper $self->_c; exit;
    
    # initialize some attributes
    $self->_citationsSize(_setCitationsSize($self));
    $self->_biblioSize(_setBiblioSize($self));
    # do we have a biblio entry for each citation and vice versa?
    if($self->_citationsSize != $self->_biblioSize) {
        print STDERR  "Warning: the number of citations and the size of the bibliography differ, but should be of equal.";
    }
}

# trigger to check that the format is validly set to a supported type
sub _set_format {
    my ($self, $format, $meta_attr) = @_;

    if ($format ne "txt") {
        die "ERROR: Unknwon output format\n";
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

# print citations
sub citationsToString {
        my $self = shift;
        foreach my $item ( @{$self->citations} ) {
            print $item, "\n";
        }
}

# print bibliography
sub biblioToString {
        my $self = shift;
        foreach my $item ( @{$self->biblio} ) {
            print $item, "\n";
        }
}

# do the transformation of the mods file given the csl style file
sub transform {
    my $self = shift;
    
    # handle citations
    if($self->generateCitations==1) {
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
            #print Dumper $mods;            
            transformEach($mods, $self); # TODO: only 1 param: self
        }
    }
    else { # no collection, transform just a single mods        
        transformEach($self->_m->{mods}, $self); # TODO: only 1 param: self
    }
}


###########################
## private methods

# case $self->_c->{style}->{citation}
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
    elsif(exists $ptr->{option}->{value}) { # second posibility of specifying citation-number
        switch($ptr->{option}->{value}) {
            case "citation-number" {
                $numbers = 1;
            }
            else {
                die "ERROR: The CSL-attribute style->citation->option->value eq '".($ptr->{option}->{value})."' is not implemented, yet.";
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
        push @_citations, $ret_id; # store the citation
    }
}


# parse a single mods entry
sub transformEach() {
    my ($mods, $self) = @_;
    
    if($self->_c->{style}) {
        # here we handle the bibliography only, the citations have already been generated.
        if( $self->_c->{style}->{bibliography} ) {
            if( $self->_c->{style}->{bibliography}->{layout} ) {
                my @nodes = $self->_c->{style}->{bibliography}->{layout}->nodes_keys();
                my @order = $self->_c->{style}->{bibliography}->{layout}->order();

                # node names are not unique, e.g. text
                # therefore we have to keep the index position for each node in the respective array
                # $node-name -> $node->array_position
                my %i;
                foreach my $n (@nodes) {
                    $i{$n} = 0;
                }
                
                # move through layout
                foreach my $o ( @order ) {
                    #print "\n--- $o ---\n";
                    
                    switch($self->_c->{style}->{bibliography}->{layout}->{$o}->key()) {
                        case "suffix" {
                            _layoutSuffix($mods, $self);
                        }
                        case "text" {
                            _layoutText($mods, \%i, $o, $self);
                        }
                    
                        case "date" {
                            _layoutDate($mods, $self);
                        }
                        case "choose" {
                            _layoutChoose($mods, $self);
                        }
                        else {
                            die "ERROR: The case CSL-attribute style->bibliography->layout eq '".($self->_c->{style}->{bibliography}->{layout}->{$o}->key())."' is not implemented yet!";
                        }
                    }
                    $i{$o}++ if(exists $i{$o});
                }
                #print Dumper %i;                
            }
            else {
                die "ERROR: CSL-element 'layout' not available?";
            }
        }
        else {
            die "ERROR: CSL-element 'bibliography' not available?";
        }
        push @_biblio, $self->{_biblio_str};
        $self->{_biblio_str}="";
    }
    else {
        die "ERROR: CSL-element 'style' not available?";
    }    
}



# case $self->_c->{style}->{bibliography}->{layout} eq suffix
sub _layoutSuffix {
    my ($mods, $self) = @_;
    # TODO
}


# case $self->_c->{style}->{bibliography}->{layout} eq text
sub _layoutText {
    my ($mods, $i, $o, $self) = @_;
    
    # shorten the whole thing
    my $text = $self->_c->{style}->{bibliography}->{layout}->{text}->[$i->{$o}]->pointer;
                        
    if(exists $text->{variable} && exists $text->{suffix} && $text->{variable} eq "citation-number") {
        $self->{_biblioNumber}++;
        #print $self->_biblioNumber, $text->{suffix};
        $self->{_biblio_str} .= $self->{_biblioNumber}.$text->{suffix};
    }
    elsif($text->{macro} eq "author") {
        #print Dumper $text;
        if($mods->{name}) {
            #print Dumper $mods->{name};
            my @names = $mods->{name}->('@');
            my $round = scalar(@names); 
            my $qtNames = $round;

            my ($et_al_min , $et_al_use_first) = (0, 0);
            
            # read et-al options
            my @options = $self->_c->{style}->{bibliography}->{option}('@');
            foreach my $o ( @options ) {
               #print Dumper $o->pointer;
                switch($o->pointer->{name}) {
                    case "et-al-min" {
                        $et_al_min = $o->pointer->{value};
                    }
                    case "et-al-use-first" {
                        $et_al_use_first = $o->pointer->{value};
                    }                    
                }
            }

            # print the names
            foreach my $n ( @names ) {
                #print Dumper $n->pointer; exit;
                
                my $complete_name = "";
                
                # either not enough for et-al or we use the first authors until we reach $et_al_use_first
                if($qtNames < $et_al_min || (($qtNames >= $et_al_min) && ($qtNames-$round)<$et_al_use_first) ) {
                    my $c_nameEQauthor = $self->_c->{style}->{macro}('name','eq','author') ;
                    my $family_name = $n->{namePart}('type', 'eq', 'family');
                    my @given_names = $n->{namePart}('type', 'eq', 'given');
                    #print Dumper @given_names;
                                        
                    my $and = "";
                    if($c_nameEQauthor->{names}->{name}->{and} eq "text" ) {
                        $and = "and ";
                    }
                    elsif($c_nameEQauthor->{names}->{name}->{and} eq "symbol" ) {
                        $and = "&";
                    }
                    
                    #print $c_nameEQauthor->{names}->{name}->{"name-as-sort-order"}; exit;
                    if($c_nameEQauthor->{names}->{name}->{'name-as-sort-order'} eq "all") { # all -> Doe, John                                             
                        #print Dumper $n->{namePart}->[1]->pointer; exit;
                        $complete_name = $family_name.$c_nameEQauthor->{names}->{name}->{'sort-separator'};
                        
                        if(exists $c_nameEQauthor->{names}->{name}->{'initialize-with'}) {
                            foreach my $gn (@given_names) {
                                my @nameParts = split /\s+/, $gn;
                                for(my $i=0; $i<=$#nameParts; $i++) { # shorten each name part to its initial and add the respective char, e.g. Rose -> R.
                                    if($nameParts[$i] =~ /^(\S)/) {
                                        $nameParts[$i] = $1;
                                        $complete_name .= $nameParts[$i].$c_nameEQauthor->{names}->{name}->{'initialize-with'};
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
                    elsif($c_nameEQauthor->{names}->{name}->{'name-as-sort-order'} eq "first") { # what does this option mean?
                        die "ERROR: The case CSL-attribute style->macro->name(eq author)->names->name->{'name-as-sort-order'}(eq first) is not implemented yet!";
                    }
                    else { # attribute not given -> "John Doe"
                        die "ERROR: The case CSL-attribute style->macro->name(eq author)->names->name->{'name-as-sort-order'} not given is not implemented yet!";
                    }                                    
                    
                    if($c_nameEQauthor->{names}->{name}->{'delimiter-precedes-last'} eq 'always') {
                        $complete_name .= $c_nameEQauthor->{names}->{name}->{delimiter} if($round>1);
                        $complete_name .= $and if($round==2);
                    }
                    elsif($c_nameEQauthor->{names}->{name}->{'delimiter-precedes-last'} eq 'never') {
                        if($qtNames == 2 && $round>1) {
                            $complete_name .= $and;
                        }
                        else {
                            $complete_name .= $c_nameEQauthor->{names}->{name}->{delimiter} if($round>1);
                            $complete_name .= $and if($round==2);
                        }
                    }
                    else {
                        die "ERROR: The CSL-attribute style->macro->name(eq author)->names->name->{'delimiter-precedes-last'} is not available?";
                    }
                }
                
                $round--;
                
                #print $complete_name;
                $self->{_biblio_str} .= $complete_name;
            }
            
            # add et.al string
            if($qtNames >= $et_al_min) {
                $self->{_biblio_str} .= "et al.";
            }
        }
        #print Dumper @authors;
    }    
}

# case $self->_c->{style}->{bibliography}->{layout} eq date
sub _layoutDate {
    my ($mods, $self) = @_;
    
    # just shorten
    my $ptr = $self->_c->{style}->{bibliography}->{layout}->{date}->pointer;
    
    $self->{_biblio_str} .= $ptr->{prefix} if(exists $ptr->{prefix});
    
    if(exists $ptr->{'date-part'}) {
        if(exists $ptr->{'date-part'}->{name}) {
            switch($ptr->{'date-part'}->{name}) { # month | day | year-other
                case "month" { # 1. 
                    
                }
                case "day" { # 2.
                    
                }
                case "year" { # 3.1
                    # unfortunately there are several ways to define the year:
                    my $year = "";
                    if(exists $mods->{relatedItem}->{part}->{date}) {
                        $year = $mods->{relatedItem}->{part}->{date}->{CONTENT};
                    }
                    elsif(exists $mods->{relatedItem}->{originInfo}->{dateIssued}) {
                        $year = $mods->{relatedItem}->{originInfo}->{dateIssued}->{CONTENT};
                        if($year =~ /(\d\d\d\d)$/) {
                            $year = $1;
                        }
                    }
                    else {
                        die "ERROR: How else should I get the year info?";
                    }
                    
                    # now we have the long year, e.g. 2000.
                    # perhaps we have to shorten it                    
                    if(exists $ptr->{'date-part'}->{form}) {
                        switch($ptr->{'date-part'}->{form}) {
                            case "short" {
                                
                            }
                            case "long" {
                                
                            }
                            else {
                                die "ERROR: The CSL-attribute style->bibliography->layout->date->date-part->form eq '".($ptr->{'date-part'}->{form})."' is not implemented, yet.";
                            }
                        }
                    }
                    
                    # the year is ready, add it 
                    $self->{_biblio_str} .= $year;
                    
                }
                case "other" { # 3.2
                    
                }
                else {
                    die "ERROR: The CSL-attribute style->bibliography->layout->date->date-part->name eq '".($ptr->{'date-part'}->{name})."' is not implemented, yet.";
                }
            }
        }
    }
    
    $self->{_biblio_str} .= $ptr->{suffix} if(exists $ptr->{suffix});    
}

# case $self->_c->{style}->{bibliography}->{layout} eq choose
sub _layoutChoose {
    my ($mods, $self) = @_;
    
    my @options = $self->_c->{style}->{bibliography}->{layout}->{choose}->nodes_keys();
    my $opt = $self->_c->{style}->{bibliography}->{layout}->{choose}->pointer;
    foreach my $o (@options) {
        if($opt->{$o}->{type}) {        
            switch($opt->{$o}->{type}) {
                case "article" {
                }
                case "article-magazine" {
                }
                case "article-newspaper" {
                }
                case "article-journal" {
                }
                case "bill" {
                }
                case "book" {
                }
                case "broadcast" {
                }
                case "chapter" {
                }
                case "entry" {
                }
                case "entry-dictionary" {
                }
                case "entry-encyclopedia" {
                }
                case "figure" {
                }
                case "graphic" {
                }
                case "interview" {
                }
                case "legislation" {
                }
                case "legal_case" {
                }
                case "manuscript" {
                }
                case "map" {
                }
                case "motion_picture" {
                }
                case "musical_score" {
                }
                case "pamphlet" {
                }
                case "paper-conference" {
                }
                case "patent" {
                }
                case "post" {
                }
                case "post-weblog" {
                }
                case "personal_communication" {
                }
                case "report" {
                }
                case "review" {
                }
                case "review-book" {
                }
                case "song" {
                }
                case "speech" {
                }
                case "thesis" {
                }
                case "treaty" {
                }
                case "webpage" {
                }
            }
        }
        else { # no settings just print 
            
            # e.g. article title
            if($opt->{$o}->{text}->{macro}) {
                $self->{_biblio_str} .= $opt->{$o}->{text}->{prefix} if($opt->{$o}->{text}->{prefix});
                
                if($opt->{$o}->{text}->{macro} eq "title") { 
                    if($mods->{titleInfo}->{title}) {                        
                        my $title = $mods->{titleInfo}->{title};
                        $title =~ s/\n//g;
                        $title =~ s/\s+/ /g;
                        $self->{_biblio_str} .= $title;
                    }
                }
                
                $self->{_biblio_str} .= $opt->{$o}->{text}->{suffix} if($opt->{$o}->{text}->{suffix});
            }
            
            if(exists $opt->{$o}->{group}) {        
                #my @order = $self->_c->{style}->{bibliography}->{layout}->{choose}->{$o}->{group}->order();
                #print Dumper @order; exit;
                my $elemNumber = 0;
                # return value of elemNumber not important but necessary to keep the biblio_string intact.
                _parseGroup($mods, $self, $opt->{$o}->{group}, 0);
                
                
            }
        }
    }    
}

# parse csl group element
# A group can have subgroups.
# Therefore, we provide the groupStr
# covering the result string.
# At the first call of _parseGroup the string is empty.
# In subgroups we extend the string, recursively.
# Furhermore, we need the number of overall printed elements in the recursion
sub _parseGroup {
    my ($mods, $self, $g, $elemNumber) = @_;

    $self->{_biblio_str} .= $g->{'prefix'}  if(exists $g->{'prefix'});
    
    # index of the group element

    # cause text could appear more than once in the ordering
    # but if it contains more than once
    # it is represented as array and has its own loop
    my @order = @{$g->{'/order'}};
    my @order_unique = _uniqueArray(\@order);
    
    # not the first element and not the last
    # -1 because of the delimiter entry
    
    #my $round = 0;
    foreach my $k (@order_unique) {
        switch($k) { # formatting | delimiter | TODO:
            #print $k, "\n";
            case "delimiter" {
            }
            case "prefix" { # already done before the loop
            }
            case "suffix" { # will be done after the loop
            }
            case "font-family" {
                
            }
            case "font-style" {
                
            }
            case "font-variant" {
                
            }
            case "font-weight" {
                
            }            
            case "text-decoration" {
                
            }
            case "vertical-align" {
                
            }
            case "text-case" {
                
            }
            case "display" {
                    
            }
            case "quotes" {
                
            }
            case "text" {
                if(ref($g->{$k}) eq "HASH") {
                    $elemNumber++;                    
                    $self->{_biblio_str} .= $g->{'delimiter'} if($elemNumber>1 && exists $g->{'delimiter'});
                    
                    # can appear either as hash
                    if(exists $g->{$k}->{variable}) {
                        $self->{_biblio_str} .= _parseVariable($mods, $self, $g->{$k});
                    }
                }
                elsif(ref($g->{$k}) eq "ARRAY") {
                    # or as array
                    foreach my $v (@{$g->{$k}}) {
                        $elemNumber++;
                        $self->{_biblio_str} .= $g->{'delimiter'} if($elemNumber>1 && exists $g->{'delimiter'});
                    
                        if(exists $v->{variable}) {
                            $self->{_biblio_str} .= _parseVariable($mods, $self, $v);
                        }
                    }
                }
                
            }
            case "group" {
               $elemNumber = _parseGroup($mods, $self, $g->{$k}, 0);
            }
            case "class" {
                
            }
            else {
               die "ERROR: The CSL-attribute ...group->{'".($k)."'} is not available?";
            }
        }        
    }

    $self->{_biblio_str} .= $g->{'suffix'} if(exists $g->{'suffix'});
    
    return $elemNumber;
}



sub _parseVariable {
    my ($mods, $self, $v) = @_;
    
    #print Dumper $var;
    
    my $var = $v->{variable};
    switch($var) {
        ## the primary title for the cited item
        case "title" { 

        }
        ## the secondary title for the cited item; for a book chapter, this 
        ## would be a book title, for an article the journal title, etc.
        # the article title is handled elsewhere, here we have to care about
        #   $mods->{relatedItem}->{titleInfo}
        case "container-title" {
            # short title?
            if(exists $v->{form}) {
                switch($v->{form}) {
                    case "short" {
                        return $mods->{relatedItem}->{titleInfo}->('type','eq','abbreviated')->{title};
                    }
                    case "long" {
                        if(exists $mods->{relatedItem}->{titleInfo}->{title}) {
                            return $mods->{relatedItem}->{titleInfo}->{title};
                        }
                    }
                    else {
                        die "ERROR: Unknown container-title form '".($v->{form})."'";
                    }
                }
            }
            else {
                if(exists $mods->{relatedItem}->{titleInfo}->{title}) {
                    return $mods->{relatedItem}->{titleInfo}->{title};
                }
            }
            #if(exists $mods->{relatedItem}->{titleInfo}->{title}) {
            #     return $mods->{relatedItem}->{titleInfo}->{title};
            #}
        }
        ## the tertiary title for the cited item; for example, a series title
        case "collection-title" {
        }
        ## collection number; for example, series number
        case "collection-number" {
        }
        ## title of a related original version; often useful in cases of translation
        case "original-title" {
        }
        ## the name of the publisher
        case "publisher" {
        }
        ## the location of the publisher
        case "publisher-place" {
        }
        ## the name of the archive
        case "archive" {
        }
        ## the location of the archive
        case "archive-place" {
        }
        ## the location within an archival collection (for example, box and folder)
        case "archive_location" {
        }
        ## the name or title of a related event such as a conference or hearing
        case "event" {
        }
        ## the location or place for the related event
        case "event-place" {
        }
        ##
        case "page" {
            if(exists $mods->{relatedItem}->{part}->{extent}->{unit}) {
                if($mods->{relatedItem}->{part}->{extent}->{unit} eq "page") {
                    if(exists $mods->{relatedItem}->{part}->{extent}->{start} && exists $mods->{relatedItem}->{part}->{extent}->{end}) {
                           return $mods->{relatedItem}->{part}->{extent}->{start}."-".$mods->{relatedItem}->{part}->{extent}->{end};
                    }
                    else {
                        die "ERROR: No start and end page in the mods file?";
                    }
                }
            }
        }
        ## a description to locate an item within some larger container or 
        ## collection; a volume or issue number is a kind of locator, for example.
        case "locator" {
        }
        ## version description
        case "version" {
        }
        ## volume number for the container periodical
        case "volume" {
            if(exists $mods->{relatedItem}->{part}->{detail}->{type}) {
                if($mods->{relatedItem}->{part}->{detail}->{type} eq "volume") {
                    if(exists $mods->{relatedItem}->{part}->{detail}->{number}) {
                        return $mods->{relatedItem}->{part}->{detail}->{number};
                    }
                }
            }
        } 
        ## refers to the number of items in multi-volume books and such
        case "number-of-volumes" {
        } 
        ## the issue number for the container publication
        case "issue" {
        } 
        ##
        case "chapter-number" {
        } 
        ## medium description (DVD, CD, etc.)
        case "medium" {
        } 
        ## the (typically publication) status of an item; for example "forthcoming"
        case "status" {
        } 
        ## an edition description
        case "edition" {
        } 
        ## a section description (for newspapers, etc.)
        case "section" {
        } 
        ##
        case "genre" {
        } 
        ## a short inline note, often used to refer to additional details of the resource
        case "note" {
        } 
        ## notes made by a reader about the content of the resource
        case "annote" {
        } 
        ##
        case "abstract" {
        } 
        ##
        case "keyword" {
        } 
        ## a document number; useful for reports and such
        case "number" {
        }
        ## for related referenced resources; this is here for legal case 
        ## histories, but may be relevant for other contexts.
        case "references" {
        } 
        ##
        case "URL" {
        } 
        ##
        case "DOI" {
        } 
        ##
        case "ISBN" {
        } 
        ##
        case "call-number" {
        } 
        ## the number used for the in-text citation mark in numeric styles
        case "citation-number" {
        } 
        ## the label used for the in-text citation mark in label styles
        case "citation-label" {
        }
        ## The number of a preceding note containing the first reference to
        ## this item. Relevant only for note-based styles, and null for first references.
        case "first-reference-note-number" {
        }
        ## The year suffix for author-date styles; e.g. the 'a' in '1999a'.
        case "year-suffix" {
        }
    }
    
    return "";
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
