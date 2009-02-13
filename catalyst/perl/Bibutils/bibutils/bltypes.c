/*
 * bltypes.c
 *
 * Copyright (c) Chris Putnam 2008
 *
 * Program and source code released under the GPL
 *
 */

#include <stdio.h>
#include "fields.h"
#include "reftypes.h"

/* Entry types for biblatex formatted bibliographies */

/*
 * Article in a journal, newspaper, other periodical
 */
static lookups article[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "editor",          "EDITOR",       PERSON, LEVEL_MAIN },
	{ "redactor",        "REDACTOR",     PERSON, LEVEL_MAIN },
	{ "annotator",       "ANNOTATOR",    PERSON, LEVEL_MAIN },
	{ "commentator",     "COMMENTATOR",  PERSON, LEVEL_MAIN },
	{ "translator",      "TRANSLATOR",   PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "journaltitle",    "TITLE",        SIMPLE, LEVEL_HOST },
	{ "journalsubtitle", "SUBTITLE",     SIMPLE, LEVEL_HOST },
	{ "issuetitle",      "TITLE",        SIMPLE, LEVEL_SERIES }, /*WRONG*/
	{ "issuesubtitle",   "SUBTITLE",     SIMPLE, LEVEL_SERIES }, /*WRONG*/
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "origlanguage",    "LANGUGE",      SIMPLE, LEVEL_ORIG },
	{ "origyear",        "YEAR",         SIMPLE, LEVEL_ORIG },
	{ "origtitle",       "TITLE",        SIMPLE, LEVEL_ORIG },
	{ "origlocation",    "LOCATION",     SIMPLE, LEVEL_ORIG },
	{ "origpublisher",   "PUBLISHER",    SIMPLE, LEVEL_ORIG },
	{ "series",          "TITLE",        SIMPLE, LEVEL_SERIES },
	{ "volume",          "VOLUME",       SIMPLE, LEVEL_MAIN },
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "eid",             "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "issue",           "ISSUE",        SIMPLE, LEVEL_MAIN },
	{ "date",            "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "day",             "PARTDAY",      SIMPLE, LEVEL_MAIN },
	{ "month",           "PARTMONTH",    SIMPLE, LEVEL_MAIN },
	{ "year",            "PARTYEAR",     SIMPLE, LEVEL_MAIN },
	{ "pages",           "PAGES",        PAGES,  LEVEL_MAIN },
	{ "version",         "VERSION",      SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTES",        SIMPLE, LEVEL_MAIN },
	{ "issn",            "ISSN",         SIMPLE, LEVEL_HOST },
	{ "addendum",        "?????",        SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "eprinttype",      "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "url",             "URL",          BIBTEX_URL, LEVEL_MAIN },
	{ "urldate",         "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "urlday",          "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "urlmonth",        "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "urlyear",         "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",            "TYPE|ARTICLE",           ALWAYS, LEVEL_MAIN },
	{ " ",            "ISSUANCE|continuing",    ALWAYS, LEVEL_HOST },
	{ " ",            "RESOURCE|text",          ALWAYS, LEVEL_MAIN },
	{ " ",            "GENRE|periodical",       ALWAYS, LEVEL_HOST }
};

/* Book */

static lookups book[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "editor",          "EDITOR",       PERSON, LEVEL_MAIN },
	{ "redactor",        "REDACTOR",     PERSON, LEVEL_MAIN },
	{ "annotator",       "ANNOTATOR",    PERSON, LEVEL_MAIN },
	{ "commentator",     "COMMENTATOR",  PERSON, LEVEL_MAIN },
	{ "translator",      "TRANSLATOR",   PERSON, LEVEL_MAIN },
	{ "introduction",    "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "foreward",        "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "afterward",       "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "maintitle",       "TITLE",        SIMPLE, LEVEL_HOST },
	{ "mainsubtitle",    "SUBTITLE",     SIMPLE, LEVEL_HOST },
	{ "maintitleaddon",  "?????",        SIMPLE, LEVEL_HOST },   /*WRONG*/
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "origlanguage",    "LANGUAGE",     SIMPLE, LEVEL_ORIG },
	{ "origyear",        "YEAR",         SIMPLE, LEVEL_ORIG },
	{ "origtitle",       "TITLE",        SIMPLE, LEVEL_ORIG },
	{ "origlocation",    "LOCATION",     SIMPLE, LEVEL_ORIG },
	{ "origpublisher",   "PUBLISHER",    SIMPLE, LEVEL_ORIG },
	{ "volume",          "VOLUME",       SIMPLE, LEVEL_HOST },
	{ "part",            "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "edition",         "EDITION",      SIMPLE, LEVEL_MAIN },
	{ "volumes",         "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "series",          "TITLE",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "isbn",            "ISBN",         SIMPLE, LEVEL_MAIN },
	{ "chapter",         "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pages",           "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pagetotal",       "?????????",    SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "TYPE|BOOK",    ALWAYS, LEVEL_MAIN },
	{ " ",               "RESOURCE|text",ALWAYS, LEVEL_MAIN },
	{ " ",               "ISSUANCE|monographic", ALWAYS, LEVEL_MAIN },
	{ " ",               "GENRE|book",   ALWAYS, LEVEL_MAIN }
};

/* Booklet */

static lookups booklet[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "editor",          "EDITOR",       PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "type",            "?????????",    SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "chapter",         "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pages",           "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pagetotal",       "?????????",    SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "TYPE|BOOK",    ALWAYS, LEVEL_MAIN },
	{ " ",               "RESOURCE|text",ALWAYS, LEVEL_MAIN },
	{ " ",               "ISSUANCE|monographic", ALWAYS, LEVEL_MAIN },
	{ " ",               "GENRE|book",   ALWAYS, LEVEL_MAIN }
};

static lookups collection[] = {
	{ "editor",          "EDITOR",       PERSON, LEVEL_MAIN },
	{ "redactor",        "REDACTOR",     PERSON, LEVEL_MAIN },
	{ "annotator",       "ANNOTATOR",    PERSON, LEVEL_MAIN },
	{ "commentator",     "COMMENTATOR",  PERSON, LEVEL_MAIN },
	{ "translator",      "TRANSLATOR",   PERSON, LEVEL_MAIN },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "introduction",    "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "foreward",        "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "afterward",       "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "maintitle",       "TITLE",        SIMPLE, LEVEL_HOST },
	{ "mainsubtitle",    "SUBTITLE",     SIMPLE, LEVEL_HOST },
	{ "maintitleaddon",  "?????",        SIMPLE, LEVEL_HOST },   /*WRONG*/
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "origlanguage",    "LANGUAGE",     SIMPLE, LEVEL_ORIG },
	{ "origyear",        "YEAR",         SIMPLE, LEVEL_ORIG },
	{ "origtitle",       "TITLE",        SIMPLE, LEVEL_ORIG },
	{ "origlocation",    "LOCATION",     SIMPLE, LEVEL_ORIG },
	{ "origpublisher",   "PUBLISHER",    SIMPLE, LEVEL_ORIG },
	{ "volume",          "VOLUME",       SIMPLE, LEVEL_HOST },
	{ "part",            "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "edition",         "EDITION",      SIMPLE, LEVEL_MAIN },
	{ "volumes",         "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "series",          "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "isbn",            "ISBN",         SIMPLE, LEVEL_MAIN },
	{ "chapter",         "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pages",           "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pagetotal",       "?????????",    SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "TYPE|BOOK",    ALWAYS, LEVEL_MAIN },
	{ " ",               "RESOURCE|text",ALWAYS, LEVEL_MAIN },
	{ " ",               "ISSUANCE|monographic", ALWAYS, LEVEL_MAIN },
	{ " ",               "GENRE|book",   ALWAYS, LEVEL_MAIN }
};

/* Part of a book (e.g. chapter or section) */

static lookups inbook[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "editor",          "EDITOR",       PERSON, LEVEL_HOST },
	{ "redactor",        "REDACTOR",     PERSON, LEVEL_HOST },
	{ "annotator",       "ANNOTATOR",    PERSON, LEVEL_HOST },
	{ "commentator",     "COMMENTATOR",  PERSON, LEVEL_HOST },
	{ "translator",      "TRANSLATOR",   PERSON, LEVEL_HOST },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "introduction",    "?????",        SIMPLE, LEVEL_HOST }, /*WRONG*/
	{ "foreward",        "?????",        SIMPLE, LEVEL_HOST }, /*WRONG*/
	{ "afterward",       "?????",        SIMPLE, LEVEL_HOST }, /*WRONG*/
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "maintitle",       "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "mainsubtitle",    "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "maintitleaddon",  "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "booktitle",       "TITLE",        SIMPLE, LEVEL_HOST },
	{ "booksubtitle",    "SUBTITLE",     SIMPLE, LEVEL_HOST },
	{ "booktitleaddon",  "??????",       SIMPLE, LEVEL_HOST },
	{ "bookauthor",      "AUTHOR",       PERSON, LEVEL_HOST },
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "origlanguage",    "LANGUAGE",     SIMPLE, LEVEL_ORIG },
	{ "origyear",        "YEAR",         SIMPLE, LEVEL_ORIG },
	{ "origtitle",       "TITLE",        SIMPLE, LEVEL_ORIG },
	{ "origlocation",    "LOCATION",     SIMPLE, LEVEL_ORIG },
	{ "origpublisher",   "PUBLISHER",    SIMPLE, LEVEL_ORIG },
	{ "volume",          "VOLUME",       SIMPLE, LEVEL_MAIN },
	{ "pages",           "PAGES",        PAGES,  LEVEL_MAIN },
	{ "part",            "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "edition",         "EDITION",      SIMPLE, LEVEL_MAIN },
	{ "volumes",         "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "series",          "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "isbn",            "ISBN",         SIMPLE, LEVEL_HOST },
	{ "chapter",         "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "TYPE|INBOOK",    ALWAYS, LEVEL_MAIN },
	{ " ",               "RESOURCE|text",ALWAYS, LEVEL_MAIN },
	{ " ",               "ISSUANCE|monographic", ALWAYS, LEVEL_HOST },
	{ " ",               "GENRE|book",   ALWAYS, LEVEL_HOST }
};

/* incollection */

static lookups incollection[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "editor",          "EDITOR",       PERSON, LEVEL_HOST },
	{ "redactor",        "REDACTOR",     PERSON, LEVEL_HOST },
	{ "annotator",       "ANNOTATOR",    PERSON, LEVEL_HOST },
	{ "commentator",     "COMMENTATOR",  PERSON, LEVEL_HOST },
	{ "translator",      "TRANSLATOR",   PERSON, LEVEL_HOST },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "introduction",    "?????",        SIMPLE, LEVEL_HOST }, /*WRONG*/
	{ "foreward",        "?????",        SIMPLE, LEVEL_HOST }, /*WRONG*/
	{ "afterward",       "?????",        SIMPLE, LEVEL_HOST }, /*WRONG*/
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "maintitle",       "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "mainsubtitle",    "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "maintitleaddon",  "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "booktitle",       "TITLE",        SIMPLE, LEVEL_HOST },
	{ "booksubtitle",    "SUBTITLE",     SIMPLE, LEVEL_HOST },
	{ "booktitleaddon",  "??????",       SIMPLE, LEVEL_HOST },
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "origlanguage",    "LANGUAGE",     SIMPLE, LEVEL_ORIG },
	{ "origyear",        "YEAR",         SIMPLE, LEVEL_ORIG },
	{ "origtitle",       "TITLE",        SIMPLE, LEVEL_ORIG },
	{ "origlocation",    "LOCATION",     SIMPLE, LEVEL_ORIG },
	{ "origpublisher",   "PUBLISHER",    SIMPLE, LEVEL_ORIG },
	{ "volume",          "VOLUME",       SIMPLE, LEVEL_HOST },
	{ "part",            "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "edition",         "EDITION",      SIMPLE, LEVEL_MAIN },
	{ "volumes",         "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "series",          "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_HOST },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_HOST },
	{ "isbn",            "ISBN",         SIMPLE, LEVEL_MAIN },
	{ "chapter",         "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pages",           "PAGES",        PAGES,  LEVEL_MAIN }, /* WRONG */
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "TYPE|INCOLLECTION",    ALWAYS, LEVEL_MAIN },
	{ " ",               "RESOURCE|text",ALWAYS, LEVEL_MAIN },
	{ " ",               "ISSUANCE|monographic", ALWAYS, LEVEL_MAIN },
	{ " ",               "GENRE|collection",   ALWAYS, LEVEL_HOST }
};

/* inproceedings */

static lookups inproceedings[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "editor",          "EDITOR",       PERSON, LEVEL_HOST },
	{ "redactor",        "REDACTOR",     PERSON, LEVEL_HOST },
	{ "annotator",       "ANNOTATOR",    PERSON, LEVEL_HOST },
	{ "commentator",     "COMMENTATOR",  PERSON, LEVEL_HOST },
	{ "translator",      "TRANSLATOR",   PERSON, LEVEL_HOST },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "introduction",    "?????",        SIMPLE, LEVEL_HOST }, /*WRONG*/
	{ "foreward",        "?????",        SIMPLE, LEVEL_HOST }, /*WRONG*/
	{ "afterward",       "?????",        SIMPLE, LEVEL_HOST }, /*WRONG*/
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "maintitle",       "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "mainsubtitle",    "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "maintitleaddon",  "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "booktitle",       "TITLE",        SIMPLE, LEVEL_HOST },
	{ "booksubtitle",    "SUBTITLE",     SIMPLE, LEVEL_HOST },
	{ "booktitleaddon",  "??????",       SIMPLE, LEVEL_HOST },
	{ "venue",           "??????",       SIMPLE, LEVEL_MAIN },
	{ "organization",    "???????",      SIMPLE, LEVEL_MAIN },
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "origlanguage",    "LANGUAGE",     SIMPLE, LEVEL_ORIG },
	{ "volume",          "VOLUME",       SIMPLE, LEVEL_HOST },
	{ "part",            "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "edition",         "EDITION",      SIMPLE, LEVEL_MAIN },
	{ "volumes",         "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "series",          "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_HOST },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_HOST },
	{ "isbn",            "ISBN",         SIMPLE, LEVEL_MAIN },
	{ "chapter",         "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pages",           "PAGES",        PAGES,  LEVEL_MAIN }, /* WRONG */
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "TYPE|INPROCEEDINGS",    ALWAYS, LEVEL_MAIN },
	{ " ",               "RESOURCE|text",ALWAYS, LEVEL_MAIN },
	{ " ",               "ISSUANCE|monographic", ALWAYS, LEVEL_MAIN },
	{ " ",               "GENRE|collection",   ALWAYS, LEVEL_HOST }
};

static lookups manual[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "editor",          "EDITOR",       PERSON, LEVEL_MAIN },
	{ "redactor",        "REDACTOR",     PERSON, LEVEL_MAIN },
	{ "annotator",       "ANNOTATOR",    PERSON, LEVEL_MAIN },
	{ "commentator",     "COMMENTATOR",  PERSON, LEVEL_MAIN },
	{ "translator",      "TRANSLATOR",   PERSON, LEVEL_MAIN },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "introduction",    "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "foreward",        "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "afterward",       "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "edition",         "EDITION",      SIMPLE, LEVEL_MAIN },
	{ "version",         "???????",      SIMPLE, LEVEL_MAIN },
	{ "type",            "?????",        SIMPLE, LEVEL_MAIN },
	{ "series",          "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "organization",    "?????????",    SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "isbn",            "ISBN",         SIMPLE, LEVEL_MAIN },
	{ "chapter",         "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pages",           "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pagetotal",       "?????????",    SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "TYPE|REPORT",       ALWAYS, LEVEL_MAIN },
	{ " ",               "RESOURCE|text",     ALWAYS, LEVEL_MAIN },
	{ " ",               "GENRE|instruction", ALWAYS, LEVEL_MAIN }
};

static lookups misc[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "editor",          "EDITOR",       PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "day",             "DAY",          SIMPLE, LEVEL_MAIN },
	{ "month",           "MONTH",        SIMPLE, LEVEL_MAIN },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "howpublished",    "????????",     SIMPLE, LEVEL_MAIN },
	{ "version",         "???????",      SIMPLE, LEVEL_MAIN },
	{ "type",            "TYPE",         SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "organization",    "?????????",    SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "TYPE|MISC",       ALWAYS, LEVEL_MAIN },
};

static lookups online[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "editor",          "EDITOR",       PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "date",            "?????",        SIMPLE, LEVEL_MAIN },
	{ "day",             "DAY",          SIMPLE, LEVEL_MAIN },
	{ "month",           "MONTH",        SIMPLE, LEVEL_MAIN },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "version",         "???????",      SIMPLE, LEVEL_MAIN },
	{ "type",            "?????",        SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "organization",    "?????????",    SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
        { " ",  "RESOURCE|software, multimedia",    ALWAYS, LEVEL_MAIN },
	{ " ",         "GENRE|web page",       ALWAYS, LEVEL_MAIN },
};

static lookups patent[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "holder",          "HOLDER",       PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "date",            "?????",        SIMPLE, LEVEL_MAIN },
	{ "day",             "DAY",          SIMPLE, LEVEL_MAIN },
	{ "month",           "MONTH",        SIMPLE, LEVEL_MAIN },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "version",         "???????",      SIMPLE, LEVEL_MAIN },
	{ "type",            "?????",        SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "organization",    "?????????",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "RESOURCE|text",   ALWAYS, LEVEL_MAIN },
	{ " ",               "TYPE|PATENT",    ALWAYS, LEVEL_MAIN },
	{ " ",               "GENRE|patent",    ALWAYS, LEVEL_MAIN },
};

/*
 * An entire issue of a periodical
 */
static lookups periodical[] = {
	{ "editor",          "EDITOR",       PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "issuetitle",      "TITLE",        SIMPLE, LEVEL_SERIES }, /*WRONG*/
	{ "issuesubtitle",   "SUBTITLE",     SIMPLE, LEVEL_SERIES }, /*WRONG*/
	{ "series",          "TITLE",        SIMPLE, LEVEL_SERIES },
	{ "volume",          "VOLUME",       SIMPLE, LEVEL_MAIN },
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "issue",           "ISSUE",        SIMPLE, LEVEL_MAIN },
	{ "date",            "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "day",             "PARTDAY",      SIMPLE, LEVEL_MAIN },
	{ "month",           "PARTMONTH",    SIMPLE, LEVEL_MAIN },
	{ "year",            "PARTYEAR",     SIMPLE, LEVEL_MAIN },
	{ "pages",           "PAGES",        PAGES,  LEVEL_MAIN },
	{ "note",            "NOTES",        SIMPLE, LEVEL_MAIN },
	{ "issn",            "ISSN",         SIMPLE, LEVEL_HOST },
	{ "addendum",        "?????",        SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "eprinttype",      "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "url",             "URL",          BIBTEX_URL, LEVEL_MAIN },
	{ "urldate",         "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "urlday",          "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "urlmonth",        "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "urlyear",         "?????",        SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",            "ISSUANCE|continuing",    ALWAYS, LEVEL_MAIN },
	{ " ",            "RESOURCE|text",          ALWAYS, LEVEL_MAIN },
	{ " ",            "GENRE|periodical",       ALWAYS, LEVEL_MAIN }
};

static lookups proceedings[] = {
	{ "editor",          "EDITOR",       PERSON, LEVEL_MAIN },
	{ "redactor",        "REDACTOR",     PERSON, LEVEL_MAIN },
	{ "annotator",       "ANNOTATOR",    PERSON, LEVEL_MAIN },
	{ "commentator",     "COMMENTATOR",  PERSON, LEVEL_MAIN },
	{ "translator",      "TRANSLATOR",   PERSON, LEVEL_MAIN },
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "introduction",    "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "foreward",        "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "afterward",       "?????",        SIMPLE, LEVEL_MAIN }, /*WRONG*/
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "maintitle",       "TITLE",        SIMPLE, LEVEL_HOST },
	{ "mainsubtitle",    "SUBTITLE",     SIMPLE, LEVEL_HOST },
	{ "maintitleaddon",  "?????",        SIMPLE, LEVEL_HOST },   /*WRONG*/
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "origlanguage",    "LANGUAGE",     SIMPLE, LEVEL_ORIG },
	{ "volume",          "VOLUME",       SIMPLE, LEVEL_HOST },
	{ "part",            "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "edition",         "EDITION",      SIMPLE, LEVEL_MAIN },
	{ "volumes",         "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "series",          "?????",        SIMPLE, LEVEL_HOST }, /* WRONG */
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "organization",    "ORGANIZATION", SIMPLE, LEVEL_MAIN },
	{ "publisher",       "PUBLISHER",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "isbn",            "ISBN",         SIMPLE, LEVEL_MAIN },
	{ "chapter",         "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pages",           "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pagetotal",       "?????????",    SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",               "TYPE|BOOK",    ALWAYS, LEVEL_MAIN },
        { " ",         "RESOURCE|text",       ALWAYS, LEVEL_MAIN },
        { " ",         "GENRE|conference publication",   ALWAYS, LEVEL_MAIN }
};



/* Technical reports */
static lookups report[] = {
	{ "author",          "AUTHOR",       PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "year",            "YEAR",         SIMPLE, LEVEL_MAIN },
	{ "language",        "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "number",          "NUMBER",       SIMPLE, LEVEL_MAIN },
	{ "note",            "NOTE",         SIMPLE, LEVEL_MAIN },
	{ "version",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "location",        "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "isrn",            "ISRN",         SIMPLE, LEVEL_MAIN },
	{ "chapter",         "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pages",           "?????????",    SIMPLE, LEVEL_MAIN }, /* WRONG */
	{ "pagetotal",       "?????????",    SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "doi",             "DOI",          SIMPLE, LEVEL_MAIN },
	{ "eprint",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "eprinttype",      "?????????",    SIMPLE, LEVEL_MAIN },
	{ "url",             "URL",          SIMPLE, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",         "TYPE|REPORT",     ALWAYS, LEVEL_MAIN },
	{ " ",         "RESOURCE|text",   ALWAYS, LEVEL_MAIN },
	{ " ",         "GENRE|report",    ALWAYS, LEVEL_MAIN }
};

static lookups thesis[] = {
	{ "author",    "AUTHOR",    PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "year",      "YEAR",      SIMPLE, LEVEL_MAIN },
	{ "month",     "MONTH",     SIMPLE, LEVEL_MAIN },
	{ "day",       "DAY",       SIMPLE, LEVEL_MAIN },
	{ "type",      "GENRE",     SIMPLE, LEVEL_MAIN },
	{ "institution","DEGREEGRANTOR:ASIS",SIMPLE, LEVEL_MAIN },
	{ "doi",       "DOI",       SIMPLE, LEVEL_MAIN },
	{ "url",       "URL",       BIBTEX_URL, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "language",     "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "location",     "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "note",         "NOTES",        SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",         "TYPE|THESIS",   ALWAYS, LEVEL_MAIN },
	{ " ",         "RESOURCE|text", ALWAYS, LEVEL_MAIN },
	{ " ",         "GENRE|thesis",  ALWAYS, LEVEL_MAIN },
};

/* Unpublished */
static lookups unpublished[] = {
	{ "author",    "AUTHOR",    PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "howpublished", "??????", SIMPLE, LEVEL_MAIN },
	{ "year",      "YEAR",      SIMPLE, LEVEL_MAIN },
	{ "month",     "MONTH",     SIMPLE, LEVEL_MAIN },
	{ "day",       "DAY",       SIMPLE, LEVEL_MAIN },
	{ "date",      "????",      SIMPLE, LEVEL_MAIN },
	{ "url",       "URL",       BIBTEX_URL, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "language",     "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "note",         "NOTES",        SIMPLE, LEVEL_MAIN },
	{ "addendum",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",         "TYPE|BOOK",       ALWAYS, LEVEL_MAIN },
	{ " ",         "RESOURCE|text",   ALWAYS, LEVEL_MAIN },
	{ " ",         "GENRE|unpublished",      ALWAYS, LEVEL_MAIN }
};

static lookups phdthesis[] = {
	{ "author",    "AUTHOR",    PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "year",      "YEAR",      SIMPLE, LEVEL_MAIN },
	{ "month",     "MONTH",     SIMPLE, LEVEL_MAIN },
	{ "day",       "DAY",       SIMPLE, LEVEL_MAIN },
	{ "type",      "GENRE",     SIMPLE, LEVEL_MAIN },
	{ "institution","DEGREEGRANTOR:ASIS",SIMPLE, LEVEL_MAIN },
	{ "doi",       "DOI",       SIMPLE, LEVEL_MAIN },
	{ "url",       "URL",       BIBTEX_URL, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "language",     "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "location",     "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "note",         "NOTES",        SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",         "TYPE|THESIS",   ALWAYS, LEVEL_MAIN },
	{ " ",         "RESOURCE|text", ALWAYS, LEVEL_MAIN },
	{ " ",         "GENRE|thesis",  ALWAYS, LEVEL_MAIN },
	{ " ",         "GENRE|Ph.D. thesis",  ALWAYS, LEVEL_MAIN }
};

static lookups mastersthesis[] = {
	{ "author",    "AUTHOR",    PERSON, LEVEL_MAIN },
	{ "title",           "TITLE",        SIMPLE, LEVEL_MAIN },
	{ "subtitle",        "SUBTITLE",     SIMPLE, LEVEL_MAIN },
	{ "titleaddon",      "?????",        SIMPLE, LEVEL_MAIN },   /*WRONG*/
	{ "year",      "YEAR",      SIMPLE, LEVEL_MAIN },
	{ "month",     "MONTH",     SIMPLE, LEVEL_MAIN },
	{ "day",       "DAY",       SIMPLE, LEVEL_MAIN },
	{ "type",      "GENRE",     SIMPLE, LEVEL_MAIN },
	{ "institution","DEGREEGRANTOR:ASIS",SIMPLE, LEVEL_MAIN },
	{ "doi",       "DOI",       SIMPLE, LEVEL_MAIN },
	{ "url",       "URL",       BIBTEX_URL, LEVEL_MAIN },
	{ "urldate",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlday",          "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlmonth",        "?????????",    SIMPLE, LEVEL_MAIN },
	{ "urlyear",         "?????????",    SIMPLE, LEVEL_MAIN },
	{ "language",     "LANGUAGE",     SIMPLE, LEVEL_MAIN },
	{ "location",     "LOCATION",     SIMPLE, LEVEL_MAIN },
	{ "note",         "NOTES",        SIMPLE, LEVEL_MAIN },
	{ "address",         "ADDRESS",      SIMPLE, LEVEL_MAIN },
	{ "refnum",          "REFNUM",       SIMPLE, LEVEL_MAIN },
	{ " ",         "TYPE|THESIS",   ALWAYS, LEVEL_MAIN },
	{ " ",         "RESOURCE|text", ALWAYS, LEVEL_MAIN },
	{ " ",         "GENRE|thesis",  ALWAYS, LEVEL_MAIN },
	{ " ",         "GENRE|Masters thesis",  ALWAYS, LEVEL_MAIN },
};

#define ORIG(a) ( &(a[0]) )
#define SIZE(a) ( sizeof( a ) / sizeof( lookups ) )
#define REFTYPE(a,b) { a, ORIG(b), SIZE(b) }

variants biblatex_all[] = {
	REFTYPE( "article", article ),
	REFTYPE( "booklet", booklet ),
	REFTYPE( "book", book ),
	REFTYPE( "collection", collection ),
	REFTYPE( "inbook", inbook ),
	REFTYPE( "incollection", incollection ),
	REFTYPE( "inproceedings", inproceedings ),
	REFTYPE( "conference", inproceedings ), /* legacy */
	REFTYPE( "manual", manual ),
	REFTYPE( "misc", misc ),
	REFTYPE( "online", online ),
	REFTYPE( "electronic", online ), /* legacy */
	REFTYPE( "www", online ),        /* jurabib compatibility */
	REFTYPE( "patent", patent ),
	REFTYPE( "periodical", periodical ),
	REFTYPE( "proceedings", proceedings ),
	REFTYPE( "report", report ),
	REFTYPE( "techreport", report ),
/*	REFTYPE( "set", set ), */
	REFTYPE( "thesis", thesis ),
	REFTYPE( "phdthesis", phdthesis ), /* legacy */
	REFTYPE( "mastersthesis", mastersthesis ), /* legacy */
	REFTYPE( "unpublished", unpublished ),
};

int biblatex_nall = sizeof( biblatex_all ) / sizeof( variants );
