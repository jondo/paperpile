package Mac::SystemDirectory;

use 5.006000;
use strict;
use warnings;

BEGIN {
    our $VERSION     = '0.06';
    our @EXPORT_OK   = ('FindDirectory', 'HomeDirectory', 'TemporaryDirectory');

    require XSLoader;
    XSLoader::load('Mac::SystemDirectory', $VERSION);

    our %EXPORT_TAGS = (
        'all'        => [ @EXPORT_OK ],
        'DomainMask' => [ grep { /^NS.*DomainMask/ } @EXPORT_OK ],
        'Directory'  => [ grep { /^NS.*Directory/  } @EXPORT_OK ],
    );

    require Exporter;
    *import = \&Exporter::import;
}

1;
__END__

=head1 NAME

Mac::SystemDirectory - Locate Mac OS X Standard System Directories

=head1 SYNOPSIS

  use Mac::SystemDirectory qw[:all];
  
  $path = FindDirectory(NSDocumentDirectory);
  $path = HomeDirectory();
  $path = TemporaryDirectory();

=head1 DESCRIPTION

Locate Mac OS X Standard System Directories

=head1 FUNCTIONS

=over 4

=item FindDirectory(Directory [, DomainMask])

Creates a list of path strings for the specified directories in the specified 
domains. The list is in the order in which you should search the directories.

I<Usage>

    $path  = FindDirectory(NSApplicationDirectory);
    @paths = FindDirectory(NSApplicationDirectory);

I<Arguments>

=over 4

=item Directory

L</Directory> constant.

=item DomainMask (optional)

L</DomainMask> constant. Defaults to C<NSUserDomainMask>.

=back

I<Returns>

When called in scalar context this function returns the first matching 
directory. In list context it returns all matching directories.
If no directories are found, undef is returned in a scalar context and an 
empty list in a list context.

=item HomeDirectory()

Path to the current user's home directory.

I<Usage>

    $path = HomeDirectory();

I<Returns>

A string containing the path of the current user's home directory.

=item TemporaryDirectory()

Path to the current user's temporary directory.

I<Usage>

    $path = TemporaryDirectory();

I<Returns>

A string containing the path of the temporary directory for the current user. 
If no such directory is currently available, returns undef.

=back

=head1 CONSTANTS

=head2 DomainMask

Bitmask constants that identify the file-system domain (User, System, Local, Network) or all domains.

=over 4

=item NSUserDomainMask

The user's home directory-the place to install user's personal items (~).

Available in Mac OS X v10.0 and later.

=item NSLocalDomainMask

Local to the current machine-the place to install items available to everyone on this machine.

Available in Mac OS X v10.0 and later.

=item NSNetworkDomainMask

Publicly available location in the local area network-the place to install items available on the network (/Network).

Available in Mac OS X v10.0 and later.

=item NSSystemDomainMask

Provided by Apple - can't be modified (/System).

Available in Mac OS X v10.0 and later.

=item NSAllDomainsMask

All domains. Includes all of the above and future items.

Available in Mac OS X v10.0 and later.

=back

=head2 Directory

Constants that identify the name or type of directory (for example, Library, Documents, or Applications).

=over 4

=item NSApplicationDirectory

Supported applications (/Applications).

Available in Mac OS X v10.0 and later.

=item NSDemoApplicationDirectory

Unsupported applications and demonstration versions.

Available in Mac OS X v10.0 and later.

=item NSDeveloperApplicationDirectory

Developer applications (/Developer/Applications).

Available in Mac OS X v10.0 and later.

=item NSAdminApplicationDirectory

System and network administration applications.

Available in Mac OS X v10.0 and later.

=item NSLibraryDirectory

Various user-visible documentation, support, and configuration files (/Library).

Available in Mac OS X v10.0 and later.

=item NSDeveloperDirectory

Developer resources (/Developer).
Deprecated: Beginning with Xcode 3.0, developer tools can be installed in any location.

Available in Mac OS X v10.0 and later.

=item NSUserDirectory

User home directories (/Users).

Available in Mac OS X v10.0 and later.

=item NSDocumentationDirectory

Documentation.

Available in Mac OS X v10.0 and later.

=item NSDocumentDirectory

Document directory.

Available in Mac OS X v10.2 and later.

=item NSCoreServiceDirectory

Location of core services (System/Library/CoreServices).

Available in Mac OS X v10.4 and later.

=item NSAutosavedInformationDirectory

Location of user's autosaved documents Documents/Autosaved

Available in Mac OS X v10.6 and later.

=item NSDesktopDirectory

Location of user's desktop directory.

Available in Mac OS X v10.4 and later.

=item NSCachesDirectory

Location of discardable cache files (Library/Caches).

Available in Mac OS X v10.4 and later.

=item NSApplicationSupportDirectory

Location of application support files (Library/Application Support).

Available in Mac OS X v10.4 and later.

=item NSDownloadsDirectory

Location of the user's downloads directory.

Available in Mac OS X v10.5 and later.

=item NSInputMethodsDirectory

Location of Input Methods (Library/Input Methods)

Available in Mac OS X v10.6 and later.

=item NSMoviesDirectory

Location of user's Movies directory (~/Movies)

Available in Mac OS X v10.6 and later.

=item NSMusicDirectory

Location of user's Movies directory (~/Music)

Available in Mac OS X v10.6 and later.

=item NSPicturesDirectory

Location of user's Movies directory (~/Pictures)

Available in Mac OS X v10.6 and later.

=item NSPrinterDescriptionDirectory

Location of system's PPDs directory (Library/Printers/PPDs)

Available in Mac OS X v10.6 and later.

=item NSSharedPublicDirectory

Location of user's Public sharing directory (~/Public)

Available in Mac OS X v10.6 and later.

=item NSPreferencePanesDirectory

Location of the PreferencePanes directory for use with System Preferences (Library/PreferencePanes)

Available in Mac OS X v10.6 and later.

=item NSItemReplacementDirectory

For use with NSFileManager method URLForDirectory:inDomain:appropriateForURL:create:error:

Available in Mac OS X v10.6 and later.

=item NSAllApplicationsDirectory

All directories where applications can occur.

Available in Mac OS X v10.0 and later.

=item NSAllLibrariesDirectory

All directories where resources can occur.

Available in Mac OS X v10.0 and later.

=back

=head1 EXPORT

None by default. Functions and constants can either be imported individually or
in sets grouped by tag names. The tag names are:

=over 4

=item C<:all> exports all functions and constants.

=item C<:DomainMask> exports all L</DomainMask> constants.

=item C<:Directory> exports all L</Directory> constants.

=back

=head1 SEE ALSO

L<http://developer.apple.com/mac/library/DOCUMENTATION/Cocoa/Conceptual/LowLevelFileMgmt/Articles/StandardDirectories.html>
L<http://developer.apple.com/mac/library/documentation/MacOSX/Conceptual/BPFileSystem/BPFileSystem.html>

=head1 AUTHOR

Christian Hansen, E<lt>chansen@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Christian Hansen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.9 or,
at your option, any later version of Perl 5 you may have available.

=cut
