#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Module::Load::Conditional qw[can_load check_install requires];
use Term::ANSIColor;
use CPAN;

my $command=$ARGV[0];

if ((scalar @ARGV !=1) or ($command ne 'info' and $command ne 'install')){
  print "USAGE: install_modules info\n";
  print "       install_modules install\n";
  exit;
}

print<<END;

This script helps you to install all necessary modules to build and
Paperpile on your machine.

It assumes that you have a sane development installation (gcc and friends) and
a configured CPAN installation (run cpan first if you are not sure).

To run this script as automatically as possible, we recommend to set the
'prerequisites_policy' to 'follow' like this:

cpan> o conf prerequisites_policy follow
cpan> conf commit

Depending on your CPAN settings you might need to run this script as root.

END

if ($command eq 'info'){
  print "Run './install_modules.pl install' to start the actual installation process.\n";
}

my $list = 'modules.list';
open( MODULES, "<$list" );

my @required=();

foreach my $module (<MODULES>) {
  chomp($module);
  next if $module =~ /^\s*#/;
  next if $module =~ /^$/;
  push @required, $module;
}

my @available = ();
my @missing   = ();

foreach my $module (@required){
  my $rv = check_install( module => $module );
  if ($rv) {
    push @available, ($module);
  } else {
    push @missing, ($module);
  }
}

print "\nRequired modules installed on your system:\n\n";

foreach my $module (@available){
  print "     $module\n";
}

if (@missing){

  print "\nRequired modules missing:\n\n";

  foreach my $module (@missing){
    print colored ("     $module\n", 'red');
  }

  print "\n";

  exit(0) if ($command eq 'info');

  print "I will try to install ".($#missing+1)." missing CPAN modules\n\n";

  print "ENTER to start installation process (Ctrl-c to exit)\n";
  my $input=<STDIN>;


  foreach my $module (@missing){

    print colored ("\nInstalling $module...\n\n", 'red');

    my $rv = check_install( module => $module );

    if ($rv){
      print "Module has been installed already. Skipping.\n\n";
      next;
    }

    CPAN::Shell->install($module);

  }

  print colored ("\nCPAN Installation process finished.\n\n", 'red');

  my @missing=();
  foreach my $module (@required){
    my $rv = check_install( module => $module );
    if (!$rv) {
      push @missing, ($module);
    }
  }

  if (@missing){
    print "\nThe following CPAN modules could not be installed\n";
    print "You need to try to install them manually (consider using force):\n\n";

    foreach my $module (@missing){
      print colored ("     $module\n", 'red');
    }
  } else {
    print "\nAll required CPAN modules installed successfully.\n";
  }
} else {
  print "\nAll required CPAN modules installed. Don't have to do anything.\n";
}















