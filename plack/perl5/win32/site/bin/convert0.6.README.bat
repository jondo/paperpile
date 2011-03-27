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
convert0.6.pl

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

__END__
:endofperl
