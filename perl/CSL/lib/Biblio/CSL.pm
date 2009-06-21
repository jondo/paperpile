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

# verbose mode on (1) or off (0)
has 'verbose' => (
  is        => 'rw',
  isa       => 'Int',
  default   => 0,
  required  => 0
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

# string that holds the current rusult of either parsing the citations or a entry of the bibliography
has '_result' => (
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

# hash that stores the variables
# key: name of variables
# value: content-string
has '_var' => (
    is       => 'rw',
    required => 0
);

# group settings
# hash contains:
#   'inGroup': 1 if we are within a group, 0 otherwise
#   'delimiter': The delimiter.
has '_group' => (
    is       => 'rw',
    required => 0
);

# mapping of months to strings
has '_monthStrings' => (
    is       => 'rw',
    required => 0
);

# mapping of months to numbers
has '_monthNumbers' => (
    is       => 'rw',
    required => 0
);

# hash containing info needed for sorting
# e.g.
# $self->{_sortInfo}->{_withinSorting}
#   flag that shows whether we are within the sorting routine and have to collect sorting keys or not
# $self->{_sortInfo}->{_curKeyNumber}
#   the current i.th key
# $self->{_sortInfo}->{_curKeyElement}
#   Which element, e.g. a macro
# $self->{_sortInfo}->{_curKeyName}
#   Name of the element, e.g. the maro 'contributors'
has '_sortInfo' => (
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
    $self->_citationsSize($self->_setCitationsSize());
    $self->_biblioSize($self->_setBiblioSize());
    
    $self->{_group}->{'inGroup'} = 0;
    $self->{_group}->{'delimiter'} = '';
    
    $self->{_sortInfo}->{_withinSorting} = 0;
    
    # Zotero outputs full month names
    # therefore we need a mapping to the full names
    %{$self->{_monthStrings}} = (
        "Jan" => "January",
        "Feb" => "February",
        "Mar" => "March",
        "Apr" => "April",
        "May" => "May",
        "Jun" => "June",
        "Jul" => "July",
        "Aug" => "August",
        "Sep" => "September",
        "Oct" => "October",
        "Nov" => "November",
        "Dec" => "December",
        "01" => "January",
        "02" => "February",
        "03" => "March",
        "04" => "April",
        "05" => "May",
        "06" => "June",
        "07" => "July",
        "08" => "August",
        "09" => "September",
        "10" => "October",
        "11" => "November",
        "12" => "December"
    );
    
    # sorting requires a numeric date format
    # therefore we need a mapping to the numbers
    # (we store the date as YYYY/MM/DD)
    %{$self->{_monthNumbers}} = (
        "Jan" => "01",
        "Feb" => "02",
        "Mar" => "03",
        "Apr" => "04",
        "May" => "05",
        "Jun" => "06",
        "Jul" => "07",
        "Aug" => "08",
        "Sep" => "09",
        "Oct" => "10",
        "Nov" => "11",
        "Dec" => "12",
        "January" => "01",
        "February" => "02",
        "March" => "03",
        "April" => "04",
        "May" => "05",
        "June" => "06",
        "July" => "07",
        "August" => "08",
        "September" => "09",
        "October" => "10",
        "November" => "11",
        "December" => "12"
    );

    # do we have a biblio entry for each citation and vice versa?
    #if($self->_citationsSize != $self->_biblioSize) {
    #    print STDERR  "Warning: the number of citations and the size of the bibliography differ, but should be equal.";
    #}
}

# trigger to check that the format is validly set to a supported type
sub _set_format {
    my ($self, $format, $meta_attr) = @_;

    if ($format ne "txt") {
        die "ERROR: Unknown output format '$format'\n";
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

# do the transformation of the mods file given the CSL-style file
# parses citations and bibliography
sub transform {
    my $self = shift;
    
    # handle citations
    if($self->getCitationsSize>0) {
        if(exists $self->_c->{style}) {
            if(exists $self->_c->{style}->{citation}) {
                $self->_parseCitations($self->_c->{style}->{citation}->pointer);
            }
            else {
                die "ERROR: CSL-element 'citation' not available?";
            }
        }
    }
    
    # handle bibliography
    if($self->_m->{modsCollection}) { # transform the complete collection
        foreach my $mods ($self->_m->{modsCollection}->{mods}->('@')) {
            $self->_transformEach($mods); # TODO: only 1 param: self, $mods or $mods->pointer???
        }
    }
    else { # no collection, transform just a single mods        
        $self->_transformEach($self->_m->{mods}); # TODO: only 1 param: self
    }
    
    print Dumper $self->{_sort} if($self->{verbose});
    @{$self->{biblio}} = $self->_sortBiblio if(scalar(keys %{$self->{_sort}})>0);
}


###########################
## private methods

# _sort*
# sort the $self->biblio array according to what is specified at $self->_c->{style}->{bibliography}->{sort}

sub _sortAddKeys {
    my $self = shift;
    my $mods = shift;
    my $sort = shift;
    
    print "_sortAddKeys\n" if($self->{verbose});
    
    # whenever we see the sort element, switch the flag that tells us that from now on we have to collect keys for sorting
    $self->{_sortInfo}->{_withinSorting}=1;
    print "Setting $self->{ _sortInfo }->{ _withinSorting }=1\n" if($self->{verbose});    
    
    $self->{_sortInfo}->{_keyNumber}=0;
    foreach my $key ($sort->{key}('[@]') ) {
        $key = $key->pointer;
        #print Dumper $key;
        foreach my $k (keys %{$key}) {
            if(exists $self->{_sortInfo}->{_keyNumber}) {
                $self->{_sortInfo}->{_keyNumber}++;
                print "incrementing _keyNumber to ".$self->{_sortInfo}->{_keyNumber}."\n" if($self->{verbose});
            }
            if(! exists $self->{_sort}->{$self->{_sortInfo}->{_keyNumber}}->{$k}->{$key->{$k}}->{$self->{_biblioNumber}}) {
                $self->{_sort}->{$self->{_sortInfo}->{_keyNumber}}->{$k}->{$key->{$k}}->{$self->{_biblioNumber}} = 1;
                print "adding sort-key _keyNumber=".$self->{_sortInfo}->{_keyNumber}." k=$k _curKeyName=".$key->{$k}."\n" if($self->{verbose});
                if(exists $self->{_var}->{$key->{$k}}) {
                    #print STDERR "$i ->{ $k }->{ ".$key->{$k}." } -> ".($self->{_biblioNumber})."\n";
                    $self->{_sort}->{$self->{_sortInfo}->{_keyNumber}}->{$k}->{$key->{$k}}->{$self->{_biblioNumber}} = $self->{_var}->{$key->{$k}};
                }
            }

            #print STDERR Dumper $key;
            $self->_parseChildElements($mods, $key,"_parseChildElements($key->{$k})");
        }
    }
    
    $self->{_sortInfo}->{_withinSorting}=0;
    print "Setting $self->{ _sortInfo }->{ _withinSorting }=0\n" if($self->{verbose});
}

# TODO: Sorting works just for the first key, yet. 
sub _sortBiblio {
    my $self = shift;
    
    my @tmp; # container for the _biblio entries
    my %s; # hash to realize sorting of multiple keys
    #print "_sortBiblio:\n";
    
    foreach my $sort_order (sort {$a<=>$b} keys %{$self->{_sort}}) { # order of the keys
        foreach my $k (keys %{$self->{_sort}->{$sort_order}}) {
            foreach my $kk (keys %{$self->{_sort}->{$sort_order}->{$k}}) {
                foreach my $kkk (keys %{$self->{_sort}->{$sort_order}->{$k}->{$kk}}) {
                    #print "sort_order: ", $sort_order, " ", $k, " ", $kk, " ", $kkk, " = ", $self->{_sort}->{$sort_order}->{$k}->{$kk}->{$kkk},"\n";
                    if(exists $s{$kkk}) {
                        $s{$kkk} .= $self->{_sort}->{$sort_order}->{$k}->{$kk}->{$kkk}." ";
                    }
                    else {
                        $s{$kkk} = $self->{_sort}->{$sort_order}->{$k}->{$kk}->{$kkk}." ";
                    }                        
                }
            }
        }
    }
    
    # $i is the order/number of the respective biblio entry
    foreach my $i (sort {$s{$a} cmp $s{$b}} keys %s) { # actual sorting due to multiple concatenated keys
        #print $i, " ", $s{$i}, "\n";
        push @tmp, $self->{biblio}[$i-1];
    }
    
    return @tmp;
}


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
    
    #print Dumper $ptr;
    
    if(exists $ptr->{option}) {
        if(my $o = $self->_c->{style}->{citation}->{option}('name', 'eq', 'collapse')) {
             $collapse = 1;
            if($o->{value} eq 'citation-number') {
                $numbers = 1;
            }
        }
    }
    elsif(exists $ptr->{layout}->{text}) {
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
# here we only handle the bibliography, the citations have already been generated.
sub _transformEach() {
    my ($self, $mods) = @_;
    
    if(exists $self->_c->{style}) {
        if(exists $self->_c->{style}->{bibliography} ) {            
            if(exists $self->_c->{style}->{bibliography}->{layout} ) {
                $self->{_biblioNumber}++; # we are parsing the next entry
                $self->_updateVariables($mods->pointer);

                if(exists $self->_c->{style}->{bibliography}->{sort}) {
                    $self->_sortAddKeys($mods, $self->_c->{style}->{bibliography}->{sort}); # initialize the sorting hash.
                    #print STDERR Dumper $self->{_sort};
                }
                
                my $ptr = $self->_c->{style}->{bibliography}->{layout}->pointer;
                $self->_parseChildElements($mods, $ptr, "transformEach(parsing layout)");
                if(exists $ptr->{suffix}) { # TODO: is it really possible to forget the layout-suffix?
                    $self->{_result} .= $ptr->{suffix};
                }
                
                # check for "line-formatting" element, attribute-name is {"line-spacing" | "entry-spacing" }.
                my $opt = 0;
                if($opt = $self->_c->{style}->{bibliography}->{option}("name", "eq", "line-spacing")->pointer) {
                    if(exists $opt->{value}) {
                        for(my $i=0; $i < $opt->{value}; $i++) {
                            $self->{_result} .= "\n"; # add newlines
                        }
                    }
                }
                
                if($opt = $self->_c->{style}->{bibliography}->{option}("name", "eq", "entry-spacing")->pointer ) {
                    if(exists $opt->{value}) {
                        for(my $i=0; $i < $opt->{value}; $i++) {
                            $self->{_result} .= " "; # add spaces 
                        }
                    }
                }
                
                # hardcoded rule: if we have "et al" and it doesn't end with a ., we add it.
                $self->{_result} =~ s/et al/et al./g if($self->{_result} =~ /et al[^\.]/);
                # hardcoded rule: remove double spaces
                $self->{_result} =~ s/  / /g if($self->{_result} =~ /  /);
                # hardcoded rule: solve space-comma-space
                $self->{_result} =~ s/ , /, /g if($self->{_result} =~ / , /);
                # hardcoded rule: if we start with number and ., a space must follow
                $self->{_result} = $1." ".$2.$3 if($self->{_result} =~ /^(\d+\.)(\S)(.+)/);
                # hardcoded rule: if we have quotes and the quote comes before a ., switch them
                $self->{_result} =~ s/\x{0201D}\./\.\x{0201D}/g if($self->{_result}=~ /\x{0201D}\./);
                # hardcoded rule: remove double dots
                $self->{_result} =~ s/\.\./\./g if($self->{_result} =~ /\.\./);
                # hardcoded rule: remove double comma
                $self->{_result} =~ s/\,\,/\,/g if($self->{_result} =~ /\,\,/);
                
                # the string is ready, add the current entry to the bibliography result-array
                push @{$self->{biblio}}, $self->{_result};
                $self->{_result}="";
                $self->{_sortInfo} = ();
                $self->{_sortInfo}->{_withinSorting} = 0;
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

# cleans the old and store the current variables of the current mods
sub _updateVariables {
    my ($self, $mods) = @_;
    
    print "_updateVariables\n" if($self->{verbose});
    
    %{$self->{_var}} = (); 
    %{$self->_var} = (
        'title' => '',
        'container-title' => '',
        'container-title_short' => '',        
        'collection-title' => '',
        'collection-number' => '',
        'original-title' => '',
        'publisher' => '',
        'publisher-place' => '',
        'archive' => '',
        'archive-place' => '',
        'archive_location' => '',
        'event' => '',
        'event-place' => '',
        'page' => '',
        'locator' => '',
        'version' => '',
        'volume' => '',
        'number-of-volumes' => '',
        'issue' => '',
        'chapter-number' => '',
        'medium' => '',
        'status' => '',
        'edition' => '',
        'section' => '',
        'genre' => '',
        'note' => '',
        'annote' => '',
        'abstract' => '',
        'keyword' => '',
        'number' => '',
        'references' => '',
        'URL' => '',
        'DOI' => '',
        'ISBN' => '',
        'call-number' => '',
        'citation-number' => '',
        'citation-label' => '',
        'first-reference-note-number' => '',
        'year-suffix' => '',
        'editor' => '',
        'translator' => '',
        'interviewer' => '',
        'recipient' => '',
        'issued' => '',
        'event' => '',
        'accessed' => '',
        'container' => '',
        'original-date' => ''
    );

    # now get existing values for these given keys

    foreach my $k (keys %{$self->_var}) {
        switch($k) {
            ## the primary title for the cited item
            case 'title' {
                if(exists $mods->{titleInfo}->{title}) {
                    $self->_var->{'title'} = $mods->{titleInfo}->{title}->{CONTENT};
                }
                else {                    
                }
            }
            ## the secondary title for the cited item; for a book chapter, this 
            ## would be a book title, for an article the journal title, etc.
            # the article title is handled elsewhere, here we have to care about
            #  $mods->{relatedItem}->{titleInfo}
            case 'container-title' {
                if(exists $mods->{relatedItem}) {
                    if(exists $mods->{relatedItem}->{titleInfo}) {
                        my $r = ref($mods->{relatedItem}->{titleInfo});
                        if($r eq "HASH") {
                                if(exists $r->{type}) { # dont get special title variants
                                }
                                else {
                                    $self->{_var}->{'container-title'} = $mods->{relatedItem}->{titleInfo}->{title}->{CONTENT};
                                }
                        }
                        elsif($r eq "ARRAY") { # multiple titles
                            # which should we keep?
                            # we'll try to get the full name
                            # MODS type variants: abbreviated, translated, alternative, uniform
                            my @titles = @{$mods->{relatedItem}->{titleInfo}};
                            foreach my $t (@titles) {
                                if(exists $t->{type}) { # dont get special title variants
                                }
                                else { # try to get the full title
                                    $self->{_var}->{'container-title'} = $t->{title}->{CONTENT};
                                }
                            }
                            
                            # just ensure that we have a conainer-title 
                            if($self->_var->{'container-title'} eq '' && scalar(@titles)>0) {
                                $self->{_var}->{'container-title'} = $titles[0]->{title}->{CONTENT};
                            }
                        }
                        else {
                            die "ERROR: Container-title is neither hash nor array?";
                        }
                    }
                }
            }
            case 'container-title_short' {                
                if(exists $mods->{relatedItem}) {
                    if(exists $mods->{relatedItem}->{titleInfo}) {
                        my $r = ref($mods->{relatedItem}->{titleInfo});
                        if($r eq "HASH") {
                                if(exists $r->{type}) {
                                    if($r->{type} eq 'abbreviated') {
                                        $self->{_var}->{'container-title_short'} = $mods->{relatedItem}->{titleInfo}->{title}->{CONTENT};
                                    }
                                }
                        }
                        elsif($r eq "ARRAY") { # multiple titles
                            # which should we keep?
                            # we'll try to get the full name
                            # MODS type variants: abbreviated, translated, alternative, uniform
                            my @titles = @{$mods->{relatedItem}->{titleInfo}};
                            foreach my $t (@titles) {
                                if(exists $t->{type}) {
                                    if($t->{type} eq 'abbreviated') {
                                        $self->{_var}->{'container-title_short'} = $t->{title}->{CONTENT};
                                    }
                                }
                                else { # don't get full title
                                }
                            }
                            
                            # just ensure that we have a conainer-title 
                            if($self->_var->{'container-title_short'} eq '' && scalar(@titles)>0) {
                                $self->{_var}->{'container-title_short'} = $titles[0]->{title}->{CONTENT};
                            }
                        }
                        else {
                            die "ERROR: Container-title_short is neither hash nor array?";
                        }
                    }
                }
            }
            ## the tertiary title for the cited item; for example, a series title
            case 'collection-title' {
                
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
                if(exists $mods->{relatedItem}->{part}->{extent}->{unit}) {
                    if($mods->{relatedItem}->{part}->{extent}->{unit} eq "pages") {
                        if(exists $mods->{relatedItem}->{part}->{extent}->{start} && exists $mods->{relatedItem}->{part}->{extent}->{end}) {
                            if($mods->{relatedItem}->{part}->{extent}->{start}->{CONTENT} eq $mods->{relatedItem}->{part}->{extent}->{end}->{CONTENT}) {
                                $self->_var->{'page'} = $mods->{relatedItem}->{part}->{extent}->{start}->{CONTENT};
                            }
                            else {
                                $self->_var->{'page'} = $mods->{relatedItem}->{part}->{extent}->{start}->{CONTENT}."-".$mods->{relatedItem}->{part}->{extent}->{end}->{CONTENT};
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
                if(exists $mods->{relatedItem}) {
                    if(exists $mods->{relatedItem}->{part}) {
                        if(exists $mods->{relatedItem}->{part}->{detail}) {
                            my $r = ref($mods->{relatedItem}->{part}->{detail});
                            if($r eq "HASH") {
                                if(exists $mods->{relatedItem}->{part}->{detail}->{type}) {
                                    if($mods->{relatedItem}->{part}->{detail}->{type} eq 'volume') {
                                        if(exists $mods->{relatedItem}->{part}->{detail}->{number}) {
                                            $self->_var->{'volume'} = $mods->{relatedItem}->{part}->{detail}->{number}->{CONTENT};
                                        }
                                        elsif(exists $mods->{relatedItem}->{part}->{detail}->{text}) {
                                            $self->_var->{'volume'} = $mods->{relatedItem}->{part}->{detail}->{text}->{CONTENT};
                                        }
                                        else {
                                            die "ERROR: Volume number is given, but no number or text tag is found for the volume number? (mods-entry ".($self->_biblioNumber).")";
                                        }
                                    }
                                }
                            }
                            elsif($r eq "ARRAY") {
                                my @details = @{$mods->{relatedItem}->{part}->{detail}};
                                foreach my $d (@details) {
                                    if(exists $d->{type}) {
                                        if($d->{type} eq 'volume') {
                                            if(exists $d->{number}) {
                                                $self->_var->{'volume'} = $d->{number}->{CONTENT};
                                            }
                                            elsif(exists $d->{text}) {
                                                $self->_var->{'volume'} = $d->{text}->{CONTENT};
                                            }
                                            else {
                                                die "ERROR: Volumeis given, but no number or text tag is found for the volume number? (mods-entry ".($self->_biblioNumber).")";
                                            }
                                        }
                                    }
                                }                                
                            }
                            else {
                                die "mods->{ relatedItem }->{ part }->{ detail } is neither hash nor array? It is '$r'?\n";
                            }
                        }
                    }
                }
            } 
            ## refers to the number of items in multi-volume books and such
            case 'number-of-volumes' {
            } 
            ## the issue number for the container publication
            case 'issue' {
                if(exists $mods->{relatedItem}) {
                    if(exists $mods->{relatedItem}->{part}) {
                        if(exists $mods->{relatedItem}->{part}->{detail}) {
                            my $r = ref($mods->{relatedItem}->{part}->{detail});
                            if($r eq "HASH") {
                                if(exists $mods->{relatedItem}->{part}->{detail}->{type}) {
                                    if($mods->{relatedItem}->{part}->{detail}->{type} eq 'issue') {
                                        if(exists $mods->{relatedItem}->{part}->{detail}->{number}) {
                                            $self->_var->{'issue'} = $mods->{relatedItem}->{part}->{detail}->{number}->{CONTENT};
                                        }
                                        else {
                                            die "ERROR: Issue is given, but no number tag is found for the volume number? (mods-entry ".($self->_biblioNumber).")";
                                        }
                                    }
                                }
                            }
                            elsif($r eq "ARRAY") {
                                my @details = @{$mods->{relatedItem}->{part}->{detail}};
                                foreach my $d (@details) {
                                    if(exists $d->{type}) {
                                        if($d->{type} eq 'issue') {
                                            if(exists $d->{number}) {
                                                $self->_var->{'issue'} = $d->{number}->{CONTENT};
                                            }
                                            elsif(exists $d->{text}) {
                                                $self->_var->{'issue'} = $d->{text}->{CONTENT};
                                            }
                                            else {
                                                die "ERROR: Issue is given, but no number tag is found for the volume number? (mods-entry ".($self->_biblioNumber).")";
                                            }
                                        }
                                    }
                                }                                
                            }
                            else {
                                die "mods->{ relatedItem }->{ part }->{ detail } is neither hash nor array? It is '$r'?\n";
                            }
                        }
                    }
                }
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
                if(exists $mods->{location}) {
                    if(exists $mods->{location}->{url}) {
                        $self->_var->{$k} = $mods->{location}->{url}->{'CONTENT'};
                        #print STDERR $self->_var->{$k}, "\n";
                    }
                }
            } 
            ##
            case 'DOI' {
                # TODO hash vs array?
                if(exists $mods->{identifier}) {
                    if(exists $mods->{identifier}->{type}) {
                        if($mods->{identifier}->{type} eq 'doi') {
                            $self->_var->{$k} = $mods->{identifier}->{'CONTENT'};
                            #print STDERR $self->_var->{$k}, "\n";
                        }
                    }
                }
            } 
            ##
            case 'ISBN' {
            } 
            ##
            case 'call-number' {
            } 
            ## the number used for the in-text citation mark in numeric styles
            case 'citation-number' {
                $self->_var->{'citation-number'} = $self->{_biblioNumber};
                
                # hardcoded space, some styles have a space at this point, others don't, TODO do we really need this?
                # $self->_var->{'citation-number'} .= " " if($self->_var->{'citation-number'} !~ /\s$/);
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
            ## Roles
            # however, certain roles can appear as names-variable
            case 'editor' {                
            }
            case 'translator' {                
            }
            case 'interviewer' {                
            }
            case 'recipient' {                
            }
            ## cs-date-tokens
            case 'issued' {
                #<relatedItem><originInfo><dateIssued>Mar 12, 2009</dateIssued>
                if(exists $mods->{relatedItem}) {
                    if(exists $mods->{relatedItem}->{originInfo}) {
                        if(exists $mods->{relatedItem}->{originInfo}->{dateIssued}) {
                            my $date = $mods->{relatedItem}->{originInfo}->{dateIssued}->{CONTENT};
                            #print STDERR "date='$date'\n";
                                                                                    
                            my $keep = "";
                            # NAIVE APPROACH
                            # WE'LL KEEP THE DATE AS YEAR/MONTH/DAY
                            if($date =~ /^(\d\d\d\d)$/) { #simple year
                                $keep = $1."/-/-";
                            }
                            elsif($date =~ /^(\S+) (\d\d\d\d)$/) { # month and year
                                if(exists $self->{_monthNumbers}{$1}) {
                                    $keep = $2."/".$self->{_monthNumbers}{$1}."/-";
                                }
                                else {
                                    $keep = $2."/".$1."/-";
                                }
                            }
                            elsif($date =~ /^(\S+) (\d+), (\d\d\d\d)$/) { # month day, year
                                if(exists $self->{_monthNumbers}{$1}) {
                                    $keep = $3."/".$self->{_monthNumbers}{$1}."/".$2;
                                }
                                else {
                                    $keep = $3."/".$1."/".$2;
                                }
                            }
                            else {
                                die "ERROR: Wasn't able to parse the date '$date'?";
                            }
                            $self->_var->{'issued'} = $keep;
                            #print STDERR $keep, "\n"; exit;
                        }
                    }
                }
            }
            case 'event' {
            }
            case 'accessed' {
            }
            case 'container' {
            }
            case 'original-date' {
            }
        }
    }


    #print STDERR Dumper %{$self->_var}; 
    #exit;

}


# add either prefix or suffix 
sub _addFix {
    my ($self, $ptr, $what) = @_;
    
    if(ref($ptr) eq 'HASH') {
        if($what eq 'prefix') {
            if(exists $ptr->{prefix}) {
                print "Adding prefix '$ptr->{prefix}'\n" if($self->{verbose});
                #print Dumper $ptr;
                $self->{_result} .= $ptr->{prefix}; 
                #$self->_checkIntegrityOfFix($ptr->{prefix});
            }
        }
        elsif($what eq 'suffix') {
            if(exists $ptr->{suffix}) {
                my $l = length($ptr->{suffix});
                my $l_str = substr $self->{_result}, (0-$l);
                print "end of _result: $l_str\n" if($self->{verbose});
                if($ptr->{suffix} ne $l_str) {
                    #print Dumper $ptr;
                    print "Adding suffix '$ptr->{suffix}'\n" if($self->{verbose});                    
                    $self->{_result} .= $ptr->{suffix};
                }
            }
        }
        elsif($what eq 'quoteOpen') {
            if(exists $ptr->{quotes}) {
                print "Adding quoteOpen \x{0201C}\n" if($self->{verbose});
                $self->{_result} .= "\x{0201C}";
            }
        }
        elsif($what eq 'quoteClose') {
            if(exists $ptr->{quotes}) {
                print "Adding quoteClose \x{0201D}\n" if($self->{verbose});
                $self->{_result} .= "\x{0201D}";
            }
        }
        else {
            die "ERROR: '$what' is not a valid fix, choose prefix|suffix|quoteOpen|quoteClose, please!";
        }
    }
}


# parses relevant major CSL elements while generating the bibliography
sub _parseChildElements {
    my ($self, $mods, $ptr, $from) = @_;
    
    print "_parseChildElements from=$from\n" if($self->{verbose});
    
    # prefix before the tmp copy!
    $self->_addFix($ptr, 'prefix');
    $self->_addFix($ptr, 'quoteOpen');
    
    # copy to be able to recognise changes;
    my $tmpStr = $self->{_result};    

    my @order;
    if(ref($ptr) eq "HASH") {        
        if(exists $ptr->{'/order'}) {
            #@order = _uniqueArray(\@{$ptr->{'/order'}});
            @order = $self->_getMap(\@{$ptr->{'/order'}});
        }
        else {
            my @tmp = keys %{$ptr};
            @order = $self->_getMap(\@tmp);
        }
    }
    elsif(ref($ptr) eq "ARRAY") {
        foreach my $k (@$ptr) {
            $self->_parseChildElements($mods, $k, $from);
        }
    }
    else {
        die "ERROR: '$ptr', ref=".(ref($ptr))." is neither hash nor array!";
    }
    
    # needed for if|else-if|else
    my $goOn = 1;  # do we go on?
    
    foreach my $element (@order) {
        if(ref($ptr->{$element->{'name'}}) eq 'ARRAY' && $element->{'name'} ne 'date-part') {
            $self->_parseChildElements($mods, ${$ptr->{$element->{'name'}}}[$element->{'pos'}], "parseChildElement(".$element->{'name'}.")");
        }
        else {
            my $o = $element->{'name'};
            print ">$o<\n" if($self->{verbose});
            switch($o) {
                ###################################################
                # cause of speed and to avoid printing the warn-msg            
                case '/order' { 
                }
                case '/nodes' { 
                }
                case 'name' { 
                }
                case 'text-case' {
                }
                case 'sort' { # nothing todo
                }
                case 'form' {                
                }
                case 'font-weight' {
                }
                case 'font-style' {
                }
                case 'quotes' {
                }
                case 'delimiter' {
                }
                # because of nested macros
                case 'macro' { 
                    $self->_parseMacro($mods, $ptr->{$o});
                }# now all what is directly given by the CSL-standard
                case 'names' {
                    $self->_parseNames($mods, $ptr->{$o});
                }
                case 'date' {
                    #$self->_parseChildElements($mods, $ptr->{$o},"_parseChildElements($o)");
                    print Dumper $ptr->{$o} if($self->{verbose});
                    $self->_addFix($ptr->{$o}, "prefix");
                    $self->_parseDatePart($mods, $ptr->{$o}->{'date-part'});
                    $self->_addFix($ptr->{$o}, "suffix");
                    
                }
                case 'label' {
                    $self->_parseLabel($mods, $ptr->{$o});
                }
                case 'text' {
                    $self->_parseChildElements($mods, $ptr->{$o}, "_parseChildElements($o)");
                }
                case 'choose' {
                    $self->_parseChoose($mods, $ptr->{$o});
                }            
                case 'group' {
                    $self->_parseGroup($mods, $ptr->{$o});
                }
                # additional non-top-level elements
                case 'variable' {       
                    $self->_parseVariable($mods, $ptr, $o);
                }
                case 'prefix' { # not here, we do it above (=front)
                }
                case 'suffix' { # not here, we do it below (=end)
                }
                case 'date-part' {
                    #$self->_parseDatePart($mods, $ptr->{$o});
                }
                case 'if' {
                    $goOn = $self->_parseIf_elseIf_else($mods, $ptr->{$o}, $goOn, $o);
                }
                case 'else-if' {
                    $goOn = $self->_parseIf_elseIf_else($mods, $ptr->{$o}, $goOn, $o);
                }
                case 'else' {
                    $goOn = $self->_parseIf_elseIf_else($mods, $ptr->{$o}, $goOn, $o);
                }
                else {
                   print STDERR "Warning ($from): '$o' not implemented, yet!\n" if($self->{verbose});
                }
            }
        }
        
        if(isNoStopWord($element->{'name'})) {
            # group delimiter
            if($self->{_group}->{'inGroup'}==1 && $self->{_group}->{'delimiter'} ne '') {
                if($tmpStr ne $self->{_result} && $self->{_result} !~ /$self->{_group}->{'delimiter'}$/) {
                    print "adding delimiter ($from) '".$self->{_group}->{'delimiter'}."'\n" if($self->{verbose});
                    $self->{_result} .= $self->{_group}->{'delimiter'};
                }
            }
        }
                
        print "### _parseChildElements(".$element->{'name'}."): _result string after parsing ".$element->{'name'}.": '$self->{_result}'\n" if($self->{verbose});
    }
     
    my $removedPrefix = 0;
    if($tmpStr eq $self->{_result}) {
        print "should remove prefix!\n" if($self->{verbose});
        # remove potential prefix cause the _result string hasn't changed, we don't need the prefix if there is nothing new
        if(ref($ptr) eq "HASH") {        
            if(exists $ptr->{prefix}) {  
                print "removing prefix '".$ptr->{prefix}."'\n" if($self->{verbose});
                my $substr = substr $self->{_result}, 0, length($self->{_result})-length($ptr->{prefix});
                $self->{_result} = $substr;
            }
        }
        $removedPrefix = 1;
    }
        
    # suffixes finish strings
    # but we need them only in that cases where we did not remove a prefix.
    if(! $removedPrefix) {
        $self->_addFix($ptr, "suffix");
        $self->_addFix($ptr, "quoteClose");
    }

}


sub _parseMacro {
    my ($self, $mods, $macro_name) = @_;
    
    my $macro = $self->_c->{style}->{macro}('name','eq',$macro_name)->pointer;
    
    print "_parseMacro: $macro_name\n" if($self->{verbose});
    #print Dumper $macro;
    
    if($self->{_sortInfo}->{_withinSorting}==1) {
        $self->{_sortInfo}->{_curKeyElement} = 'macro';
        $self->{_sortInfo}->{_curKeyName}    = $macro_name;
        #print STDERR Dumper $self->{_sortInfo};
    }
    
    $self->_parseChildElements($mods, $macro, "_parseMacro($macro_name)");
}


sub _parseLabel {
    my ($self, $mods, $l) = @_;
    
    print "_parseLabel\n" if($self->{verbose});
    
    if(exists $l->{variable}) {
        if($l->{variable} eq 'page') {
            if($self->_var->{'page'} =~ /(\d+)\-(\d+)/) {
                $self->{_result} .= "pp. ";
            }
            elsif($self->_var->{'page'} =~ /^(\d+)$/) {
                $self->{_result} .= "p. ";
            }
        }
    }
}
    

sub _parseNames {
    my ($self, $mods, $namesPtr) = @_;
    
    print "_parseNames\n" if($self->{verbose});
    #print Dumper $namesPtr;
    
    if(exists $namesPtr->{variable}) {
        # remind set variables
        # print "reminding variable ", $namesPtr->{variable}, "\n";
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
                $self->_parseNameAuthor($mods, $namesPtr->{name});
            }
            case 'editor' {
                #print "_parseEditor TODO\n";
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
    
    print "_parseNameAuthor\n" if($self->{verbose});
    
    if($self->{_sortInfo}->{_withinSorting}==1) {
        if($mods->{name}) {
            my $string = "";
            foreach my $n ( $mods->{name}->('@') ) {
                # add family name
                $string .= $n->{namePart}('type', 'eq', 'family')." ";
                my @given_names = $n->{namePart}('type', 'eq', 'given');
                # add given names
                foreach my $gn (@given_names) {
                    $string .= $gn." ";
                }
                $self->{_sort}->{$self->{_sortInfo}->{_keyNumber}}->{$self->{_sortInfo}->{_curKeyElement}}->{$self->{_sortInfo}->{_curKeyName}}->{$self->{_biblioNumber}}=$string;
            }
        }
    }
    else {    
        if($mods->{name}) {
            #print Dumper $mods->{name};
            my @names = $mods->{name}->('@');
            my $qtNames = scalar(@names);
            my $round = $qtNames;

            my ($et_al_min , $et_al_use_first, $sort_separator, $initialize_with, $name_as_sort_order) = (0, 0, "", "", "");
            
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
                        
            # set sort_separator
            $sort_separator = $name->{'sort-separator'} if(exists $name->{'sort-separator'});
                    
            # set initialize_with
            $initialize_with = $name->{'initialize-with'} if(exists $name->{'initialize-with'});
            $initialize_with =~ s/\s+$//g; # remove endstanding spaces
            
            # set name_as_sort_order
            $name_as_sort_order = $name->{'name-as-sort-order'} if(exists $name->{'name-as-sort-order'});
            
            print "et_al_min=".$et_al_min.", et-al-use-first=".$et_al_use_first." sort_separator='$sort_separator' initialize_with='$initialize_with' name_as_sort_order='$name_as_sort_order' qtNames='$qtNames' round='$round'\n" if($self->{verbose});            
            
            # print the names
            my $i=0;
            foreach my $n ( @names ) {
                #print Dumper $n->pointer; exit;
                $i++;
                my $complete_name = "";
                my @nameParts = ();
                
                # either not enough for et-al or we use the first authors until we reach $et_al_use_first, or we do not have et-al option
                if($qtNames < $et_al_min || (($qtNames >= $et_al_min) && ($qtNames-$round)<$et_al_use_first) || ($et_al_min==0 && $et_al_use_first==0)) {
                    my $family_name = $n->{namePart}('type', 'eq', 'family');
                    my @given_names = $n->{namePart}('type', 'eq', 'given');    

                    # prepare nameParts
                    foreach my $gn (@given_names) {
                        @nameParts = split /\s+/, $gn;
                        push @nameParts, $gn if(scalar(@nameParts)==0);
                    }

                    if($initialize_with ne '') {
                        for(my $j=0; $j<=$#nameParts; $j++) { # shorten each name part to its initial and add the respective char, e.g. Dominic -> D.
                            if($nameParts[$j] =~ /^(\S)/) {
                                $nameParts[$j] = uc($1).$initialize_with;
                                $nameParts[$j] =~ s/\s+$//g; # remove endstanding spaces                                
                            }
                        }
                    }
                    else {
                        for(my $j=0; $j<=$#nameParts; $j++) { # add endstanding space
                            $nameParts[$j] .= " ";
                        }
                    }

                    if( (($i == 1 && $name_as_sort_order eq 'first') || $name_as_sort_order eq 'all') && $sort_separator ne '') {
                            # if this is the first author and name-as-sort="first"
                            # or if this is a subsequent author and name-as-sort="all"
                            # then the name gets inverted
                            
                            # zotero:
                            #authorStrings.push(lastName+(firstName ? child["@sort-separator"].toString()+firstName : ""));

                            $complete_name .= $family_name;
                            $complete_name .= $sort_separator if(@given_names>0);
                            for(my $j=0; $j<=$#nameParts; $j++) {
                                $complete_name .= $nameParts[$j];
                            }
                            $complete_name =~ s/\s+$//g; # remove endstanding spaces
                    } else {
                            # zotero:
                            #authorStrings.push((firstName ? firstName+" " : "")+lastName);
                            
                            for(my $j=0; $j<=$#nameParts; $j++) {
                                $complete_name .= $nameParts[$j];
                            }
                            $complete_name .= " " if(scalar(@given_names)>0);
                            $complete_name .= $family_name;
                    }
                   
                    if(exists $name->{'delimiter-precedes-last'}) {
                        if($name->{'delimiter-precedes-last'} eq 'always') {
                            if($round>1) {
                                $complete_name .= $name->{delimiter} if(exists $name->{delimiter});
                                
                            }
                        }
                        elsif($name->{'delimiter-precedes-last'} eq 'never') {
                            if($round>2 && $qtNames < $et_al_min) {
                                $complete_name .= $name->{delimiter} if(exists $name->{delimiter});
                            }
                        }
                        else { # attribute exists but the given phrase is not supported
                        }
                    }
                    else {
                        $complete_name .= $name->{delimiter} if(exists $name->{delimiter});
                    }
                    
                    # add the AND 
                    my $and = "";
                    if($name->{and} eq "text" ) {
                        $and = " and ";
                    }
                    elsif($name->{and} eq "symbol" ) {
                        $and = " & ";
                    }
                    
                    if($round==2 && ($qtNames < $et_al_min || $et_al_min<=0) ) {
                        # $qtNames < $et_al_min means that we only add the AND if we do not have the ET-AL
                        $complete_name .= $and;
                    }
                }
                
                $round--;
                
                #print $complete_name;
                $self->{_result} .= $complete_name; # add the name to the biblio result-string
            }
            
            # add "et al." string
            if($et_al_min>0 && $qtNames>=$et_al_min) {
                print "adding 'et al'\n" if($self->{verbose});
                
                # ensure that there is a space before the ET-ALL
                if($self->{_result} !~ / $/) {
                    $self->{_result} .= " ";
                }
                
                $self->{_result} .= 'et al'; # TODO: 'et al' OR 'et al.'? (with or without dot?)
            }
        }
    }
}

sub _parseDatePart {
    my ($self, $mods, $dp) = @_;
    
    print "_parseDatePart\n" if($self->{verbose});
    
    my @d = split /\//, $self->_var->{'issued'};
    if(scalar(@d)!=3) {
        die "ERROR: Couldn't split CSL-variable issued!";
    }

    my $datePartString = "";
    if($self->_var->{'issued'} ne '') {
        if(ref($dp) eq "HASH") {            
            if(exists $dp->{name}) {
                switch($dp->{name}) { # month | day | year-other
                    case "month" { # 1. 
                        if($d[1] ne '-') {
                            if(exists $dp->{form}) {
                                switch($dp->{form}) {
                                    case "short" {
                                        $datePartString .= $1 if($self->{_monthStrings}->{$d[1]} =~ /^(\S\S\S)/);                                    
                                    }
                                    case "long" {
                                        
                                    }
                                    else {
                                        die "ERROR: The CSL-attribute style->bibliography->layout->date->date-part->form eq '".($dp->{form})."' is not implemented, yet.";
                                    }
                                }
                            }
                            else {
                                $datePartString .= $self->{_monthStrings}->{$d[1]};
                            }
                        }
                    }
                    case "day" { # 2.
                        $datePartString .= $d[2] if($d[2] ne '-');
                    }
                    case "year" { # 3.1
                        # now we have the long year, e.g. 2000.
                        # perhaps we have to shorten it                    
                        if(exists $dp->{form}) {
                            switch($dp->{form}) {
                                case "short" {
                                    $d[0] = $1 if($d[0] =~ /\d\d(\d\d)/);                                    
                                }
                                case "long" {
                                    
                                }
                                else {
                                    die "ERROR: The CSL-attribute style->bibliography->layout->date->date-part->form eq '".($dp->{form})."' is not implemented, yet.";
                                }
                            }
                        }
                        
                        # the year is ready, add it 
                        $datePartString .= $d[0];
                        
                    }
                    case "other" { # 3.2
                        
                    }
                    else {
                        die "ERROR: The CSL-attribute style->bibliography->layout->date->date-part->name eq '".($dp->{'date-part'}->{name})."' is not implemented, yet.";
                    }
                }
                
                if($datePartString ne '') {
                    $self->_addFix($dp, "prefix");
                    $self->{_result} .= $datePartString;
                    $self->_addFix($dp, "suffix");
                }
            }
            
            
        }
        elsif(ref($dp) eq "ARRAY") {
            foreach my $thisDp (@$dp) {
                $self->_parseDatePart($mods, $thisDp);
                #$self->_parseChildElements($mods, $thisDp,"_parseDatePart");
            }
        }
        else {
            die "ERROR: Date-part is neither hash nor array?";
        }
    }
}


sub _parseChoose {
    my ($self, $mods, $choosePtr) = @_;
    
    print "_parseChoose\n" if($self->{verbose});
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
            $self->_parseChoose($mods, $c);
            #print "leaving choose\n";
        }
    }
    else {
        die "ChoosePtr is neither a hash nor an array?";
    }
    
    my $goOn = 1;  # do we go on?
    foreach my $o (@order) {
        print "-- $o --\n"  if($self->{verbose});
        if( $o eq 'if' || $o eq 'else-if') {
            print "if or else-if goOn=$goOn\n" if($self->{verbose});
            $goOn = $self->_parseIf_elseIf_else($mods, $choosePtr->{$o}, $goOn, $o);
            print "goOn=$goOn after parsing if or else-if\n" if($self->{verbose});
        }
        elsif($o eq 'else') { 
            print "else goOn=$goOn\n" if($self->{verbose});
            $goOn = $self->_parseIf_elseIf_else($mods, $choosePtr->{$o}, $goOn, $o);
            print "goOn=$goOn after parsing else\n" if($self->{verbose});
        }
        else {
            #print "Warning: Should I reach this?";
        }
    }
    
    print "leaving choose\n" if($self->{verbose});
}

# TODO: check that really ALL-NEXT-NODES get parsed, not only the first of the next ones.
sub _parseIf_elseIf_else {
    my ($self, $mods, $ptr, $goOn, $what) = @_;
    
    if($goOn==1) {
        print "checking $what\n" if($self->{verbose});
        if($what eq 'if' or $what eq 'else-if') {
            if($self->_checkCondition($mods, $ptr)==1) {
                print "within the if or else-if statement, what=$what\n" if($self->{verbose});
                $self->_processSubgroupNoStopWords($mods, $ptr);
            }
            else {
                return 1; #goOn
            }
        }
        else { # the else-statement
            print "within the else statement, what=$what\n" if($self->{verbose});
            #$self->_processSubgroupNoStopWords($mods, $ptr);
            $self->_parseChildElements($mods, $ptr, "_parseIf_elseIf_else($what)");
        }
    }
    
    print "leaving parseIf_elseIf_else\n" if($self->{verbose});
    
    return 0; # goOn=0 because we went into either if|else-if|else
}

sub _processSubgroupNoStopWords {
    my ($self, $mods, $condiPtr) = @_;

    print "_processSubgroupNoStopWords\n" if($self->{verbose});
    #print Dumper $condiPtr;

    my @order;
    if(ref($condiPtr) eq "HASH") {
        if(exists $condiPtr->{'/order'}) {
            @order = _uniqueArray(\@{$condiPtr->{'/order'}});
        }
        else {
            @order = keys %$condiPtr;
        }
    }
    elsif(ref($condiPtr) eq "ARRAY") {
        foreach my $c (@{$condiPtr}) {
            $self->_processSubgroupNoStopWords($mods, $c);
            #$self->_parseChildElements($mods, $condiPtr->{$o}, "_processSubgroup($o)");
        }
    }
    else {
        die "CondiPtr '$condiPtr' is neither a hash nor an array? (It is ".(ref($condiPtr)).")";
    }

    foreach my $o (@order) {        
        switch($o) {# for each subcondition
            case 'type' {
            }
            case 'variable' {
            }
            case 'is_numeric' {
            }
            case 'is_date' {
            }
            case 'position' {
            }
            case 'disambiguate' {
            }
            case 'locator' {
            }
            case 'match' {
            }
            # other stop words
            case '/nodes' {
            }
            else {
                if($o  ne '') {
                    print "proceed with $o\n" if($self->{verbose});
                    #print Dumper $condiPtr->{$o};
                    $self->_parseChildElements($mods, $condiPtr->{$o}, "_processSubgroupNoStopWords($o)");
                }
            }
        }
    }
}

# returns 1 when condition is true otherwise 0
sub _checkCondition {
    my ($self, $mods, $condiPtr) = @_;
    
    print "_checkCondition\n" if($self->{verbose});
    #print Dumper $condiPtr;

    my @order;
    if(ref($condiPtr) eq "HASH") {
        if(exists $condiPtr->{'/order'}) {
            @order = _uniqueArray(\@{$condiPtr->{'/order'}});
        }
        else {
            #die "ERROR: Condition has no /order or /nodes entry?";
            @order = keys %$condiPtr;
        }
    }
    elsif(ref($condiPtr) eq "ARRAY") {
        foreach my $c (@{$condiPtr}) {
            $self->_checkCondition($mods, $c);
        }
    }
    else {
        die "CondiPtr is neither a hash nor an array?";
    }

    my $truth = 0; # increment if subcondition is true
    my $qtSubconditions = 0;
    my $match = "";
    foreach my $o (@order) { 
        switch($o) {# for each subcondition
            print "searching subcondition: $o\n" if($self->{verbose});
            case 'type' {
                $truth += $self->_checkType($mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'variable' {
                $truth += $self->_checkVariable($mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'is_numeric' {
                $truth += $self->_checkIsNumeric($mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'is_date' {
                $truth += $self->_checkIsDate($mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'position' {
                $truth += $self->_checkPosition($mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'disambiguate' {
                $truth += $self->_checkDisambiguate($mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'locator' {
                $truth += $self->_checkLocator($mods, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'match' {
                $match = $condiPtr->{match};
            }
        }
    }
    
    if($qtSubconditions>0) {
        switch($match) {
            print "truth=$truth qtSubconditions=$qtSubconditions match='$match'\n" if($self->{verbose});
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
    }
    
    return 0;
}



# check if the current mods is of the respective type
# returns 1 if the check was positive else 0
sub _checkType {
    my ($self, $mods, $type) = @_;

    print "_checkType: $type\n" if($self->{verbose});

    my %alias=( 
        'academic journal' => 'article-journal',
        'journalArticle' => 'article-journal',
    );

    # $type can store multiple types
    my @types = split / /, $type;
    my $ret = 0;
    # check if at least one type fits
    foreach my $t (@types) {
        # if it is the same, we take it right-away  
        if ($mods->{genre} eq $t) {
            $ret = 1;
        } 
        else {
            # We look if we can match an alias, if not return 0
            if ($alias{$mods->{genre}}) {
                $ret = 1 if($alias{$mods->{genre}} eq $t);
            } 
            else {
                $ret = 0;
            }
        }
    }
    return $ret;
}

sub _checkVariable {
    my ($self, $mods, $v) = @_;
    
    print "_checkVariable: $v\n" if($self->{verbose});
    
    my @s = split / /, $v;
    foreach my $entry (@s) {
        if(exists ${$self->{_var}}{$entry}) {
            if(${$self->{_var}}{$entry} ne '') {
                print "variable exists\n" if($self->{verbose});
                return 1;
            }
        }
    }
    
    print "variable is unknown\n" if($self->{verbose});
    return 0;
}

sub _checkIsNumeric {
    my ($self, $mods, $n) = @_;
    
    #print "_checkIsNumeric: TODO! $n\n";
    #TODO
    
    return 0;    
}

sub _checkIsDate {
    my ($self, $mods, $d) = @_;
    
    #print "_checkIsDate: TODO! $d\n";
    #TODO
    
    return 0;    
}

sub _checkPosition {
    my ($self, $mods, $p) = @_;
    
    #print "_checkPosition: TODO! $p\n";
    #TODO
    
    return 0;    
}

sub _checkDisambiguate {
    my ($self, $mods, $t) = @_;
    
    #print "_checkDisambiguate: TODO! $t\n";
    #TODO
    
    return 0;    
}

sub _checkLocator {
    my ($self, $mods, $l) = @_;
    
    #print "_checkLocator: TODO! $l\n";
    #TODO
    
    return 0;    
}

sub _getMap {
    my ($self, $array_ref) = @_;
    
    my @order;
    my %global_map;
    
    foreach my $a (@{$array_ref}) {
        my %map;
        
        if(! exists $global_map{$a}) {
            $global_map{$a} = 0;
        }
        else {
            $global_map{$a}++;
        }
                
        $map{'name'} = $a;
        $map{'pos'}  = $global_map{$a};
        
        push @order, \%map;            
    }
    
    return @order;
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
    my ($self, $mods, $g) = @_;

    print "_parseGroup\n" if($self->{verbose});
    $self->{_group}->{'inGroup'} = 1;

    if(ref($g) eq "HASH") {
        if(exists $g->{'delimiter'}) {
            $self->{_group}->{'delimiter'} = $g->{'delimiter'};
        }
    }
    
    $self->_parseChildElements($mods, $g, "_parseGroup(group)");

    # Here we leave the group.
    # Group-example: 1,2,3
    # if the third(last) group element does not contribute to the _result string
    # then we also do not need the delimiter at the second element.
    if($self->{_group}->{'delimiter'} ne '' && $self->{_result}=~/$self->{_group}->{'delimiter'}$/ ) {
        $self->{_result} = substr $self->{_result}, 0, length($self->{_result})-length($self->{_group}->{'delimiter'});
        #print STDERR "JA group (after removing): ", $self->{_result}, "\n";
    }
    else {
        #print STDERR "NEIN group: ", $self->{_result}, "\n";
    }
    
        
    # because we leave the group
    $self->{_group}->{'delimiter'} = '';
    $self->{_group}->{'size'} = 0; 
    $self->{_group}->{'inGroup'} = 0;
}

# variation of _processSubgroup
# useful to check if there is something left that we have to parse
# they only return 1 element, this one will be parsed, 
# but what if there are multiple elements after the condition, do we parse them all or just the single one that was returned?
sub isNoStopWord {
    my $word = shift;
    
    my %stop_words = (
        'type' => 1,
        'variable' => 1,
        'is_numeric' => 1,
        'is_date' => 1,
        'position' => 1,
        'disambiguate' => 1,
        'locator' => 1,
        'match' => 1,
        '/nodes' => 1,
        'delimiter' => 1,
        'label' => 1,
        'quotes' => 1
    );
    
    if(exists $stop_words{$word}) {
        return 0;
    }
    else {
        return 1;
    }
}

# add the variable to the biblio string
sub _parseVariable {
    my ($self, $mods, $ptr, $link) = @_;
    
    my $v = $ptr->{$link};
    
    if($self->{_sortInfo}->{_withinSorting}==1) {
        
    }
    else {
        # get putative options of the variable
        if(exists $ptr->{'form'}) {
            #print STDERR "Form:".Dumper $ptr->{'form'};
            $v.='_short'; # we want the short version of the variable
        }

        # do not print the issued variable, that is done within _parseDatePart 
        if($v ne "issued") {    
            print "_parseVariable: '$v'\n" if($self->{verbose});
            if(exists $self->_var->{$v}) {
                #print STDERR Dumper $self->_var;
                #print STDERR Dumper $self->_var->{$v};
                if($self->_var->{$v} ne '') {
                        $self->{_result} .= $self->_var->{$v};
                }
            }
            else {
                print STDERR "Warning: Variable '$v' is unknown, someone should implement it ;-)\n" if($self->{verbose});
            }
        }
    }
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
