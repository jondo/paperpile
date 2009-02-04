#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "config.h"
#include "poppler.h"
#include "cairo.h"

int render(char* uri, int pageNo, float scale);
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

  if (strcmp(argv[1],"render")==0){
    
    if (argc != 5){
      usage();
    }

    render(uri, atoi(argv[2]), atof(argv[3]));

  } else {
    usage();
  }

}

void usage(){
  fprintf(stderr, "\nusage: extpdf COMMAND PARAMETERS\n");
  exit(1);
}

void fail(char* msg){
  fprintf (stderr, "%s\n", msg); 
  exit (-1); 
}

int render(char* uri, int pageNo, float scale){

  PopplerDocument *document;
  PopplerBackend backend;
  PopplerPage *page;
  GEnumValue *enum_value;
  GError *error;
  double width, height;
  GList *list, *l;
  char *text;
  double duration;
  PopplerRectangle area;
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

  cairo_surface_write_to_png(surface,"/home/wash/test.png");
  cairo_destroy (cr);

  printf("Page rendered in %.4f seconds\n",g_timer_elapsed (timer, NULL));

  /*
  area.x1 = 0;
  area.y1 = 0;
  area.x2 = width;
  area.y2 = height;

  text = poppler_page_get_text (page, POPPLER_SELECTION_GLYPH, &area);
  if (text)
    {
      FILE *file = fopen ("dump.txt", "w");
      if (file)
	{
	  fwrite (text, strlen (text), 1, file);
	  fclose (file);
	}
      g_free (text);
    }

  list = poppler_page_find_text (page, "and");
  printf ("\n");  
  printf ("\tFound text \"Bitwise\" at positions:\n");
  for (l = list; l != NULL; l = l->next)
    {
      PopplerRectangle *rect = (PopplerRectangle *)l->data;

      printf ("  (%f,%f)-(%f,%f)\n", rect->x1, rect->y1, rect->x2, rect->y2);
    }

  */

  g_object_unref (G_OBJECT (page));
  g_object_unref (G_OBJECT (document));

  return 1;

}
