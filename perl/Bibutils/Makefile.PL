use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Bibutils',
    VERSION_FROM      => 'lib/Bibutils.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Bibutils.pm', # retrieve abstract from module
       AUTHOR         => 'Stefan Washietl <wash@>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
    MYEXTLIB => 'bibutils/libbibutils$(LIB_EXT)',
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw(BIBL_ADSABSOUT BIBL_BIBLATEXIN BIBL_BIBTEXIN BIBL_BIBTEXOUT
		 BIBL_CHARSET_DEFAULT BIBL_CHARSET_GB18030 BIBL_CHARSET_UNICODE
		 BIBL_CHARSET_UNKNOWN BIBL_COPACIN BIBL_ENDNOTEIN
		 BIBL_ENDNOTEOUT BIBL_ENDNOTEXMLIN BIBL_ERR_BADINPUT
		 BIBL_ERR_CANTOPEN BIBL_ERR_MEMERR BIBL_FIRSTIN BIBL_FIRSTOUT
		 BIBL_FORMAT_VERBOSE BIBL_ISIIN BIBL_ISIOUT BIBL_LASTIN
		 BIBL_LASTOUT BIBL_MEDLINEIN BIBL_MODSIN BIBL_MODSOUT BIBL_OK
		 BIBL_RAW_WITHCHARCONVERT BIBL_RAW_WITHMAKEREFID BIBL_RISIN
		 BIBL_RISOUT BIBL_SRC_DEFAULT BIBL_SRC_FILE BIBL_SRC_USER
		 BIBL_WORD2007OUT));
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'Bibutils',
                                     NAMES        => \@names,
                                     DEFAULT_TYPE => 'IV',
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                  );

}
else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}


sub MY::postamble {
'
$(MYEXTLIB): bibutils/Makefile
	cd bibutils && $(MAKE) $(PASSTHRU)
';
}