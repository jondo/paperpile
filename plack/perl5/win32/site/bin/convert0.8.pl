#!C:\Users\wash\play\local\strawberry\perl\bin\perl.exe -w

use Data::Dumper;
use File::Find;	   
use Getopt::Std;
use IO::File;
use strict;

my ($EXCLUDE, $HELP, $QUIET, $TEST);

my $usage = <<EOF;
Usage: $0 -hqt [-e <regexp>] <directory> [<directory>...]
-e <regexp>: Exclude paths matching <regexp> case-insensitive. e.g. "(.gif|.jpg)$"
-h: Display help message and exit
-q: Quiet mode, do not report normal processing of files
-t: Do not actually change files, just report what changes would be made
EOF

my $helpmsg = <<EOF;
This utility converts existing components to use new syntax
introduced in Mason 0.8.

1. Old-style mc_commands (mc_comp, mc_file, etc.) are converted to
new-style \$m methods (\$m->comp, \$m->file, etc.) See Commands.pod for
all the conversions to be performed.

2. References to request variable \$REQ are converted to \$m.

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
    ($EXCLUDE, $HELP, $QUIET, $TEST) = @opts{qw(e h q t)};
    if ($HELP) { print "$helpmsg\n$usage"; exit }
    if (!@ARGV) { print "$usage\n$helpmsg"; exit }
    my @dirs = @ARGV;
    
    if (!$TEST) {
	print "*** Mason 0.8 Conversion ***\n\n";
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
    my (@changes,@failures);
    my $report = sub { push(@changes,$_[1] ? "$_[0]  -->  $_[1]" : "removed $_[0]") };
    my $report_failure = sub { push(@failures,$_[0]) };

    #
    # Convert mc_ commands to $m-> method equivalents
    #
    # Easy substitutions
    #
    my $easy_cmds = join("|",qw(abort cache cache_self call_self comp comp_exists dhandler_arg file file_root out time));
    if (!$TEST) {
	$c += ($buf =~ s{mc_($easy_cmds)(?![A-Za-z0-9 _])}{"\$m->$1"}geo);
    } else {
	while ($buf =~ m{(mc_($easy_cmds)(?![A-Za-z0-9 _]))}go) {
	    $report->($1,"\$m->$2");
	}
    }

    # Boilerplate substitutions for methods with no arguments
    my @subs =
	(['mc_auto_comp',    '$m->fetch_next->path'],
	 ['mc_caller',       '$m->callers(1)->path'],
	 ['mc_comp_source',  '$m->current_comp->source_file'],
	 ['mc_comp_stack',   'map($_->title,$m->callers)'],
	 );
    foreach my $sub (@subs) {
	my ($mc_cmd,$repl) = @$sub;
	if (!$TEST) {
	    $c += ($buf =~ s{$mc_cmd(\s*\(\))?(?!\s*[\(])}{$repl}ge);
	} else {
	    while ($buf =~ m{($mc_cmd(\s*\(\))?(?!\s*[\(]))}g) {
		$report->($1,$repl);
	    }
	}
    }

    # Boilerplate substitutions for methods with arguments
    @subs =
	(['mc_auto_next',    '$m->call_next'],
	 );
    foreach my $sub (@subs) {
	my ($mc_cmd,$repl) = @$sub;
	if (!$TEST) {
	    $c += ($buf =~ s{$mc_cmd}{$repl}ge);
	} else {
	    while ($buf =~ m{($mc_cmd)}g) {
		$report->($1,$repl);
	    }
	}
    }

    # mc_comp_source with simple argument
    if (!$TEST) {
	$c += ($buf =~ s{mc_comp_source\s*\(([^\(\)]+)\)}{"\$m->fetch_comp($1)->source_file"}ge);
    } else {
	while ($buf =~ m{(mc_comp_source\s*\(([^\(\)]+)\))}g) {
	    $report->($1,"\$m->fetch_comp($2)->source_file");
	}
    }

    # mc_suppress_http_header with and without arguments
    if (!$TEST) {
	$c += ($buf =~ s{mc_suppress_http_header\s*(?!\s*\();?}{}g);
	$c += ($buf =~ s{mc_suppress_http_header\s*\([^\(\)]*\)\s*;?}{}g);
    } else {
	while ($buf =~ m{(mc_suppress_http_header\s*(?!\s*\();?)}g) {
	    $report->($1,"");
	}
	while ($buf =~ m{(mc_suppress_http_header\s*\([^\(\)]*\)\s*;?)}g) {
	    $report->($1,"");
	}
    }    
    
    #
    # Convert $REQ to $m
    #
    if (!$TEST) {
	$c += ($buf =~ s{\$REQ(?![A-Za-z0-9_])}{\$m}go);
    } else {
	while ($buf =~ m{(\$REQ(?![A-Za-z0-9_]))}go) {
	    $report->($1,"\$m");
	}
    }
    
    # Report substitutions we can't handle
    foreach my $cmd (qw(mc_comp_source mc_suppress_http_header)) {
	if ($buf =~ m{$cmd\s*\([^\)]*\(}) {
	    $report_failure->("Can't convert $cmd with complex arguments");
	}
    }
    if ($buf =~ m{mc_date}) {
	$report_failure->("Can't convert mc_date");
    }
	
    if ($TEST) {
	if (@changes) {
	    print scalar(@changes)." substitutions in $path:\n";
	    print join("\n",@changes)."\n";
	}
    }
    
    if ($c && !$TEST) {
	print "$c substitutions in $path\n" if !$QUIET;
	my $outfh = new IO::File ">$file";
	if (!$outfh) { warn "cannot write $path: $!"; return }
	$outfh->print($buf);
    }
    
    foreach my $failure (@failures) {
	print "** Warning: $failure; must fix manually\n";
    }

    print "\n" if (($TEST && @changes) || @failures);
}


main();
