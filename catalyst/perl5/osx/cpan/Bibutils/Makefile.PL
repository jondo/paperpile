use ExtUtils::MakeMaker;
$Verbose = 1;
WriteMakefile(
              NAME   => 'Bibutils',
              SKIP   => [qw(all static static_lib dynamic dynamic_lib)],
              clean  => {'FILES' => 'libbibutils$(LIB_EXT)'},
             );


sub MY::top_targets {
'
all :: static

pure_all :: static

static :: libbibutils$(LIB_EXT)

libbibutils$(LIB_EXT): $(O_FILES)
	$(AR) cr libbibutils$(LIB_EXT) $(O_FILES)
	$(RANLIB) libbibutils$(LIB_EXT)
';

}
