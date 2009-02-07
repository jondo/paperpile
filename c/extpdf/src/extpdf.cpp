#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "config.h"
#include "poppler.h"
#include "cairo.h"

int render(char* uri, int pageNo, float scale);
int search(char* uri, char* term);
int text(char* uri, int pageNo, float x1, float y1, float x2, float y2);

void usage();
void fail(char* msg);

int main (int argc, char *argv[]){

  gchar *uri;
  GError *error;

  g_type_init ();

  /* At least two parameters are always required */
  if (argc <= 2){
    usage();
  }

  /* glib needs absolute uri of file */
  error = NULL;
  if (g_ascii_strncasecmp (argv[argc-1], "file://", strlen ("file://")) == 0) {
    uri = g_strdup (argv[argc-1]);
  } else {
    uri = g_filename_to_uri (argv[argc-1], NULL, &error);
    if (error) {
      fail(error->message);
    }
  }

  /* Renders page to png */
  
  if (strcmp(argv[1],"RENDER")==0){
    if (argc != 5){
      usage();
    }
    if (render(uri, atoi(argv[2]), atof(argv[3]))){
      exit(0);
    } else {
      exit(1);
    }
  }

  /* Search text and get coordinates of all matches */

  if (strcmp(argv[1],"SEARCH")==0){
    if (argc != 4){
      usage();
    }
    if (search(uri, argv[2])){
      exit(0);
    } else {
      exit(1);
    }
  }

  /* Get text in selection */
  
  if (strcmp(argv[1],"TEXT")==0){
    
    if (argc != 8){
      usage();
    }

    if (text(uri, atoi(argv[2]), atof(argv[3]), atof(argv[4]), atof(argv[5]), atof(argv[6]))){
      exit(0);
    } else {
      exit(1);
    }
  }

  /* No command was recognized */
  usage();

}

void usage(){
  fprintf(stderr, "Usage: extpdf COMMAND PARAMETERS\n");
  fprintf(stderr, "       extpdf RENDER page scale file\n");
  fprintf(stderr, "       exptdf SEARCH \"searchterm\" file\n");
  fprintf(stderr, "       exptdf TEXT page x1 y1 x2 y2 file\n");
  exit(1);
}

void fail(char* msg){
  fprintf (stderr, "%s\n", msg); 
  exit (-1); 
}

int render(char* uri, int pageNo, float scale){

  PopplerDocument *document;
  PopplerPage *page;
  GError *error;
  double width, height;
  double duration;
  GTimer      *timer;
  cairo_surface_t *surface;
  cairo_t *cr;

  timer = g_timer_new ();
  
  document = poppler_document_new_from_file (uri, NULL, &error);
  
  printf("Page loaded in %.4f seconds\n",g_timer_elapsed (timer, NULL)); 
  timer = g_timer_new ();

  if (document == NULL){
    fail(error->message);
  }

  page = poppler_document_get_page(document, pageNo);
  if (page == NULL){
    fail("Page not found");
  }

  poppler_page_get_size (page, &width, &height);

  surface = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, width*scale, height*scale);
  cr = cairo_create (surface);

  if (scale != 1.0){
    cairo_scale (cr, scale, scale);
  }

  poppler_page_render(page,cr);     

  printf("Page rendered by poppler in %.4f seconds\n",g_timer_elapsed (timer, NULL));
  timer = g_timer_new ();
  
  cairo_surface_write_to_png(surface,"/home/wash/test.png");
  cairo_destroy (cr);

  printf("Page written to png by cairo in %.4f seconds\n",g_timer_elapsed (timer, NULL));

  g_object_unref (G_OBJECT (page));
  g_object_unref (G_OBJECT (document));

  return 1;

}

int search(char* uri, char* term){
  
  GList *list, *l;
  GError *error;
  PopplerDocument *document;
  PopplerPage *page;
  int N,i;

  document = poppler_document_new_from_file (uri, NULL, &error);

  N=poppler_document_get_n_pages(document);

  for (i=0; i < N; ++i){
    page = poppler_document_get_page(document, i);
    list = poppler_page_find_text (page, term);
    
    for (l = list; l != NULL; l = l->next){
      PopplerRectangle *rect = (PopplerRectangle *)l->data;
      printf ("%i %.4f %.4f %.4f %.4f\n", i, rect->x1, rect->y1, rect->x2, rect->y2);
    }
  }

}

int text(char* uri, int pageNo, float x1, float y1, float x2, float y2){  

  PopplerRectangle area;
  GError *error;
  PopplerDocument *document;
  PopplerPage *page;
  char *text;

  document = poppler_document_new_from_file (uri, NULL, &error);
  page = poppler_document_get_page(document, pageNo);

  area.x1 = x1;
  area.y1 = y1;
  area.x2 = x2;
  area.y2 = y2;

  text = poppler_page_get_text (page, POPPLER_SELECTION_LINE, &area);
  
  printf("%s\n",text);

  return 1;
   
}



