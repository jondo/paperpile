#include <stdio.h>
#include <stdlib.h>
#include "perlwrapper.h"
#include "bibutils.h"

int last_error=BIBL_OK;

int c_get_error(){
  return last_error;
}

int c_get_n_entries(bibl* b){
  return b->nrefs;
}

int c_get_n_fields(bibl* b, int index){
  return b->ref[index]->nfields;
}

char* c_get_field_tag(bibl* b, int index1, int index2){
  return(b->ref[index1]->tag[index2].data);
}

char* c_get_field_data(bibl* b, int index1, int index2){
  return(b->ref[index1]->data[index2].data);
}

int c_get_field_level(bibl* b, int index1, int index2){
  return(b->ref[index1]->level[index2]);
}

bibl* c_new(){
  bibl *b;
  b=(bibl*)malloc(sizeof(bibl));
  bibl_init( b );
  return b;
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


