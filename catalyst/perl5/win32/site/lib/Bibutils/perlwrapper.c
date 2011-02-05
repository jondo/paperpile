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
  
  bibl_initparams( &bibparams, format, BIBL_MODSOUT, "Perl bindings for Bibutils" );
  bibl_init( bibliography );
  last_error = bibl_read( bibliography, fh, "stdin", &bibparams );

  return(bibliography);


}


void c_write(const char *file, int format, bibl* b, 
             int charsetout, unsigned char latexout, unsigned char utf8out, 
             unsigned char xmlout, int format_opts){
  
  param bibparams;
  int err;
  FILE *fh;

  fh=fopen(file, "w");

  if (fh == NULL){
    last_error=BIBL_ERR_CANTOPEN;
    return NULL;
  }

  bibl_initparams( &bibparams, BIBL_MODSIN, format, "Perl bindings for Bibutils" );

  if (charsetout != 999){
    bibparams.latexout=latexout;
  }

  if (latexout != 999){
    bibparams.latexout=latexout;
  }

  if (utf8out != 999){
    bibparams.utf8out=latexout;
  }

  if (xmlout != 999){
    bibparams.utf8out=latexout;
  }
    
  if (format_opts != 999){
    bibparams.format_opts=format_opts;
  }


  
  last_error = bibl_write( b, fh, &bibparams );

}




