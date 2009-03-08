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

  char *in_file, *out_file;
  int pageNo;
  double width, height;
  char string[1000];
  int i;
  mxml_node_t *node, *xmlout, *output_tag, *status_tag, *page_tag, *some_tag;
  PDFDoc *doc;
  Page *page;
  GooString *filename_g;
  Catalog *catalog;

  filename_g = new GooString (xmlGet(xml,"inFile"));
  doc = new PDFDoc(filename_g, NULL, NULL);
    
  catalog = doc->getCatalog();

  xmlout = mxmlNewXML("1.0");
  output_tag = mxmlNewElement(xmlout, "output");
  status_tag = mxmlNewElement(output_tag, "status");
  mxmlNewOpaque(status_tag, "OK");
  some_tag = mxmlNewElement(output_tag, "pageNo");
  sprintf(string,"%i", doc->getNumPages());
  mxmlNewOpaque(some_tag,string );
  
  for (i=0;i<doc->getNumPages();i++){

    page = catalog->getPage (i+1);
    width=page->getCropWidth();
    height=page->getCropHeight();

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

  cairo_surface_t *surface;
  cairo_t *cr;
  char *in_file, *out_file;
  int pageNo;
  float scale;
  double width, height;
  mxml_node_t *node, *xmlout, *output_tag, *status_tag;

  PDFDoc *doc;
  Page *page;
  GooString *filename_g;
  char *filename;
  Gfx *gfx;
  Catalog *catalog;
  CairoOutputDev* output_dev;

    
  node = mxmlFindElement(xml, xml, "inFile", NULL, NULL, MXML_DESCEND);
  in_file=node->child->value.opaque;
  node = mxmlFindElement(xml, xml, "outFile", NULL, NULL, MXML_DESCEND);
  out_file=node->child->value.opaque;
  node = mxmlFindElement(xml, xml, "page", NULL, NULL, MXML_DESCEND);
  pageNo=atoi(node->child->value.opaque);
  node = mxmlFindElement(xml, xml, "scale", NULL, NULL, MXML_DESCEND);
  scale=atof(node->child->value.opaque);

  if (!globalParams) {
    globalParams = new GlobalParams();
  }

  filename_g = new GooString (in_file);
  doc = new PDFDoc(filename_g, NULL, NULL);
    
  catalog = doc->getCatalog();
  page = catalog->getPage (pageNo+1);

  width=page->getCropWidth();
  height=page->getCropHeight();

  surface = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, width*scale, height*scale);
  cr = cairo_create (surface);

  if (scale != 1.0){
    cairo_scale (cr, scale, scale);
  }

  output_dev = new CairoOutputDev ();
  output_dev->startDoc(doc->getXRef ());
  output_dev->setCairo (cr);
  output_dev->setPrinting (0);

  cairo_save (cr);

  page->displaySlice(output_dev, 72.0, 72.0, 0, gFalse, gTrue, -1, -1, -1, -1,
                       0,  catalog, NULL, NULL, NULL, NULL);
  cairo_restore (cr);

  output_dev->setCairo (NULL);	

  if (strcmp(out_file,"STDOUT")==0){
    cairo_surface_write_to_png_stream (surface, write_png_stream,NULL);
    exit(0);
  }
  
  cairo_surface_write_to_png(surface,out_file);
  cairo_destroy (cr);

  xmlout = mxmlNewXML("1.0");
  output_tag = mxmlNewElement(xmlout, "output");
  status_tag = mxmlNewElement(output_tag, "status");
  mxmlNewOpaque(status_tag, "OK");

  return xmlout;

}

mxml_node_t* search(mxml_node_t *xml){
  
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

  GError *error;
  int i;
  char *in_file;
  char string[1000];
  char type[100];
  int pageNo;
  double x1, y1, x2, y2;
  mxml_node_t *node, *xmlout, *output_tag, *status_tag, *word_tag;
  TextOutputDev *text_dev;
  
  PDFDoc *doc;
  Page *page;
  GooString *filename_g;
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
  doc = new PDFDoc(filename_g, NULL, NULL);

  catalog = doc->getCatalog();
  page = catalog->getPage (pageNo+1);

  /* code to get text_dev similar to poppler-page.cc */
  text_dev=new TextOutputDev(NULL, gFalse,gFalse,gFalse);

  if (text_dev->isOk()) {
    gfx=page->createGfx(text_dev,
                          72.0, 72.0, 0,
                          gFalse,
                          gTrue,
                          -1, -1, -1, -1,
                          gFalse,
                          doc->getCatalog (),
                          NULL, NULL, NULL, NULL);
    page->display(gfx);
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
    sprintf(string, "%.2f,%.2f,%.2f,%.2f", x1,y1,x2,y2);
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

  for (i=0;i<length;i++){
    putc(data[i],stdout);
  }
  
  return CAIRO_STATUS_SUCCESS;
}
