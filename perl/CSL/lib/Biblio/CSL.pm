package Biblio::CSL;

use 5.010000;
use strict;
use warnings;
use Moose;
use XML::Smart;
use Switch;
#use Date::Components;
#use Date::Manip;
#use DateTime::Format::Natural;
#use DateTime::Format::Flexible;
use DateTimeX::Easy;


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

# hash that stores the variables
# key: name of variables
# value: content-string
has '_var' => (
    is       => 'rw',
    required => 0
);

# group settings
# getting active when entering group
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
    $self->_citationsSize($self->_setCitationsSize());
    $self->_biblioSize($self->_setBiblioSize());
    
    $self->{_group}->{'inGroup'} = 0;
    $self->{_group}->{'delimiter'} = '';

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

# do the transformation of the mods file given the csl style file
sub transform {
    my $self = shift;
    
    # handle citations
    if($self->getCitationsSize>0) {
        if($self->_c->{style}->{citation} ) {
            $self->_parseCitations();
        }
        else {
            die "ERROR: CSL-element 'citation' not available?";
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
sub _transformEach() {
    my ($self, $mods) = @_;
    
    if(exists $self->_c->{style}) {
        # here we only handle the bibliography, the citations have already been generated.
        if(exists $self->_c->{style}->{bibliography} ) {
            if(exists $self->_c->{style}->{bibliography}->{layout} ) {  
                # lets go
                $self->_updateVariables($mods->pointer);
                $self->_parseChildElements($mods, $self->_c->{style}->{bibliography}->{layout}->pointer, "transformEach(parsing layout)");
                
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

# cleans the old and store the current variables of the current mods
sub _updateVariables {
    my ($self, $mods) = @_;
    
    print "_updateVariables\n";
    
    %{$self->{_var}} = (); 
    %{$self->_var} = (
        'title' => '',
        'container-title' => '',
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
            case "title" {
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
                        #print Dumper $mods->{relatedItem}->{titleInfo};
                        my $r = ref($mods->{relatedItem}->{titleInfo});
                        if($r eq "HASH") {
                                $self->_setContainerTitle($mods, $mods->{relatedItem}->{titleInfo});                                
                        }
                        elsif($r eq "ARRAY") {
                            #print Dumper $mods->{relatedItem}->{titleInfo};
                            my @titles = @{$mods->{relatedItem}->{titleInfo}};
                            #print Dumper @titles;
                            foreach my $t (@titles) {
                                print Dumper $t;
                                $self->_setContainerTitle($mods, $t);
                            }
                        }
                        else {
                            die "ERROR: Container-title is neither hash nor array?";
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
            } 
            ##
            case 'DOI' {
                # TODO hash vs array?
                if(exists $mods->{identifier}) {
                    if(exists $mods->{identifier}->{type}) {
                        if($mods->{identifier}->{type} eq 'doi') {
                            $self->_var->{$k} = $mods->{identifier}->{'CONTENT'};
                            print STDERR $self->_var->{$k}, "\n";
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
                $self->{_biblioNumber}++;
                $self->_var->{'citation-number'} = $self->{_biblioNumber};
                
                # hardcoded space, some styles have a space at this point, others don't
                $self->_var->{'citation-number'} .= " " if($self->_var->{'citation-number'} !~ /\s$/);
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
                            
                            # Zotero outputs full month names
                            my %month = (
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
                            );
                                                        
                            my $keep = "";
                            # NAIVE APPROACH
                            # WE'LL KEEP THE DATE AS DAY/MONTH/YEAR
                            if($date =~ /^(\d\d\d\d)$/) { #simple year
                                $keep = "-/-/".$1;
                            }
                            elsif($date =~ /^(\S+) (\d\d\d\d)$/) { # month and year
                                if(exists $month{$1}) {
                                    $keep = "-/".$month{$1}."/".$2; # keep full name
                                }
                                else {
                                    $keep = "-/".$1."/".$2;
                                }
                            }
                            elsif($date =~ /^(\S+) (\d+), (\d\d\d\d)$/) { # month day, year
                                if(exists $month{$1}) {
                                    $keep = $2."/".$month{$1}."/".$3;
                                }
                                else {
                                    $keep = $2."/".$1."/".$3;
                                }
                            }
                            else {
                                die "ERROR: Wasn't able to parse the date '$date'?";
                            }
                            $self->_var->{'issued'} = $keep;
                            #print STDERR $keep, "\n";
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

sub _setContainerTitle {
    my ($self, $mods, $title) = @_; 
    
    #print Dumper $title;
    
    my $r = ref($title);
    #print "innen r=$r\n";
    
    if(exists $title->{title}) {
        if(! $r) { # its just the string and that is the order to get the container-title.
            print Dumper $title;
            $self->{_var}->{'container-title'} = $title->{title}->{CONTENT};
        }            
        elsif($r eq "HASH") {
            # short title?
            if(exists $title->{form}) {
                switch($title->{form}) {
                    case "short" {
                        $self->_var->{'container-title'} = $mods->{relatedItem}->{titleInfo}->('type','eq','abbreviated')->{title}->{CONTENT};
                    }
                    case "long" {                                    
                        $self->_var->{'container-title'} = $title->{title}->{CONTENT};
                    }
                    else {
                        die "ERROR: Unknown container-title form '".($title->{form})."'";
                    }
                }
            }
            else {
                $self->_var->{'container-title'} = $title->{title}->{CONTENT};
            }
        }
    }
}

# add either prefix or suffix 
sub _addFix {
    my ($self, $ptr, $what) = @_;
    
    if(ref($ptr) eq "HASH") {
        if($what eq "prefix") {
            if(exists $ptr->{prefix}) {
                print "Adding prefix '$ptr->{prefix}'\n";
                #print Dumper $ptr;
                $self->{_biblio_str} .= $ptr->{prefix}; 
                #$self->_checkIntegrityOfFix($ptr->{prefix});
            }
        }
        elsif($what eq "suffix") {     
            if(exists $ptr->{suffix}) {
                print "Adding suffix '$ptr->{suffix}'\n";
                #print Dumper $ptr;
                $self->{_biblio_str} .= $ptr->{suffix};
                #$self->_checkIntegrityOfFix($ptr->{suffix});
            }
        }
        else {
            die "ERROR: '$what' is not a valid fix, either prefix or suffix, please!";
        }
    }
}

# sometimes we ignore variables
# they are not written to the output
# but then we also don't need the fix!
# this is to ensure that we do not have double fixes and so on
#
### DON'T NEEDED ANYMORE 
#
#sub _checkIntegrityOfFix {
    #my ($self, $str) = @_;
    
    #if($self->{_biblio_str} =~ /\Q$str$str\E/) {        
    #    print "matching (str='$str$str'): ", $self->{_biblio_str}, "\n";
    #    $self->{_biblio_str} =~ s/$str$str$/$str/g;
    #    print "after: ", $self->{_biblio_str}, "\n";
    #}
    
#}

# parses relevant major CSL elements while generating the bibliography
sub _parseChildElements {
    my ($self, $mods, $ptr, $from) = @_;
    
    $self->_addFix($ptr, "prefix");
    
    # copy to be able to recognise changes;
    my $tmpStr = $self->_biblio_str;
    
    #print Dumper $ptr;
    
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
            $self->_parseChildElements($mods, $k, $from);
        }
    }
    else {
        die "ERROR: $ptr is neither hash nor array!";
    }
    
    # needed for if|else-if|else
    my $goOn = 1;  # do we go on?
    
    foreach my $o (@order) {
        print ">$o<\n";
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
            case 'sort' {                
            }
            # because of nested macros
            case 'macro' {
                $self->_parseMacro($mods, $ptr->{$o});
            }
            # now all what is directly given by the CSL-standard
            case 'names' {
                $self->_parseNames($mods, $ptr->{$o});
            }
            case 'date' {
                $self->_parseChildElements($mods, $ptr->{$o},"_parseChildElements($o)");
            }
            case 'label' {
                $self->_parseLabel($mods, $ptr->{$o});
            }
            case 'text' {
                print 'parsing text!!!\n';
                $self->_parseChildElements($mods, $ptr->{$o}, "_parseChildElements($o)");
            }
            case 'choose' {
                $self->_parseChoose($mods, $ptr->{$o});
                print "leaving choose\n";
            }            
            case 'group' {
                $self->_parseGroup($mods, $ptr->{$o});
            }
            # additional non-top-level elements
            case 'variable' {
                $self->_parseVariable($mods, $ptr->{$o});
            }
            case 'prefix' { # not here, we do it above (=front)
            }
            case 'suffix' { # not here, we do it below (=end)
            }
            case 'date-part' {
                $self->_parseDatePart($mods, $ptr->{$o});
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
               print "Warning ($from): '$o' not implemented, yet!\n";
            }
        }
        
        print "### _parseChildElements($o): _biblio_string after parsing $o: '$self->{_biblio_str}'\n";
    }
    
    my $removedPrefix = 0;
    if($tmpStr eq $self->_biblio_str) {
        # remove potential prefix cause the biblio_string hasn't changed, we don't need the prefix if there is nothing new
        if(ref($ptr) eq "HASH") {
            if(exists $ptr->{prefix}) {
                #print STDERR "vor : '$self->{_biblio_str}'\n";
                print "removing prefix '".$ptr->{prefix}."'\n";
                my $substr = substr $self->{_biblio_str}, 0, length($self->{_biblio_str})-length($ptr->{prefix});
                $self->{_biblio_str} = $substr;
                $removedPrefix = 1;
                #print STDERR "nach: '$self->{_biblio_str}'\n";
                #if($self->{_biblio_str} =~ /\Q$p\E$/) {
                #    $self->{_biblio_str} =~ s/$p//g;
                #}
            }
        }
    }
    
    # group delimiter
    if($tmpStr ne $self->_biblio_str && $self->{_group}->{'inGroup'} ==1 && $self->{_group}->{'delimiter'} ne '' ) {
        $self->{_biblio_str} .= $self->{_group}->{'delimiter'};
    }

    # suffixes finish strings
    # but we need them only in that cases where we did not remove a prefix.
    $self->_addFix($ptr, "suffix") if(! $removedPrefix);
}


sub _parseMacro {
    my ($self, $mods, $macro_name) = @_;
    
    my $macro = $self->_c->{style}->{macro}('name','eq',$macro_name)->pointer;
    
    print "_parseMacro: $macro_name\n";
    print Dumper $macro;
    
    $self->_parseChildElements($mods, $macro, "_parseMacro($macro_name)");
}


sub _parseLabel {
    my ($self, $mods, $l) = @_;
        # TODO
}
    

sub _parseNames {
    my ($self, $mods, $namesPtr) = @_;
    
    print "_parseNames\n";
    print Dumper $namesPtr;
    
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
                print "_parseEditor TODO\n";
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
    
    my @d = split /\//, $self->_var->{'issued'};
    if(scalar(@d)!=3) {
        die "ERROR: Couldn't split SL-variable issued!";
    }

    my $datePartString = "";
    if($self->_var->{'issued'} ne '') {
        if(ref($dp) eq "HASH") {
            
            if(exists $dp->{name}) {
                switch($dp->{name}) { # month | day | year-other
                    case "month" { # 1.                        
                        $datePartString .= $d[1] if($d[1] ne '-');
                    }
                    case "day" { # 2.
                        $datePartString .= $d[0] if($d[0] ne '-');
                    }
                    case "year" { # 3.1
                        # now we have the long year, e.g. 2000.
                        # perhaps we have to shorten it                    
                        if(exists $dp->{form}) {
                            switch($dp->{form}) {
                                case "short" {
                                    $d[2] = $1 if($d[2] =~ /\d\d(\d\d)/);                                    
                                }
                                case "long" {
                                    
                                }
                                else {
                                    die "ERROR: The CSL-attribute style->bibliography->layout->date->date-part->form eq '".($dp->{form})."' is not implemented, yet.";
                                }
                            }
                        }
                        
                        # the year is ready, add it 
                        $datePartString .= $d[2];
                        
                    }
                    case "other" { # 3.2
                        
                    }
                    else {
                        die "ERROR: The CSL-attribute style->bibliography->layout->date->date-part->name eq '".($dp->{'date-part'}->{name})."' is not implemented, yet.";
                    }
                }
                
                if($datePartString ne '') {
                    $self->_addFix($dp, "prefix");
                    $self->{_biblio_str} .= $datePartString;
                    $self->_addFix($dp, "suffix");
                }
            }
            
            
        }
        elsif(ref($dp) eq "ARRAY") {
            foreach my $dp (@$dp) {
                $self->_parseDatePart($mods, $dp);
            }
        }
        else {
            die "ERROR: Date-part is neither hash nor array?";
        }
    }
}


sub _parseChoose {
    my ($self, $mods, $choosePtr) = @_;
    
    print "_parseChoose\n";
    print Dumper $choosePtr;
    
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
            print "leaving choose\n";
        }
    }
    else {
        die "ChoosePtr is neither a hash nor an array?";
    }
    
    my $goOn = 1;  # do we go on?
    foreach my $o (@order) {
        print "-- $o --\n";
        if( $o eq 'if' || $o eq 'else-if') {
            $goOn = $self->_parseIf_elseIf_else($mods, $choosePtr->{$o}, $goOn, $o);
        }
        elsif($o eq 'else') { 
            print "else goOn=$goOn\n";
            $goOn = $self->_parseIf_elseIf_else($mods, $choosePtr->{$o}, $goOn, $o);
        }
        else {
            print "Warning: Should I reach this?";
        }
    }
    
    print "leaving end of choose\n";
}

sub _parseIf_elseIf_else {
    my ($self, $mods, $ptr, $goOn, $what) = @_;
    
    if($goOn==1) {
        print "within $what\n";
        if($what eq 'if' or $what eq 'else-if') {
            if($self->_checkCondition($mods, $ptr)==1) {
                my $next = $self->_howToProceedAfterCondition($ptr);
                print "next after $what = '$next'\n";
                if($next ne "") {
                    $self->_parseChildElements($mods, $ptr->{$next}, "_parseConditionContent($what)");
                }
            }
            else {
                print "false!\n";
                return 1; #goOn
            }
        }
        else { # the else-statement
            print "\n";
            my $next = $self->_howToProceedAfterCondition($ptr);
            print "next after $what = '$next'\n";
            if($next ne "") {
                $self->_parseChildElements($mods, $ptr->{$next}, "_parseConditionContent($what)");
            }
        }
    }
    
    print "leaving parseIf_elseIf_else\n";
    
    return 0; # goOn=0 because we went into either if|else-if|else
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

    my $truth = 0; # increment if subcondiion is true
    my $qtSubconditions = 0;
    my $match = "";
    foreach my $o (@order) { 
        switch($o) {# for each subcondition
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


sub _howToProceedAfterCondition {
    my ($self, $condiPtr) = @_;

    print "_howToProceedAfterCondition\n";

    my @order;
    if(ref($condiPtr) eq "HASH") {
        if(exists $condiPtr->{'/order'}) {
            @order = _uniqueArray(\@{$condiPtr->{'/order'}});
        }
        else {
            @order = keys %$condiPtr;
        }
    }
    #elsif(ref($condiPtr) eq "ARRAY") {
    #    foreach my $c (@{$condiPtr}) {
    #        $self->_howToProceedAfterCondition($c);
    #    }
    #}
    else {
        die "CondiPtr is neither a hash nor an array?";
    }

    #print Dumper @order;

    foreach my $o (@order) {        
        switch($o) {# for each subcondition
            #print "o=", $o, "\n";
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
            case 'delimiter' {
            }
            else {
                print "proceed with $o\n";
                return $o;
            }
        }
    }

    return "";
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
    
    print "_checkVariable: $v\n";
    
    my @s = split / /, $v;
    foreach my $entry (@s) {
        if(exists ${$self->{_var}}{$entry}) {
            if(${$self->{_var}}{$entry} ne '') {
                print "variable exists\n";
                return 1;
            }
        }
    }
    
    print "variable is unknown\n";
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
    my ($self, $mods, $g) = @_;

    print "_parseGroup\n";
    $self->{_group}->{'inGroup'} = 1;

    if(ref($g) eq "HASH") {
        if(exists $g->{'delimiter'}) {
            $self->{_group}->{'delimiter'} = $g->{'delimiter'};
        }
    }
    
    # do the group
    my $next = $self->_howToProceedAfterCondition($g);
    print "next after group = '$next'\n";
    $self->_parseChildElements($mods, $g->{$next}, "_parseConditionContent(group)");
    
    # remove last delimiter 
    # delimiter-example: e.g. ',': a,b,c
    my $substr = substr $self->{_biblio_str}, 0, length($self->{_biblio_str})-length($self->{_group}->{'delimiter'});
    $self->{_biblio_str} = $substr;
    
    # because we leave the group
    $self->{_group}->{'delimiter'} = '';
    $self->{_group}->{'inGroup'} = 0;    
}

# add the variable to the biblio string
sub _parseVariable {
    my ($self, $mods, $v) = @_;
    
    # do not print the issued variable, that is done within _parseDatePart 
    if($v ne "issued") {    
        print "_parseVariable: '$v'\n";
        if(exists $self->_var->{$v}) {
            #print STDERR Dumper $self->_var;
            #print STDERR Dumper $self->_var->{$v};
            if($self->_var->{$v} ne '') {
                $self->{_biblio_str} .= $self->_var->{$v};
            }
        }
        else {
            die "ERROR: Variable '$v' is unknown, someone should implement it ;-)";
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
