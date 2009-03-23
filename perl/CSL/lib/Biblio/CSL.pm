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
  trigger  => \&_format_set,
  required => 1
);

# sorted array of strings, 
# after transformation it contains the list of citations
my @_citations = (); # the actual container
has 'citation' => (
  is       => 'ro',
  isa      => 'ArrayRef[Str]',
  required => 0
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

# citation counter,  number of current citation
has '_citationNumber' => (
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
    
    $self->biblio(\@_biblio);
}

# trigger to check that the format is validly set to a supported type
sub _format_set {
  my ( $self, $format, $meta_attr ) = @_;

  if ( $format ne "txt" ) {
	die "ERROR: Unknwon output format\n";
  }
}

### class methods

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

    my $m = XML::Smart->new($self->get_mods);
    my $c = XML::Smart->new($self->get_csl);

    #print Dumper $m;
    #print Dumper $c;
    
    if($m->{modsCollection}) { # transform the complete collection
        foreach my $mods ($m->{modsCollection}->{mods}->('@')) {
            #print Dumper $mods;            
            transformEach($mods, $c, $self);
        }
    }
    else { # no collection, transform just a single mods        
        transformEach($m->{mods}, $c, $self);
    }
}


# parse a single mods entry
sub transformEach() {
    my ($mods, $c, $self) = @_;
    
    if($c->{style}) {
        if( $c->{style}->{bibliography} ) {
            if( $c->{style}->{bibliography}->{layout} ) {
                my @nodes = $c->{style}->{bibliography}->{layout}->nodes_keys();
                my @order = $c->{style}->{bibliography}->{layout}->order();

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
                    
                    switch( $c->{style}->{bibliography}->{layout}->{$o}->key() ) {
                        case "suffix" {
                            _layoutSuffix($mods, $c);
                        }
                        case "text" {
                            _layoutText($mods, $c, \%i, $o, $self);
                        }
                    
                        case "date" {
                            _layoutDate($mods, $c);
                        }
                        case "choose" {
                            _layoutChoose($mods, $c, $self);
                        }
                        else {
                            die "ERROR: The case CSL-attribute style->bibliography->layout eq '".($c->{style}->{bibliography}->{layout}->{$o}->key())."' is not implemented yet!";
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


# case $c->{style}->{bibliography}->{layout} eq suffix
sub _layoutSuffix {
    my ($mods, $c) = @_;
    # TODO
}


# case $c->{style}->{bibliography}->{layout} eq text
sub _layoutText {
    my ($mods, $c, $i, $o, $self) = @_;
                                             
    my $text = $c->{style}->{bibliography}->{layout}->{text}->[$i->{$o}]->pointer;
                        
    if(exists $text->{variable} && exists $text->{suffix} && $text->{variable} eq "citation-number") {
        $self->{_citationNumber}++;
        #print $self->_citationNumber, $text->{suffix};
        $self->{_biblio_str} .= $self->{_citationNumber}.$text->{suffix};
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
            my @options = $c->{style}->{bibliography}->{option}('@');
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
                    my $c_nameEQauthor = $c->{style}->{macro}('name','eq','author') ;
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
                        foreach my $gn (@given_names) {
                           $complete_name .= $gn;
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

# case $c->{style}->{bibliography}->{layout} eq date
sub _layoutDate {
    my ($mods, $c) = @_;
    # TODO
}

# case $c->{style}->{bibliography}->{layout} eq choose
sub _layoutChoose {
    my ($mods, $c, $self) = @_;
    
    my @options = $c->{style}->{bibliography}->{layout}->{choose}->nodes_keys();
    my $opt = $c->{style}->{bibliography}->{layout}->{choose}->pointer;
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
            #print Dumper $opt->{$o};
            if($opt->{$o}->{text}->{macro}) {
                #print "NACH\n";
                
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
                #my @order = $c->{style}->{bibliography}->{layout}->{choose}->{$o}->{group}->order();
                #print Dumper @order; exit;
                $self->{_biblio_str} .= _parseGroup($mods, $c, $self, $opt->{$o}->{group}, "", 0);
                
                
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
    my ($mods, $c, $self, $g, $groupStr, $elemNumber) = @_;
    
    #print Dumper $g;

    $groupStr .= $g->{'prefix'}  if(exists $g->{'prefix'});
    
    foreach my $k (@{$g->{'/order'}} ) {
        switch($k) { # formatting | delimiter | TODO:
            #print $k, "\n";
            case "delimiter" {
                
            }
            #case "prefix" { # already done before the loop
            #}
            #case "suffix" { # will be done after the loop
            #}
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
                $elemNumber++;
                if($elemNumber>1) { # not the first element
                    $groupStr .= $g->{'delimiter'} if($g->{'delimiter'});
                }
                if($g->{$k}->{variable}) {
                    $groupStr .= _parseVariable($mods, $c, $self, $g->{$k}->{variable});
                }
                
            }
            case "group" {
                
            }
        }        
    }
    
    $groupStr .= $g->{'suffix'} if(exists $g->{'suffix'});
    
    return $groupStr;
}



sub _parseVariable {
    my ($mods, $c, $self, $var) = @_;
    
    my $varString = "";
    
    switch($var) {
        ## the primary title for the cited item
        case "title" { 
        }
        ## the secondary title for the cited item; for a book chapter, this 
        ## would be a book title, for an article the journal title, etc.
        case "container-title" {
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
                           $varString = $mods->{relatedItem}->{part}->{extent}->{start}."-".$mods->{relatedItem}->{part}->{extent}->{end};
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
    
    return $varString;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# print the current version of the modul
sub version {
  print "This is XML::CSL version ", $VERSION, "\n";
}

1;
__END__
