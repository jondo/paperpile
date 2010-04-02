#!/Users/wash/play/paperpile/build/../catalyst/perl5/osx/bin/perl -w

eval 'exec /Users/wash/play/paperpile/build/../catalyst/perl5/osx/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use Data::Dumper;
use File::Find;	   
use Getopt::Std;
use IO::File;
use strict;

my ($EXCLUDE, $HELP, $LOWER, $QUIET, $TEST, $UPPER);

my $usage = <<EOF;
Usage: $0 -hlqtu [-e <regexp>] <directory> [<directory>...]
-e <regexp>: Exclude paths matching <regexp> case-insensitive. e.g. "(.gif|.jpg)$"
-h: Display help message and exit
-l: Write all section names as lowercase (<%init>, etc.)
-q: Quiet mode, do not report normal processing of files
-t: Do not actually change files, just report what changes would be made
-u: Write all section names as uppercase (<%INIT>, etc.)
EOF

my $helpmsg = <<EOF;
This utility converts existing components to use two new syntactic
constructs introduced in Mason 0.6.

1.  Long section names (<%perl_init>, <%perl_args>, etc.) are
converted to short names (<%init>, <%args>, etc.) You have the option
of also standardizing to uppercase (with -u) or lowercase (with -l);
by default the case will be kept the same.

2. Component calls of the form
    <% mc_comp('path', args...) %>
are converted to
    <& path, args... &>
We try to recognize the most common variations; less common ones will
need to be converted manually.

Warning: If you use <% mc_comp(...) %> for components that *return*
HTML rather than outputting it, this will erroneously be converted to
<& &> (which discards the return value). Unfortunately there is no
easy way for us to detect this. Please be aware of this case and QA
your site carefully after conversion.

All directories will be traversed recursively.  We STRONGLY recommend
that you backup your components, and/or use the -t flag to preview,
before running this program for real.  Files are modified
destructively and no automatic backups are created.
EOF

my $warning = <<EOF;
Warning: All directories will be traversed recursively.  Files are
modified destructively and no automatic backups are created.
EOF

sub usage
{
    print $usage;
    exit;
}

sub main
{
    my (%opts);
    getopts('e:hlqtu',\%opts);
    ($EXCLUDE, $HELP, $LOWER, $QUIET, $TEST, $UPPER) = @opts{qw(e h l q t u)};
    if ($HELP) { print "$helpmsg\n$usage"; exit }
    if (!@ARGV) { print "$usage\n$helpmsg"; exit }
    my @dirs = @ARGV;
    
    if (!$TEST) {
	print "*** Mason 0.6 Conversion ***\n\n";
	print "Quiet mode.\n" if defined($QUIET);
	print "Excluding paths matching ($EXCLUDE).\n" if defined($EXCLUDE);
	print "Processing ".(@dirs==1 ? "directory " : "directories ").join(",",@dirs)."\n";
	print $warning;
	print "\nProceed? [n] ";
	exit if ((my $ans = <STDIN>) !~ /[Yy]/);
    }
    my $sub = sub {
	if (-f $_ && -s _) {
	    return if defined($EXCLUDE) && "$File::Find::dir/$_" =~ /$EXCLUDE/i;
	    convert($_,"$File::Find::dir/$_");
	}
    };
    find($sub,@dirs);
}

sub convert
{
    my ($file,$path) = @_;
    my $buf;
    my $infh = new IO::File $file;
    if (!$infh) { warn "cannot read $path: $!"; return }
    { local $/ = undef; $buf = <$infh> }

    my $c = 0;
    my @changes;
    my $report = sub { push(@changes,"$_[0]  -->  $_[1]") };

    #
    # Convert section names to short versions
    #
    my $pat = "<(/?%)perl_(args|cleanup|doc|init|once|text)>";
    if (!$TEST) {
	if ($UPPER) {
	    $c += ($buf =~ s{$pat}{"<$1".uc($2).">"}geio);
	} elsif ($LOWER) {
	    $c += ($buf =~ s{$pat}{"<$1".lc($2).">"}geio);
	} else {
	    $c += ($buf =~ s{$pat}{<$1$2>}gio);
	}
    } else {
	while ($buf =~ m{($pat)}gio) {
	    $report->($1,"<$2".($UPPER ? uc($3) : $LOWER ? lc($3) : $3).">");
	}
    }

    #
    # Convert <% mc_comp ... %> to <& ... &>
    #
    if (!$TEST) {
	$c += ($buf =~ s{<%\s*mc_comp\s*\(\s*\'([^\']+)\'\s*(.*?)\s*\)\s*%>} {<& $1$2 &>}g);
	$c += ($buf =~ s{<%\s*mc_comp\s*\(\s*\"([^\"\$]+)\"\s*(.*?)\s*\)\s*%>} {<& $1$2 &>}g);
	$c += ($buf =~ s{<%\s*mc_comp\s*\(\s*(\"[^\"]+\")\s*(.*?)\s*\)\s*%>} {<& $1$2 &>}g);
	$c += ($buf =~ s{<%\s*mc_comp\s*\(\s*(.*?)\s*\)\s*%>} {<& $1 &>}g);
    } else {
	while ($buf =~ m{(<%\s*mc_comp\s*\(\s*\'([^\']+)\'\s*(.*?)\s*\)\s*%>)}g) {
	    $report->($1,"<& $2$3 &>");
	}
	$buf =~ s{<%\s*mc_comp\s*\(\s*\'([^\']+)\'\s*(.*?)\s*\)\s*%>} {<& $1$2 &>}g;
	while ($buf =~ m{(<%\s*mc_comp\s*\(\s*\"([^\"\$]+)\"\s*(.*?)\s*\)\s*%>)}g) {
	    $report->($1,"<& $2$3 &>");
	}
	$buf =~ s{<%\s*mc_comp\s*\(\s*\"([^\"\$]+)\"\s*(.*?)\s*\)\s*%>} {<& $1$2 &>}g;
	while ($buf =~ m{(<%\s*mc_comp\s*\(\s*(\"[^\"]+\")\s*(.*?)\s*\)\s*%>)}g) {
	    $report->($1,"<& $2$3 &>");
	}
	$buf =~ s{<%\s*mc_comp\s*\(\s*(\"[^\"]+\")\s*(.*?)\s*\)\s*%>} {<& $1$2 &>}g;
        while ($buf =~ m{(<%\s*mc_comp\s*\((.*?)\s*\)\s*%>)}g) {
	    $report->($1,"<& $2 &>");
	}
    }

    if ($TEST) {
	if (@changes) {
	    print scalar(@changes)." substitutions in $path:\n";
	    print join("\n",@changes)."\n\n";
	}
    }
    
    if ($c && !$TEST) {
	print "$c substitutions in $path\n" if !$QUIET;
	my $outfh = new IO::File ">$file";
	if (!$outfh) { warn "cannot write $path: $!"; return }
	$outfh->print($buf);
    }
}


main();
