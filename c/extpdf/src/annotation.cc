#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "config.h"
#include "poppler.h"
#include "cairo.h"
#include <podofo.h>

#include "extpdf.h"
#include "annotation.h"

using namespace PoDoFo;

mxml_node_t* add_sticky(mxml_node_t *xml){

  char* file;
  int pageNo;
  float left, bottom, width, height;
  char* text;

  printf("Reading file: %s\n", file );
  printf("pageNo: %i; (%f,%f,%f,%f), %s\n", pageNo, left, bottom, width, height, text );
  
  PoDoFo::PdfMemDocument document( file );

  PdfPage* page = document.GetPage( pageNo );
  
  //PdfAnnotation* sticky = page->CreateAnnotation( ePdfAnnotation_Text, PdfRect( left, bottom, width, height ) );

  PdfAnnotation* sticky = page->CreateAnnotation( ePdfAnnotation_Text, PdfRect( left, bottom, width, height ) );

  //sticky->SetColor( 0, 0, 1, 0 );
  sticky->SetTitle( PdfString("Sticky note:") );
  sticky->SetContents( PdfString(text) );
  sticky->SetOpen(1);

  document.Write( "out.pdf" );
  
  //return 1;
}

mxml_node_t* add_highlight(mxml_node_t *xml){

//int add_highlight(char* file, int pageNo, float x1, float y1, float x2, float y2){  

  PopplerRectangle area;
  GError *error;
  PopplerDocument *pdocument;
  PopplerPage *ppage;
  GList *selection;
  int i;
  gchar *uri;
  PopplerRectangle bbox;
  char* file;
  int pageNo;
  float x1, y1, x2, y2;

  PdfMemDocument document( file );
  PdfPage* page = document.GetPage( pageNo );


  uri = g_filename_to_uri (file, NULL, &error);

  if (error) {
    fail(error->message);
  }

  pdocument = poppler_document_new_from_file (uri, NULL, &error);
  ppage = poppler_document_get_page(pdocument, pageNo);

  area.x1 = x1;
  area.y1 = y1;
  area.x2 = x2;
  area.y2 = y2;

  selection=poppler_page_get_selection_region (ppage, 1.0, POPPLER_SELECTION_WORD, &area);


  /* Find bounding box */
  bbox.x1=bbox.y1=-1;
  bbox.x2=bbox.y2=999999.9;

  for (i=0; i< g_list_length( selection );i++){
    PopplerRectangle *rect = (PopplerRectangle *)g_list_nth( selection, i)->data; 
    if (rect->x1<bbox.x1) bbox.x1=rect->x1;
    if (rect->x2<bbox.x1) bbox.x1=rect->x2;
    if (rect->y1<bbox.y1) bbox.y1=rect->y1;
    if (rect->y2<bbox.y1) bbox.y1=rect->y2;
    
    if (rect->x1>bbox.x2) bbox.x2=rect->x1;
    if (rect->x2>bbox.x2) bbox.x2=rect->x2;
    if (rect->y1>bbox.y2) bbox.y1=rect->y2;
    if (rect->y2>bbox.y2) bbox.y2=rect->y2;
    
  }

  printf("%.2f %.2f %.2f %.2f\n", bbox.x1, bbox.y1, bbox.x2, bbox.y2);

  for (i=0; i< g_list_length( selection );i++){
    PopplerRectangle *rectangle = (PopplerRectangle *)g_list_nth( selection, i)->data; 
    printf("%i %.2f %.2f %.2f %.2f\n", pageNo, rectangle->x1, rectangle->y1, rectangle->x2, rectangle->y2);
  }

  // PdfAnnotation* sticky = page->CreateAnnotation( ePdfAnnotation_Text, PdfRect( left, bottom, width, height ) );
  // //sticky->SetColor( 0, 0, 1, 0 );
  // sticky->SetTitle( PdfString("Sticky note:") );
  // sticky->SetContents( PdfString(text) );
  // sticky->SetOpen(1);
  //document.Write( "out.pdf" );
  
  //return 1;
}

