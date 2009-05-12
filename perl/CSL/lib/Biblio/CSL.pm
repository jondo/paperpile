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

# integer that specifies the genre mode
# we have to keep a map of csl-genre descriptions vs several application specific MODS-genre names
# e.g. csl attribute article-journal:
# Zotero writes <genre authority="local">journalArticle</genre> 
# Paperpile writes <genre>academic journal</genre>
# therefore we need a map that holds the different descriptions (phrases)
# mode 1: paperpile 
# mode 2: zotero 
# lMode = language mode
# public variable
has 'lMode' => (
  is       => 'rw',
  isa      => 'Int',
  default  => 1, # = paperpile
  required => 0
);

# see lMode
# _lMap = language map
# key: mode -> csl_phrase
# value: phrase_in_projcets_dialect
has '_lMap' => (
  is       => 'rw',
  required => 0
);

# hash that stores the current set variables
# key: name of variables
# value: content-string
# whenever a variable is set, the name and the content of the variable is kept in the hash
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
    _set_lMap($self);
    # do we have a biblio entry for each citation and vice versa?
    #if($self->_citationsSize != $self->_biblioSize) {
    #    print STDERR  "Warning: the number of citations and the size of the bibliography differ, but should be equal.";
    #}
    
    #print Dumper $self->{_lMap}; exit;
}

# trigger to check that the format is validly set to a supported type
sub _set_format {
    my ($self, $format, $meta_attr) = @_;

    if ($format ne "txt") {
        die "ERROR: Unknown output format\n";
    }
}

# set and initialize the attribute _lMap
sub _set_lMap {
    my ($self) = @_;
    
    # paperpile
    
    $self->{_lMap}->{1}->{'article'}            = 'academic journal';
    $self->{_lMap}->{1}->{'article-magazine'}   = 'academic journal';
    $self->{_lMap}->{1}->{'article-newspaper'}  = 'academic journal';
    $self->{_lMap}->{1}->{'article-journal'}    = 'academic journal';
    $self->{_lMap}->{1}->{'bill'}               = 'bill';
    $self->{_lMap}->{1}->{'book'}               = 'book';
    $self->{_lMap}->{1}->{'broadcast'}          = 'broadcast';
    $self->{_lMap}->{1}->{'chapter'}            = 'chapter';
    $self->{_lMap}->{1}->{'entry'}              = 'entry';
    $self->{_lMap}->{1}->{'entry-dictionary'}   = 'entry-dictionary';
    $self->{_lMap}->{1}->{'entry-encyclopedia'} = 'entry-encyclopedia';
    $self->{_lMap}->{1}->{'figure'}             = 'figure';
    $self->{_lMap}->{1}->{'graphic'}            = 'graphic';
    $self->{_lMap}->{1}->{'interview'}          = 'interview';
    $self->{_lMap}->{1}->{'legislation'}        = 'legislation';
    $self->{_lMap}->{1}->{'legal_case'}         = 'legal_case';
    $self->{_lMap}->{1}->{'manuscript'}         = 'manuscript';
    $self->{_lMap}->{1}->{'map'}                = 'map';
    $self->{_lMap}->{1}->{'motion_picture'}     = 'motion_picture';
    $self->{_lMap}->{1}->{'musical_score'}      = 'musical_score';
    $self->{_lMap}->{1}->{'pamphlet'}           = 'pamphlet';
    $self->{_lMap}->{1}->{'paper-conference'}   = 'paper-conference';
    $self->{_lMap}->{1}->{'patent'}             = 'patent';
    $self->{_lMap}->{1}->{'post'}               = 'post';
    $self->{_lMap}->{1}->{'post-weblog'}        = 'post-weblog';
    $self->{_lMap}->{1}->{'personal_communication'} = 'personal_communication';
    $self->{_lMap}->{1}->{'report'}             = 'report';
    $self->{_lMap}->{1}->{'review'}             = 'review';
    $self->{_lMap}->{1}->{'review-book'}        = 'review-book';
    $self->{_lMap}->{1}->{'song'}               = 'song';
    $self->{_lMap}->{1}->{'speech'}             = 'speech';
    $self->{_lMap}->{1}->{'thesis'}             = 'thesis';
    $self->{_lMap}->{1}->{'treaty'}             = 'treaty';
    $self->{_lMap}->{1}->{'webpage'}            = 'webpage';
    
    
    # zotero
    $self->{_lMap}->{2}->{'article'}            = 'journalArticle';
    $self->{_lMap}->{2}->{'article-magazine'}   = 'journalArticle';
    $self->{_lMap}->{2}->{'article-newspaper'}  = 'journalArticle';
    $self->{_lMap}->{2}->{'article-journal'}    = 'journalArticle';
    $self->{_lMap}->{2}->{'bill'}               = 'bill';
    $self->{_lMap}->{2}->{'book'}               = 'book';
    $self->{_lMap}->{2}->{'broadcast'}          = 'broadcast';
    $self->{_lMap}->{2}->{'chapter'}            = 'chapter';
    $self->{_lMap}->{2}->{'entry'}              = 'entry';
    $self->{_lMap}->{2}->{'entry-dictionary'}   = 'entry-dictionary';
    $self->{_lMap}->{2}->{'entry-encyclopedia'} = 'entry-encyclopedia';
    $self->{_lMap}->{2}->{'figure'}             = 'figure';
    $self->{_lMap}->{2}->{'graphic'}            = 'graphic';
    $self->{_lMap}->{2}->{'interview'}          = 'interview';
    $self->{_lMap}->{2}->{'legislation'}        = 'legislation';
    $self->{_lMap}->{2}->{'legal_case'}         = 'legal_case';
    $self->{_lMap}->{2}->{'manuscript'}         = 'manuscript';
    $self->{_lMap}->{2}->{'map'}                = 'map';
    $self->{_lMap}->{2}->{'motion_picture'}     = 'motion_picture';
    $self->{_lMap}->{2}->{'musical_score'}      = 'musical_score';
    $self->{_lMap}->{2}->{'pamphlet'}           = 'pamphlet';
    $self->{_lMap}->{2}->{'paper-conference'}   = 'paper-conference';
    $self->{_lMap}->{2}->{'patent'}             = 'patent';
    $self->{_lMap}->{2}->{'post'}               = 'post';
    $self->{_lMap}->{2}->{'post-weblog'}        = 'post-weblog';
    $self->{_lMap}->{2}->{'personal_communication'} = 'personal_communication';
    $self->{_lMap}->{2}->{'report'}             = 'report';
    $self->{_lMap}->{2}->{'review'}             = 'review';
    $self->{_lMap}->{2}->{'review-book'}        = 'review-book';
    $self->{_lMap}->{2}->{'song'}               = 'song';
    $self->{_lMap}->{2}->{'speech'}             = 'speech';
    $self->{_lMap}->{2}->{'thesis'}             = 'thesis';
    $self->{_lMap}->{2}->{'treaty'}             = 'treaty';
    $self->{_lMap}->{2}->{'webpage'}            = 'webpage';
  
    #print Dumper $self->{_lMap};
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
            transformEach($mods, $self); # TODO: only 1 param: self, $mods or $mods->pointer???
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
        push @{$self->{citations}}, $ret_id; # store the citation
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
                            _parseText($mods, $self, $self->_c->{style}->{bibliography}->{layout}->{text}->[$i{$o}]->pointer);
                        }
                    
                        case "date" {
                            _parseDate($mods, $self, $self->_c->{style}->{bibliography}->{layout}->{date}->pointer);
                        }
                        case "choose" {
                            _parseChoose($mods, $self, $self->_c->{style}->{bibliography}->{layout}->{choose}->pointer);
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
        
        # the string is ready, add the current entry to the bibliography
        #push @_biblio, $self->{_biblio_str};
        push @{$self->{biblio}}, $self->{_biblio_str};
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
sub _parseText {
    my ($mods, $self, $text) = @_;

    print "_parseText\n";
    #print Dumper $text;

    if(ref($text) eq "HASH") {
        $self->{_biblio_str} .= $text->{prefix} if(exists $text->{prefix});

        foreach my $t (keys %$text) {
            switch($t) {
                case 'variable' {
                    _parseVariable($mods, $self, $text->{$t}, 0, "");
                }
                case 'macro' {
                    if($text->{$t}) {
                        _parseMacro($mods, $self, $text->{$t});
                    }
                    else {
                        die "ERROR: Can we have a macro without a name?";
                    }
                }
                else {
                }
            }
        }
        
        if(exists $text->{suffix}) {
            $self->{_biblio_str} .= $text->{suffix};
            #$self->{_biblio_str} =~ s/\.\.//g; #TODO: Maybe we need such a security check
        }
    }
    elsif(ref($text) eq "ARRAY") {
        foreach my $t (@{$text}) {
            _parseText($mods, $self, $t);
        }
    }
    else {
        die "ERROR: Text neither hash nor element?";
    }
}


sub _getOrder {
    my ($ptr, $description) = shift;
    

}

# parsing macros seems to be complicated
# the macro is called from somewhere
# and then the macro-code has to be executed.
# the macro is identified by its name
sub _parseMacro {
    my ($mods, $self, $macro_name) = @_;
    
    my $macro = $self->_c->{style}->{macro}('name','eq',$macro_name)->pointer;
    
    print "_parseMacro: $macro_name\n";
    #print Dumper $macro;
    
    my @order;
    if(ref($macro) eq "HASH") {
        if(exists $macro->{'/order'}) {
            @order = @{$macro->{'/order'}};
        }
        else {
            @order = keys %{$macro};
        }
    }
    elsif(ref($macro) eq "ARRAY") {
        foreach my $m (@{$macro}) {
            _parseMacro($mods, $self, $m);
        }
    }
    else {
        die "ERROR (_parseMacro): Pointer is neither a hash nor an array?";
    }
    #my @order = _getOrder($macro, "_parseMacro"); # that would be cool!
    
    # check the content of the macro
    foreach my $o (@order) {
    #foreach my $key (keys %$macro) {
        switch($o) {
            case '/order' { # cause of speed and to avoid printing the warn-msg
            }
            case '/nodes' { # cause of speed and to avoid printing the warn-msg
            }
            case 'name' { # cause of speed and to avoid printing the warn-msg
            }
            case 'names' {
                _parseNames($mods, $self, $macro->{$o});
            }
            case 'date' {
                _parseDate($mods, $self, $macro->{$o});
            }
            case 'choose' {
                _parseChoose($mods, $self, $macro->{$o});
            }
            case 'text' {
                _parseText($mods, $self, $macro->{$o});
            }
            case 'group' {
                _parseGroup($mods, $self, $macro->{$o});
            }            
            else {
               print "Warning (_parseMacro): '$o' not implemented, yet!\n";
            }
        }
    }
}


sub _parseNames {
    my ($mods, $self, $namesPtr) = @_;
    
    print "_parseNames\n";
    
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
                _parseNameAuthor($mods, $self, $namesPtr->{name});
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
    my($mods, $self, $name) = @_;
    
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

# case $self->_c->{style}->{bibliography}->{layout} eq date
sub _parseDate {
    my ($mods, $self, $date) = @_;
    
    print "_parseDate\n";
    
    if(ref($date) eq "HASH") {
        $self->{_biblio_str} .= $date->{prefix} if(exists $date->{prefix});
        
        _parseDatePart($mods, $self, $date->{'date-part'});
        
        $self->{_biblio_str} .= $date->{suffix} if(exists $date->{suffix});
    }
    elsif(ref($date) eq "ARRAY") {
        foreach my $d (@{$date}) {
            _parseDate($mods, $self, $d);
        }
    }
    else {
        die "ERROR: Date is neither hash nor array?";
    }        
}

sub _parseDatePart {
    my ($mods, $self, $dp) = @_;
    
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
            _parseDatePart($mods, $self, $dp);
        }
    }
    else {
        die "ERROR: Date-part is neither hash nor array?";
    }
}


sub _parseChoose {
    my ($mods, $self, $choosePtr) = @_;
    
    print "_parseChoose\n";
    #print Dumper $choosePtr;
    
    my @order;
    if(ref($choosePtr) eq "HASH") {
        if(exists $choosePtr->{'/order'}) {
            @order = @{$choosePtr->{'/order'}};
        }
        #elsif(exists $choosePtr->{'/nodes'}) {
        #    push @order, keys $choosePtr->{'/nodes'};
        #}
        else {
            #die "ERROR: Choose has no /order or /nodes entry?";
            @order = keys %$choosePtr;
        }
    }
    elsif(ref($choosePtr) eq "ARRAY") {
        foreach my $c (@{$choosePtr}) {
            _parseChoose($mods, $self, $c);
        }
    }
    else {
        die "ChoosePtr is neither a hash nor an array?";
    }
    # TODO: if, elsif, else needs to be implemented!
    
    foreach my $o (@order) {
        print "-- $o --\n";
        if( $o eq "if" && _checkCondition($mods, $self, $choosePtr->{$o})==1 ) {
            print "within if\n";
            _parseConditionContent($mods, $self, $choosePtr->{$o});
        }
        elsif($o eq "else-if" && _checkCondition($mods, $self, $choosePtr->{$o})==1) {
            print "within else-if\n";
            _parseConditionContent($mods, $self, $choosePtr->{$o});
        }
        elsif($o eq "else") { # no conditions just the else statement
            print "within else\n";
            _parseConditionContent($mods, $self, $choosePtr->{$o});
        }
    }    
}

sub _parseConditionContent {
    my ($mods, $self, $co) = @_;
    
    print "_parseConditionContent\n";
    
    my @innerorder;
    # do it ordered
    
    #print Dumper $co;
    
    if(ref($co) eq "HASH") {
        if(exists $co->{'/order'}) {
            @innerorder = @{$co->{'/order'}};
        }
        #elsif(exists $co->{'/nodes'}) {
        #    push @innerorder, $co->{'/nodes'};
        #}
        else {
            #die "ERROR: Choose has no /order or /nodes entry?";
            @innerorder = keys %$co;
        }
    }
    elsif(ref($co) eq "ARRAY") {
        foreach my $k (@$co) {
            _parseConditionContent($mods, $self, $k);
        }
    }
    else {
        die "ERROR: inner condition content $co is neither hash nor array!";
    }
    
    # parse it
    foreach my $io (@innerorder) {
        switch($io) {
            print "within condition: $io\n";
            case 'text' { # e.g. article title
                _parseText($mods, $self, $co->{$io})
            }
            case 'group' {
                # return value of elemNumber not important but necessary to keep the biblio_string intact.
                _parseGroup($mods, $self, $co->{$io}, 0);
            }
            case 'date' {
                _parseDate($mods, $self, $co->{$io});
            }
            case 'choose' {
                _parseChoose($mods, $self, $co->{$io});
            }
            case 'variable' {
                _parseVariable($mods, $self, $co->{$io});
            }
            else {
                #print $io, "\n";
            }
        }
    }
}


# returns 1 when condition is true otherwise 0
sub _checkCondition {
    my ($mods, $self, $condiPtr) = @_;
    
    #print Dumper $condiPtr;

    print " - check condition - \n";

    my @order;
    if(ref($condiPtr) eq "HASH") {
        if(exists $condiPtr->{'/order'}) {
            @order = @{$condiPtr->{'/order'}};
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
            _checkCondition($mods, $self, $c);
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
                $truth += _checkType($mods, $self, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'variable' {
                $truth += _checkVariable($mods, $self, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'is_numeric' {
                $truth += _checkIsNumeric($mods, $self, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'is_date' {
                $truth += _checkIsDate($mods, $self, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'position' {
                $truth += _checkPosition($mods, $self, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'disambiguate' {
                $truth += _checkDisambiguate($mods, $self, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'locator' {
                $truth += _checkLocator($mods, $self, $condiPtr->{$o});
                $qtSubconditions++;
            }
            case 'match' {
                $match = $condiPtr->{match};
            }
        }
    }
    
    switch($match) {
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
            
            print "truth=$truth qtSubconditions=$qtSubconditions\n";
            
            if($truth > 0) { # at least 1
                return 0;
            }
            else {
                return 1;
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
    my ($mods, $self, $type) = @_;
    
    print "_checkType: $type\n";
    
    if(exists $self->{_lMap}->{$self->{lMode}}->{$type}) {
        print "checking type: $type $self->{lMode} $self->{_lMap}->{$self->{lMode}}->{$type}\n";
        
        # is the mods of the respective type (mods-genre vs csl-type)?
        # a mods could have several genre entries.
        if($mods->{genre} eq $self->{_lMap}->{$self->{lMode}}->{$type} ) {
            return 1; 
        }

        return 0; 
    }
}

sub _checkVariable {
    my ($mods, $self, $v) = @_;
    
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
    my ($mods, $self, $n) = @_;
    
    print "_checkIsNumeric: TODO! $n\n";
    #TODO
    
    return 0;    
}

sub _checkIsDate {
    my ($mods, $self, $d) = @_;
    
    print "_checkIsDate: TODO! $d\n";
    #TODO
    
    return 0;    
}

sub _checkPosition {
    my ($mods, $self, $p) = @_;
    
    print "_checkPosition: TODO! $p\n";
    #TODO
    
    return 0;    
}

sub _checkDisambiguate {
    my ($mods, $self, $t) = @_;
    
    print "_checkDisambiguate: TODO! $t\n";
    #TODO
    
    return 0;    
}

sub _checkLocator {
    my ($mods, $self, $l) = @_;
    
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
sub _parseGroup {
    my ($mods, $self, $g, $elemNumber) = @_;
    
    print "_parseGroup\n";
    
    if(ref($g) eq "HASH") {
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
                case "text" { # TODO _parseText!
                    my $delimiter = "";
                    
                    if(ref($g->{$k}) eq "HASH") {
                        $elemNumber++;
                        if($elemNumber>1 && exists $g->{'delimiter'}) {
                            $delimiter = $g->{'delimiter'};
                            $self->{_biblio_str} .= $g->{'delimiter'};
                        }
                        
                        # can appear either as hash
                        if(exists $g->{$k}->{variable}) {
                            _parseVariable($mods, $self, $g->{$k}, $elemNumber, $delimiter);
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
                                _parseVariable($mods, $self, $v, $elemNumber, $delimiter);
                            }
                        }
                    }
                    
                }
                case "group" {
                    $elemNumber = _parseGroup($mods, $self, $g->{$k}, $elemNumber);
                }
                case "class" {
                    
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
            $elemNumber = _parseGroup($mods, $self, $this_group, $elemNumber);
        }
    }
    else {
        die "ERROR: Group is neither hash nor array?";
    }
    
    return $elemNumber;
}


sub _parseVariable {
    my ($mods, $self, $v, $elemNumber, $delimiter) = @_;
    
    print "_parseVariable: $v\n";
    
    #$self->{_biblio_str} .= $v->{prefix} if (exists $v->{prefix});
    
    # set the variable at the "duartion" (availability?) hash.
    ${$self->{_var}}{$v}=1;
    
    switch($v) {
        ## the primary title for the cited item
        case "title" { 
                if(exists $mods->{titleInfo}->{title}) {
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
            # short title?
            if(ref($v) eq "HASH") {
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
            elsif(ref($v) eq "SCALAR") {
                die "ERROR. container-title is scalar, not implemented, yet!";
            }
            elsif(ref($v) eq "ARRAY") {
                die "ERROR. container-title is array, not implemented, yet!";
            }
        }
        ## the tertiary title for the cited item; for example, a series title
        case 'collection-title' {
            #TODO NOT yet testet!!!
            
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
