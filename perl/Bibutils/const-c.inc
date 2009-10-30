#define PERL_constant_NOTFOUND	1
#define PERL_constant_NOTDEF	2
#define PERL_constant_ISIV	3
#define PERL_constant_ISNO	4
#define PERL_constant_ISNV	5
#define PERL_constant_ISPV	6
#define PERL_constant_ISPVN	7
#define PERL_constant_ISSV	8
#define PERL_constant_ISUNDEF	9
#define PERL_constant_ISUV	10
#define PERL_constant_ISYES	11

#ifndef NVTYPE
typedef double NV; /* 5.6 and later define NVTYPE, and typedef NV to it.  */
#endif
#ifndef aTHX_
#define aTHX_ /* 5.6 or later define this for threading support.  */
#endif
#ifndef pTHX_
#define pTHX_ /* 5.6 or later define this for threading support.  */
#endif

static int
constant_11 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     BIBL_ISIOUT BIBL_LASTIN BIBL_MODSIN BIBL_RISOUT */
  /* Offset 5 gives the best switch position.  */
  switch (name[5]) {
  case 'I':
    if (memEQ(name, "BIBL_ISIOUT", 11)) {
    /*                    ^            */
#ifdef BIBL_ISIOUT
      *iv_return = BIBL_ISIOUT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'L':
    if (memEQ(name, "BIBL_LASTIN", 11)) {
    /*                    ^            */
#ifdef BIBL_LASTIN
      *iv_return = BIBL_LASTIN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'M':
    if (memEQ(name, "BIBL_MODSIN", 11)) {
    /*                    ^            */
#ifdef BIBL_MODSIN
      *iv_return = BIBL_MODSIN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'R':
    if (memEQ(name, "BIBL_RISOUT", 11)) {
    /*                    ^            */
#ifdef BIBL_RISOUT
      *iv_return = BIBL_RISOUT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_12 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     BIBL_COPACIN BIBL_FIRSTIN BIBL_LASTOUT BIBL_MODSOUT */
  /* Offset 5 gives the best switch position.  */
  switch (name[5]) {
  case 'C':
    if (memEQ(name, "BIBL_COPACIN", 12)) {
    /*                    ^             */
#ifdef BIBL_COPACIN
      *iv_return = BIBL_COPACIN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'F':
    if (memEQ(name, "BIBL_FIRSTIN", 12)) {
    /*                    ^             */
#ifdef BIBL_FIRSTIN
      *iv_return = BIBL_FIRSTIN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'L':
    if (memEQ(name, "BIBL_LASTOUT", 12)) {
    /*                    ^             */
#ifdef BIBL_LASTOUT
      *iv_return = BIBL_LASTOUT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'M':
    if (memEQ(name, "BIBL_MODSOUT", 12)) {
    /*                    ^             */
#ifdef BIBL_MODSOUT
      *iv_return = BIBL_MODSOUT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_13 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     BIBL_BIBTEXIN BIBL_FIRSTOUT BIBL_SRC_FILE BIBL_SRC_USER */
  /* Offset 12 gives the best switch position.  */
  switch (name[12]) {
  case 'E':
    if (memEQ(name, "BIBL_SRC_FIL", 12)) {
    /*                           E      */
#ifdef BIBL_SRC_FILE
      *iv_return = BIBL_SRC_FILE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'N':
    if (memEQ(name, "BIBL_BIBTEXI", 12)) {
    /*                           N      */
#ifdef BIBL_BIBTEXIN
      *iv_return = BIBL_BIBTEXIN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'R':
    if (memEQ(name, "BIBL_SRC_USE", 12)) {
    /*                           R      */
#ifdef BIBL_SRC_USER
      *iv_return = BIBL_SRC_USER;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'T':
    if (memEQ(name, "BIBL_FIRSTOU", 12)) {
    /*                           T      */
#ifdef BIBL_FIRSTOUT
      *iv_return = BIBL_FIRSTOUT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_14 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     BIBL_ADSABSOUT BIBL_BIBTEXOUT BIBL_ENDNOTEIN BIBL_MEDLINEIN */
  /* Offset 6 gives the best switch position.  */
  switch (name[6]) {
  case 'D':
    if (memEQ(name, "BIBL_ADSABSOUT", 14)) {
    /*                     ^              */
#ifdef BIBL_ADSABSOUT
      *iv_return = BIBL_ADSABSOUT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'E':
    if (memEQ(name, "BIBL_MEDLINEIN", 14)) {
    /*                     ^              */
#ifdef BIBL_MEDLINEIN
      *iv_return = BIBL_MEDLINEIN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'I':
    if (memEQ(name, "BIBL_BIBTEXOUT", 14)) {
    /*                     ^              */
#ifdef BIBL_BIBTEXOUT
      *iv_return = BIBL_BIBTEXOUT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'N':
    if (memEQ(name, "BIBL_ENDNOTEIN", 14)) {
    /*                     ^              */
#ifdef BIBL_ENDNOTEIN
      *iv_return = BIBL_ENDNOTEIN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_15 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     BIBL_BIBLATEXIN BIBL_ENDNOTEOUT BIBL_ERR_MEMERR */
  /* Offset 14 gives the best switch position.  */
  switch (name[14]) {
  case 'N':
    if (memEQ(name, "BIBL_BIBLATEXI", 14)) {
    /*                             N      */
#ifdef BIBL_BIBLATEXIN
      *iv_return = BIBL_BIBLATEXIN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'R':
    if (memEQ(name, "BIBL_ERR_MEMER", 14)) {
    /*                             R      */
#ifdef BIBL_ERR_MEMERR
      *iv_return = BIBL_ERR_MEMERR;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'T':
    if (memEQ(name, "BIBL_ENDNOTEOU", 14)) {
    /*                             T      */
#ifdef BIBL_ENDNOTEOUT
      *iv_return = BIBL_ENDNOTEOUT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_17 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     BIBL_ENDNOTEXMLIN BIBL_ERR_BADINPUT BIBL_ERR_CANTOPEN */
  /* Offset 13 gives the best switch position.  */
  switch (name[13]) {
  case 'M':
    if (memEQ(name, "BIBL_ENDNOTEXMLIN", 17)) {
    /*                            ^          */
#ifdef BIBL_ENDNOTEXMLIN
      *iv_return = BIBL_ENDNOTEXMLIN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'N':
    if (memEQ(name, "BIBL_ERR_BADINPUT", 17)) {
    /*                            ^          */
#ifdef BIBL_ERR_BADINPUT
      *iv_return = BIBL_ERR_BADINPUT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'O':
    if (memEQ(name, "BIBL_ERR_CANTOPEN", 17)) {
    /*                            ^          */
#ifdef BIBL_ERR_CANTOPEN
      *iv_return = BIBL_ERR_CANTOPEN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_20 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     BIBL_CHARSET_DEFAULT BIBL_CHARSET_GB18030 BIBL_CHARSET_UNICODE
     BIBL_CHARSET_UNKNOWN */
  /* Offset 16 gives the best switch position.  */
  switch (name[16]) {
  case '8':
    if (memEQ(name, "BIBL_CHARSET_GB18030", 20)) {
    /*                               ^          */
#ifdef BIBL_CHARSET_GB18030
      *iv_return = BIBL_CHARSET_GB18030;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'A':
    if (memEQ(name, "BIBL_CHARSET_DEFAULT", 20)) {
    /*                               ^          */
#ifdef BIBL_CHARSET_DEFAULT
      *iv_return = BIBL_CHARSET_DEFAULT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'C':
    if (memEQ(name, "BIBL_CHARSET_UNICODE", 20)) {
    /*                               ^          */
#ifdef BIBL_CHARSET_UNICODE
      *iv_return = BIBL_CHARSET_UNICODE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'N':
    if (memEQ(name, "BIBL_CHARSET_UNKNOWN", 20)) {
    /*                               ^          */
#ifdef BIBL_CHARSET_UNKNOWN
      *iv_return = BIBL_CHARSET_UNKNOWN;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant (pTHX_ const char *name, STRLEN len, IV *iv_return) {
  /* Initially switch on the length of the name.  */
  /* When generated this function returned values for the list of names given
     in this section of perl code.  Rather than manually editing these functions
     to add or remove constants, which would result in this comment and section
     of code becoming inaccurate, we recommend that you edit this section of
     code, and use it to regenerate a new set of constant functions which you
     then use to replace the originals.

     Regenerate these constant functions by feeding this entire source file to
     perl -x

#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -w
use ExtUtils::Constant qw (constant_types C_constant XS_constant);

my $types = {map {($_, 1)} qw(IV)};
my @names = (qw(BIBL_ADSABSOUT BIBL_BIBLATEXIN BIBL_BIBTEXIN BIBL_BIBTEXOUT
	       BIBL_CHARSET_DEFAULT BIBL_CHARSET_GB18030 BIBL_CHARSET_UNICODE
	       BIBL_CHARSET_UNKNOWN BIBL_COPACIN BIBL_ENDNOTEIN BIBL_ENDNOTEOUT
	       BIBL_ENDNOTEXMLIN BIBL_ERR_BADINPUT BIBL_ERR_CANTOPEN
	       BIBL_ERR_MEMERR BIBL_FIRSTIN BIBL_FIRSTOUT BIBL_FORMAT_VERBOSE
	       BIBL_ISIIN BIBL_ISIOUT BIBL_LASTIN BIBL_LASTOUT BIBL_MEDLINEIN
	       BIBL_MODSIN BIBL_MODSOUT BIBL_OK BIBL_RAW_WITHCHARCONVERT
	       BIBL_RAW_WITHMAKEREFID BIBL_RISIN BIBL_RISOUT BIBL_SRC_DEFAULT
	       BIBL_SRC_FILE BIBL_SRC_USER BIBL_WORD2007OUT));

print constant_types(), "\n"; # macro defs
foreach (C_constant ("Bibutils", 'constant', 'IV', $types, undef, 3, @names) ) {
    print $_, "\n"; # C constant subs
}
print "\n#### XS Section:\n";
print XS_constant ("Bibutils", $types);
__END__
   */

  switch (len) {
  case 7:
    if (memEQ(name, "BIBL_OK", 7)) {
#ifdef BIBL_OK
      *iv_return = BIBL_OK;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 10:
    /* Names all of length 10.  */
    /* BIBL_ISIIN BIBL_RISIN */
    /* Offset 5 gives the best switch position.  */
    switch (name[5]) {
    case 'I':
      if (memEQ(name, "BIBL_ISIIN", 10)) {
      /*                    ^           */
#ifdef BIBL_ISIIN
        *iv_return = BIBL_ISIIN;
        return PERL_constant_ISIV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    case 'R':
      if (memEQ(name, "BIBL_RISIN", 10)) {
      /*                    ^           */
#ifdef BIBL_RISIN
        *iv_return = BIBL_RISIN;
        return PERL_constant_ISIV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    }
    break;
  case 11:
    return constant_11 (aTHX_ name, iv_return);
    break;
  case 12:
    return constant_12 (aTHX_ name, iv_return);
    break;
  case 13:
    return constant_13 (aTHX_ name, iv_return);
    break;
  case 14:
    return constant_14 (aTHX_ name, iv_return);
    break;
  case 15:
    return constant_15 (aTHX_ name, iv_return);
    break;
  case 16:
    /* Names all of length 16.  */
    /* BIBL_SRC_DEFAULT BIBL_WORD2007OUT */
    /* Offset 6 gives the best switch position.  */
    switch (name[6]) {
    case 'O':
      if (memEQ(name, "BIBL_WORD2007OUT", 16)) {
      /*                     ^                */
#ifdef BIBL_WORD2007OUT
        *iv_return = BIBL_WORD2007OUT;
        return PERL_constant_ISIV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    case 'R':
      if (memEQ(name, "BIBL_SRC_DEFAULT", 16)) {
      /*                     ^                */
#ifdef BIBL_SRC_DEFAULT
        *iv_return = BIBL_SRC_DEFAULT;
        return PERL_constant_ISIV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    }
    break;
  case 17:
    return constant_17 (aTHX_ name, iv_return);
    break;
  case 19:
    if (memEQ(name, "BIBL_FORMAT_VERBOSE", 19)) {
#ifdef BIBL_FORMAT_VERBOSE
      *iv_return = BIBL_FORMAT_VERBOSE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 20:
    return constant_20 (aTHX_ name, iv_return);
    break;
  case 22:
    if (memEQ(name, "BIBL_RAW_WITHMAKEREFID", 22)) {
#ifdef BIBL_RAW_WITHMAKEREFID
      *iv_return = BIBL_RAW_WITHMAKEREFID;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 24:
    if (memEQ(name, "BIBL_RAW_WITHCHARCONVERT", 24)) {
#ifdef BIBL_RAW_WITHCHARCONVERT
      *iv_return = BIBL_RAW_WITHCHARCONVERT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

