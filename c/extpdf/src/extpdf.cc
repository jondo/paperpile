#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "config.h"
#include "poppler.h"
#include "cairo.h"

#include "extpdf.h"
#include "viewer.h"
#include "annotation.h"

int main (int argc, char *argv[]){

  mxml_node_t *xml;
  mxml_node_t *node;
  mxml_node_t *xmlout;
  
  FILE *fp;
  char command[100];

  g_type_init ();
  
  if (argc > 2){
    usage();
  }

  if (argc == 1 ){
    fp=stdin;
  } else {
    fp = fopen(argv[1], "r");
    if (fp == NULL){
      fail("Could not open control file.\n");
    }
  }

  xml = mxmlLoadFile(NULL, fp, MXML_OPAQUE_CALLBACK);
  fclose(fp);

  if (xml==NULL){
    fail("Could not read control file\n");
  }

  node = mxmlFindElement(xml, xml, "command", NULL, NULL, MXML_DESCEND);

  if (node == NULL){
    fail("The control file must specify a command.");
  }

  sprintf(command,"%s",node->child->value.opaque);

  if (strcmp(command,"INFO")==0)  xmlout=info(xml);
  if (strcmp(command,"RENDER")==0)  xmlout=render(xml);
  if (strcmp(command,"SEARCH")==0)  xmlout=search(xml);
  
  
  mxmlSaveFile (xmlout,stdout,_white_space_cb);

  
}

void usage(){
  fprintf(stderr, "Usage: extpdf COMMAND PARAMETERS\n");
  fprintf(stderr, "       extpdf RENDER page scale file\n");
  fprintf(stderr, "       exptdf SEARCH \"searchterm\" file\n");
  fprintf(stderr, "       exptdf SELECT page x1 y1 x2 y2 file\n");
  fprintf(stderr, "       exptdf TEXT page x1 y1 x2 y2 file\n");
  fprintf(stderr, "       exptdf ADD_STICKY page left bottom width height \"Text\" file\n");
  fprintf(stderr, "       exptdf ADD_HIGHLIGHT page x1 y1 x2 y2 file\n");
  exit(1);
}

void fail(const char* msg){

  mxml_node_t *xmlout;
  mxml_node_t *output_tag;
  mxml_node_t *error_tag;
  mxml_node_t *status_tag;

  xmlout = mxmlNewXML("1.0");
  output_tag = mxmlNewElement(xmlout, "output");
  status_tag = mxmlNewElement(output_tag, "status");
  mxmlNewOpaque(status_tag, "ERROR");
  error_tag = mxmlNewElement(output_tag, "error");
  mxmlNewOpaque(error_tag, msg);
  mxmlSaveFile (xmlout,stdout,_white_space_cb);

  exit (-1); 
}



gchar* get_uri(gchar* file){

  GError *error;
  gchar *uri;
  gchar* file_abs;

  error = NULL;


  if (!g_path_is_absolute (file)){
    file_abs=g_build_filename(g_get_current_dir(), file, NULL);
  } else {
    file_abs=file;
  }
  
  uri = g_filename_to_uri (file_abs, NULL, &error);
  if (error) {
    fail(error->message);
  }
 
  return uri;

}

 
const char * _white_space_cb(mxml_node_t *node, int where){
  const char *name;

  name = node->value.element.name;
  
  if (!strcmp(name, "output") || !strcmp(name, "status") || !strcmp(name, "page")){
    if (where == MXML_WS_BEFORE_OPEN || where == MXML_WS_AFTER_CLOSE){
      return ("\n");
    }
  } else {
    if (where == MXML_WS_AFTER_CLOSE){
      return ("\n");
    }
  }
  return (NULL);
}





