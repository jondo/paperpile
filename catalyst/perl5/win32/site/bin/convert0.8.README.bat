@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!perl
#line 15
convert0.8.pl

This utility converts existing components to use new syntax
introduced in Mason 0.8.

1. Old-style mc_commands (mc_comp, mc_file, etc.) are converted to
new-style $m methods ($m->comp, $m->file, etc.) See Commands.pod for
all the conversions to be performed.

2. References to request variable $REQ are converted to $m.

All directories will be traversed recursively.  We STRONGLY recommend
that you backup your components, and/or use the -t flag to preview,
before running this program for real.  Files are modified
destructively and no automatic backups are created.

__END__
:endofperl
