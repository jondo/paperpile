#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "bibutils/perlwrapper.h"
#include "bibutils/bibutils.h"

#include "const-c.inc"

MODULE = Bibutils		PACKAGE = Bibutils		

PROTOTYPES: ENABLE

INCLUDE: const-xs.inc

int
hello()

TestStruct *
test()

int 
getField(t)
   TestStruct* t

bibl* 
c_read(file, format)
   const char * file
   int format

void
c_write(file, format, b)
   const char * file
   int format
   bibl * b

int 
c_get_error()
