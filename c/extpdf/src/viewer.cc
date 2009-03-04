#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "config.h"
#include "poppler.h"
#include "cairo.h"
#include <podofo.h>

#include "extpdf.h"
#include "viewer.h"

#include <goo/GooString.h>
#include <goo/gmem.h>
#include <GlobalParams.h>
#include <Object.h>
#include <Stream.h>
#include <Array.h>
#include <Dict.h>
#include <XRef.h>
#include <Catalog.h>
#include <Page.h>
#include <PDFDoc.h>
#include <TextOutputDev.h>
#include <CairoOutputDev.h>
#include <CharTypes.h>
#include <UnicodeMap.h>
#include <Error.h>



mxml_node_t* info(mxml_node_t *xml){

  PopplerDocument *document;
  PopplerPage *page;
  GError *error;
  GTimer *timer;
  cairo_surface_t *surface;
  cairo_t *cr;
  mxml_node_t *node;
  char *in_file, *out_file, *uri;
  int pageNo;
  float scale;
  double width, height;
  char string[1000];
  int i;
  mxml_node_t *xmlout, *output_tag, *status_tag, *page_tag, *some_tag;
  
  node = mxmlFindElement(xml, xml, "inFile", NULL, NULL, MXML_DESCEND);
  in_file=node->child->value.opaque;

  uri=get_uri(in_file);
  
  document = poppler_document_new_from_file (uri, NULL, &error);
  
  if (document == NULL){
    fail("Could not open file");
  }

  xmlout = mxmlNewXML("1.0");
  output_tag = mxmlNewElement(xmlout, "output");
  status_tag = mxmlNewElement(output_tag, "status");
  mxmlNewOpaque(status_tag, "OK");
  some_tag = mxmlNewElement(output_tag, "pageNo");
  sprintf(string,"%i", poppler_document_get_n_pages(document));
  mxmlNewOpaque(some_tag,string );
  
  for (i=0;i<poppler_document_get_n_pages(document);i++){
    page = poppler_document_get_page(document, i);
    if (page == NULL){
      fail("Failed to read page.");
    }
    poppler_page_get_size (page, &width, &height);
    page_tag = mxmlNewElement(output_tag, "page");
    some_tag = mxmlNewElement(page_tag, "width");
    sprintf(string,"%.2f", width);
    mxmlNewOpaque(some_tag,string);
    some_tag = mxmlNewElement(page_tag, "height");
    sprintf(string,"%.2f", height);
    mxmlNewOpaque(some_tag,string);
  }

  return xmlout;

}

mxml_node_t* render(mxml_node_t *xml){

  PopplerDocument *document;
  PopplerPage *page;
  GError *error;
  GTimer *timer;
  cairo_surface_t *surface;
  cairo_t *cr;
  mxml_node_t *node;
  char *in_file, *out_file, *uri;
  int pageNo;
  float scale;
  double width, height;
  mxml_node_t *xmlout, *output_tag, *status_tag;

  PDFDoc *newDoc;
  Page *myPage;
  GooString *filename_g;
  GooString *password_g;
  char *filename;
  Gfx *gfx;
  Catalog *catalog;
  TextWordList *list;
  TextWord *word;
  CairoOutputDev* output_dev;
  
  node = mxmlFindElement(xml, xml, "inFile", NULL, NULL, MXML_DESCEND);
  in_file=node->child->value.opaque;
  node = mxmlFindElement(xml, xml, "outFile", NULL, NULL, MXML_DESCEND);
  out_file=node->child->value.opaque;
  node = mxmlFindElement(xml, xml, "page", NULL, NULL, MXML_DESCEND);
  pageNo=atoi(node->child->value.opaque);
  node = mxmlFindElement(xml, xml, "scale", NULL, NULL, MXML_DESCEND);
  scale=atof(node->child->value.opaque);

  //printf("Rendering page %i of %s at scale %f to %s\n",pageNo, in_file, scale, out_file); 

  uri=get_uri(in_file);
  timer = g_timer_new ();
  document = poppler_document_new_from_file (uri, NULL, &error);
  
  if (document == NULL){
    fail("Could not open file");
  }

  //printf("Page loaded in %.4f seconds\n",g_timer_elapsed (timer, NULL)); 
  timer = g_timer_new ();


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

  //printf("Page rendered by poppler in %.4f seconds\n",g_timer_elapsed (timer, NULL));
  timer = g_timer_new ();
  
  if (strcmp(out_file,"STDOUT")==0){
    //cairo_surface_write_to_png(surface,stdout);
    cairo_surface_write_to_png_stream (surface, write_png_stream,NULL);
    
    exit(0);
  }

  cairo_surface_write_to_png(surface,out_file);
  cairo_destroy (cr);

  //printf("Page written to png by cairo in %.4f seconds\n",g_timer_elapsed (timer, NULL));

  g_object_unref (G_OBJECT (page));
  g_object_unref (G_OBJECT (document));

  xmlout = mxmlNewXML("1.0");
  output_tag = mxmlNewElement(xmlout, "output");
  status_tag = mxmlNewElement(output_tag, "status");
  mxmlNewOpaque(status_tag, "OK");


  if (!globalParams) {
    globalParams = new GlobalParams();
  }

  filename_g = new GooString (in_file);
  newDoc = new PDFDoc(filename_g, NULL, NULL);
    
  catalog = newDoc->getCatalog();
  myPage = catalog->getPage (pageNo);

  surface = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, width*scale, height*scale);
  cr = cairo_create (surface);

  if (scale != 1.0){
    cairo_scale (cr, scale, scale);
  }

  output_dev = new CairoOutputDev ();
  output_dev->startDoc(newDoc->getXRef ());
  output_dev->setCairo (cr);
  output_dev->setPrinting (0);

  cairo_save (cr);

  myPage->displaySlice(output_dev,
                       72.0, 72.0, 0,
                       gFalse, /* useMediaBox */
                       gTrue, /* Crop */
                       -1, -1,
                       -1, -1,
                       0,
                       catalog,
                       NULL, NULL,
                       NULL, NULL);
  cairo_restore (cr);

  output_dev->setCairo (NULL);	

  cairo_surface_write_to_png(surface,"tmp.png");
  cairo_destroy (cr);

  return xmlout;

}

mxml_node_t* search(mxml_node_t *xml){
  //int search(char* uri, char* term){
  
  GList *list, *l;
  GError *error;
  PopplerDocument *document;
  PopplerPage *page;
  int N,i;
  char *in_file, *uri;
  char *term;
  char string[1000];
  mxml_node_t *node;
  mxml_node_t *xmlout, *output_tag, *status_tag, *hit_tag;

  node = mxmlFindElement(xml, xml, "inFile", NULL, NULL, MXML_DESCEND);
  in_file=node->child->value.opaque;

  node = mxmlFindElement(xml, xml, "term", NULL, NULL, MXML_DESCEND);
  term=node->child->value.opaque;

  uri=get_uri(in_file);

  document = poppler_document_new_from_file (uri, NULL, &error);

  if (document == NULL){
    fail("Could not open file");
  }

  xmlout = mxmlNewXML("1.0");
  output_tag = mxmlNewElement(xmlout, "output");
  status_tag = mxmlNewElement(output_tag, "status");
  mxmlNewOpaque(status_tag, "OK");

  N=poppler_document_get_n_pages(document);
    
  for (i=0; i < N; ++i){
    page = poppler_document_get_page(document, i);
    list = poppler_page_find_text (page, term);
    
    for (l = list; l != NULL; l = l->next){
      PopplerRectangle *rect = (PopplerRectangle *)l->data;
      hit_tag = mxmlNewElement(output_tag, "hit");
      sprintf(string,"%i",i);
      mxmlElementSetAttr (hit_tag, "page",string);
      sprintf (string,"%i %.2f %.2f %.2f %.2f", i, rect->x1, rect->y1, rect->x2, rect->y2);
      mxmlNewOpaque(hit_tag, string);
    }
  }

  return(xmlout);

}


mxml_node_t* wordList(mxml_node_t *xml){
  //int select(char* uri, int pageNo, float x1, float y1, float x2, float y2){  

  PopplerRectangle area;
  GError *error;
  int i;
  char *in_file;
  char string[1000];
  char type[100];
  int pageNo;
  double x1, y1, x2, y2;
  mxml_node_t *node;
  mxml_node_t *xmlout, *output_tag, *status_tag, *word_tag;
  TextOutputDev *text_dev;
  
  PDFDoc *newDoc;
  Page *myPage;
  GooString *filename_g;
  GooString *password_g;
  char *filename;
  Gfx *gfx;
  Catalog *catalog;
  TextWordList *list;
  TextWord *word;

  node = mxmlFindElement(xml, xml, "inFile", NULL, NULL, MXML_DESCEND);
  in_file=node->child->value.opaque;
  node = mxmlFindElement(xml, xml, "page", NULL, NULL, MXML_DESCEND);
  pageNo=atoi(node->child->value.opaque);

  if (!globalParams) {
    globalParams = new GlobalParams();
  }

  filename_g = new GooString (in_file);
  newDoc = new PDFDoc(filename_g, NULL, NULL);

  catalog = newDoc->getCatalog();
  myPage = catalog->getPage (pageNo);

  /* code to get text_dev similar to poppler-page.cc */
  text_dev=new TextOutputDev(NULL, gTrue,gFalse,gFalse);

  if (text_dev->isOk()) {
    gfx=myPage->createGfx(text_dev,
                          72.0, 72.0, 0,
                          gFalse,
                          gTrue,
                          -1, -1, -1, -1,
                          gFalse,
                          newDoc->getCatalog (),
                          NULL, NULL, NULL, NULL);
    myPage->display(gfx);
    text_dev->endPage();
  }

  list=text_dev->makeWordList();

  xmlout = mxmlNewXML("1.0");
  output_tag = mxmlNewElement(xmlout, "output");
  status_tag = mxmlNewElement(output_tag, "status");
  mxmlNewOpaque(status_tag, "OK");

  for (i=0; i<list->getLength();i++){
    word=list->get(i);
    word->getBBox(&x1,&y1,&x2,&y2);
    word_tag = mxmlNewElement(output_tag, "word");
    mxmlElementSetAttr(word_tag, "text", word->getText()->getCString());
    sprintf(string, "%.2f,%.2f,%.2f,%.2f\n", x1,y1,x2,y2);
    mxmlNewOpaque(word_tag, string);
  }

  return xmlout;
}


mxml_node_t* text(mxml_node_t *xml){

  //int text(char* uri, int pageNo, float x1, float y1, float x2, float y2){  

  PopplerRectangle area;
  GError *error;
  PopplerDocument *document;
  PopplerPage *page;
  char *text;

  char *uri;
  int pageNo;
  float x1, y1, x2, y2;

  document = poppler_document_new_from_file (uri, NULL, &error);
  page = poppler_document_get_page(document, pageNo);

  area.x1 = x1;
  area.y1 = y1;
  area.x2 = x2;
  area.y2 = y2;

  text = poppler_page_get_text (page, POPPLER_SELECTION_WORD, &area);
  
  printf("%s\n",text);

  //return 1;
   
}

static cairo_status_t write_png_stream (void *in_closure, const unsigned char *data, unsigned int length){

  unsigned int i;

  //png_stream_to_byte_array_closure_t *closure =
  //(png_stream_to_byte_array_closure_t *) in_closure;
  //if ((closure->current_position + length) > (closure->end_of_array))
  //return CAIRO_STATUS_WRITE_ERROR;
  //memcpy (closure->current_position, data, length);
  //closure->current_position += length;
  
  for (i=0;i<length;i++){
    putc(data[i],stdout);
  }
  
  return CAIRO_STATUS_SUCCESS;
}
