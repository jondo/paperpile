#include <stdio.h>
#include <stdlib.h>
#include "perlwrapper.h"
#include "bibutils.h"


int hello(){
  
  return 1;

}

int last_error=BIBL_OK;

int c_get_error(){
  return last_error;
}

bibl* c_read(const char *file, int format){
  
  bibl* bibliography;
  param bibparams;
  int err;
  int i,j;
  fields* entry;
  newstr content;
  FILE *fh;

  fh=fopen(file, "r");

  if (fh == NULL){
    last_error=BIBL_ERR_CANTOPEN;
    return NULL;
  }

  bibliography=(bibl*) malloc(sizeof(bibl));
  
  fprintf(stderr, "Reading %s in format %i", file, format);

  bibl_initparams( &bibparams, BIBL_MODSIN, BIBL_BIBTEXOUT, "program name" );
  bibl_init( bibliography );
  err = bibl_read( bibliography, fh, "stdin", &bibparams );

  last_error=err;

  printf("Items read: %lu\n", bibliography->nrefs);

  /*
  for (i=0;i<bibliography.nrefs;i++){
    entry=bibliography.ref[i];
    printf("  Number of fields: %i\n", entry->nfields);
    for (j=0;j<entry->nfields;j++){
      printf("    %s => %s (level: %i)\n", 
             entry->tag[j].data, 
             entry->data[j].data,
             entry->level[j]
             );
    }
  }
  */
  
  return(bibliography);


}

void c_write(const char *file, int format, bibl* b){

  param bibparams;
  int err;

  bibl_initparams( &bibparams, BIBL_MODSIN, BIBL_BIBTEXOUT, "program name" );
  
  err = bibl_write( b, stdout, &bibparams );

}


TestStruct* test(){
  TestStruct* t;
  t=(TestStruct*)malloc(sizeof(TestStruct));
  t->number=2;
  return t;
}

int getField(TestStruct* t){
  return t->number;
}
