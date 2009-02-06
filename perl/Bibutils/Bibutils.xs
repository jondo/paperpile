#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "bibutils/perlwrapper.h"
#include "bibutils/bibutils.h"


MODULE = Bibutils		PACKAGE = Bibutils		

PROTOTYPES: ENABLE


int c_get_n_entries(b)
   bibl* b

int c_get_n_fields(b, index)
  bibl* b
  int index

bibl* c_read(file, format)
   const char * file
   int format

void c_write(file, format, b)
   const char * file
   int format
   bibl * b

char* c_get_field_tag(b, index1, index2)
   bibl* b
   int index1
   int index2

char* c_get_field_data(b, index1, index2)
   bibl* b
   int index1
   int index2

int c_get_field_level(b, index1, index2)
   bibl* b
   int index1
   int index2

bibl* c_new()

int c_get_error()

void bibl_free(b)
     bibl *b 

fields *fields_new();   

int fields_add(info, tag, data, level )
   fields *info
   char *tag
   char *data
   int level 

void bibl_addref( b, ref )
     bibl *b 
     fields *ref 