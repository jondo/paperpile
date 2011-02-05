use Benchmark;
use Getopt::Long;
use File::Basename;
use XML::XPath;
use strict;

$|++;

my @default_drivers = qw(
    LibXSLT
    Sablotron
    );

use vars qw(
        $component $iter $ms $kb_in $kb_out $kb_sec $result $ref_size
        );

my @getopt_args = (
        'c=s', # config file
        'n=i', # number of benchmark times
        'd=s@', # drivers
        't', # only 1 iteration per test
        'v', # verbose
        'h', # help
        'x', # XSLTMark emulation
        );

my %options;

Getopt::Long::config("bundling");

unless (GetOptions(\%options, @getopt_args)) {
    usage();
}

usage() if $options{h};

$options{c} ||= 'testcases/default.conf';

my $basedir = dirname($options{c});

$options{d} ||= [@default_drivers];

$options{n} ||= 1;

# load drivers
for my $driver (@{$options{d}}) {
    warn "Loading $driver Driver\n" if $options{v};
    require "Driver/$driver.pm";
}

# load config
my @config;
open(CONFIG, $options{c}) || die "Can't open config file '$options{c}' : $!";
my $current = {};
while(my $line = <CONFIG>) {
    if ($line =~ /^\s*$/m && %$current) {
        push @config, $current;
        $current = {};
    }
    
    # ignore comments and full line comments
    $line =~ s/#.*$//;
    next unless $line =~ /\S/;
    
    if ($line =~ /^\s*\[(.*)\]\s*$/) {
        $current->{component} = $1;
    }
    elsif ($line =~ /^(.*?)\s*=\s*(.*)$/) {
        $current->{$1} = $2;
    }
}

for my $driver (@{$options{d}}) {
    my $pkg = "Driver::${driver}";
    
    $pkg->can('init')->(verbose => $options{v});
    
    $pkg->can('chdir')->($basedir);
    
    print "Testing: $driver\n\n";

    print_header();
    
    my %totals;

    COMPONENT:
    for my $cmp (@config) {
        warn "Running test: $cmp->{component}\n" if $options{v};
        for (1..$options{n}) {
            $component = $cmp->{component};
            $iter = $ms = $kb_in = $kb_out = $kb_sec = $ref_size = 0;

            if ($cmp->{skipdriver} =~ /\b\Q$driver\E\b/) {
                $result = 'SKIPPED';
                print_output() unless $cmp->{written};
                $cmp->{written}++;
                next COMPONENT;
            }

            eval {
                $pkg->can('load_stylesheet')->($cmp->{stylesheet});
                $pkg->can('load_input')->($cmp->{input});

                $iter = $cmp->{iterations};
                $iter = 1 if $options{t};


                my $bench = timeit($iter, sub {
                        $pkg->can('run_transform')->($cmp->{output});
                    });
                
                my $str = timestr($bench, 'all', '5.4f');
                
                if ($str =~ /\((\d+\.\d+)/) {
                    $ms = $1;
                    $ms *= 1000;
                }
                
                $kb_in = (stat($cmp->{input}))[7];

                if ($options{x}) {
                    $kb_in /= 1000;
                }
                else {
                    $kb_in += (stat($cmp->{stylesheet}))[7];
                    $kb_in /= 1024;
                }
                
                $kb_in *= $iter;

                $kb_out = (stat($cmp->{output}))[7];
                $kb_out /= 1024;
                $kb_out *= $iter;

                die "failed - no output\n" unless $kb_out > 0;

                $kb_sec = ($kb_in + $kb_out) /
                            ( $ms / 500 );

                if ($cmp->{reference}) {
                    $ref_size = (stat($cmp->{reference}))[7];
                    $ref_size /= 1024;

                    open(REFERENCE, $cmp->{reference}) || die "Can't open reference '$cmp->{reference}' : $!";
                    open(NEW, $cmp->{output}) || die "Can't open transform output '$cmp->{output}' : $!";
                    local $/;
                    my $ref = <REFERENCE>;
                    my $new = <NEW>;
                    close REFERENCE;
                    close NEW;
                    $new =~ s/\A<\?xml.*?\?>\s*//;
                    $new =~ s/\A<!DOCTYPE.*?>\s*//;

                    if (!length($new)) {
                        die "output length failed\n";
                    }
                    if ($new eq $ref) {
                        $result = 'OK';
                    }
                    else {
                        $result = 'CHECK OUTPUT';
                        eval {
                            my $rpp = XML::XPath->new(xml => $ref);
                            my $ppp = XML::XPath::XMLParser->new(xml => $new);
                            my $npp;
                            eval {
                                $npp = $ppp->parse;
                            };
                            if ($@) {
                                $npp = $ppp->parse("<norm>$new</norm>");
                            }
                            my @rnodes = $rpp->findnodes('//*');
                            my @nnodes = $npp->findnodes('//*');
#                            warn "ref nodes: ", scalar(@rnodes), "\n";
#                            warn "new nodes: ", scalar(@nnodes), "\n";
                            if (@rnodes == @nnodes) {
                                $result = 'COUNT OK';
                            }
                        };
                        if ($@) {
                            warn $@ if $options{v};
                        }
                    }
                }
                else {
                    $result = 'NO REFERENCE';
                }
            };
            if ($@) {
                warn "$component failed: $@" if $options{v};
                $result = 'ERROR';
            }
            
            if (($result =~ /OK/) || ($result eq 'NO REFERENCE')) {
                $totals{iter} += $iter;
                $totals{ms} += $ms;
                $totals{kb_in} += $kb_in;
                $totals{kb_out} += $kb_out;
            }

            print_output() unless $cmp->{written};
            $cmp->{written}++;
        } # $options{n} loop
        
        delete $cmp->{written};
    } # each component
    
    $pkg->can('shutdown')->();
    
    $component = 'total';
    $iter = $totals{iter};
    $ms = $totals{ms};
    $kb_in = $totals{kb_in};
    $kb_out = $totals{kb_out};
    $kb_sec = ($kb_in + $kb_out) / 
                ( $ms / 500 );
    $ref_size = 0;
    $result = '';
    print_output();
}

sub usage {
    print <<EOT;
usage: $0 [options]

    options:

        -c <file>   load configuration from <file>
                    defaults to testcases/default.conf
                    
        -n <num>    run each test case <num> times. Default = 1.
        
        -t          only one iteration per test case (note this
                    is different to -n 1)
        
        -d <Driver> test <Driver>. Use multiple -d options to test
                    more than one driver. Defaults are set in this
                    script (the \@default_drivers variable).
        
        -x          XSLTMark emulation. Infuriatingly XSLTMark thinks
                    there are 1000 bytes in a Kilobyte. Someone please
                    tell them some basic computer science...
                    
                    Without this option, this benchmark also includes
                    the size of the stylesheet in the KB In figure.
                    
        -v          be verbose.

Copyright 2001 AxKit.com Ltd. This is free software, you may use it and
distribute it under either the GNU GPL Version 2, or under the Perl
Artistic License.

EOT
    exit(0);
}

sub print_header {
    print STDOUT <<'EOF';
Test Component   Iter    ms   KB In  KB Out      KB/s     Result
==========================================================================
EOF
}

sub print_output {
    printf STDOUT "%-15.15s %5.0d %5.0d %7.0f %7.0f %9.2f   %-15.15s\n",
            $component, $iter, $ms, $kb_in, $kb_out, $kb_sec, $result;
}
