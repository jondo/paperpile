#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "config.h"
#include "cairo.h"
#include <podofo.h>

#include "yumpdf.h"
#include "annotation.h"

using namespace PoDoFo;

mxml_node_t* get_annotations(mxml_node_t *xml){

  int i,j, type;
  mxml_node_t *xmlout, *output_tag, *status_tag, 
    *some_tag, *page_tag, *ann_tag, *rect_tag;
  char* string;
  PdfPage* page;
  PdfRect rect;
  PdfAnnotation* annotation;

  PdfMemDocument document( xmlGet(xml,"inFile") );

  xmlout = mxmlNewXML("1.0");
  output_tag = mxmlNewElement(xmlout, "output");
  status_tag = mxmlNewElement(output_tag, "status");
  mxmlNewOpaque(status_tag, "OK");

  for (i=0;i < document.GetPageCount(); i++){
    page = document.GetPage( i );
    printf("Page: %i\n",i);
    page_tag = mxmlNewElement(output_tag, "page");

    for (j=0;j<page->GetNumAnnots();j++){
      annotation=page->GetAnnotation(j);
      type=annotation->GetType();
      
      // Currently only two types are supported
      if (type == ePdfAnnotation_Text || type == ePdfAnnotation_Highlight){

        if (type == ePdfAnnotation_Text){
          ann_tag = mxmlNewElement(page_tag, "annotation");

          xmlSetString(ann_tag,"type","STICKY");
          xmlSetString(ann_tag,"title",annotation->GetTitle().GetString());
          xmlSetString(ann_tag,"text",annotation->GetContents().GetString());

          rect_tag = mxmlNewElement(ann_tag, "rect");
          rect=annotation->GetRect();
          
          xmlSetFloat(rect_tag,"x1",rect.GetLeft());
          xmlSetFloat(rect_tag,"y1",rect.GetBottom()-rect.GetHeight());
          xmlSetFloat(rect_tag,"x2",rect.GetLeft()+rect.GetWidth());
          xmlSetFloat(rect_tag,"y2",rect.GetBottom());

        }

        if (type == ePdfAnnotation_Highlight){
            
           
        }

        printf("Type: %i\n",type);
          
      }
    }
  }
 
  return xmlout;
}




mxml_node_t* add_annotation(mxml_node_t *xml){

  int i, pageNo;
  float x1, y1, x2, y2;
  float bbox_x1,bbox_y1,bbox_x2,bbox_y2;
  char *type, *text, *title;
  char *in_file, *out_file;
  mxml_node_t *node, *xmlout, *output_tag, *status_tag;
  float color_r, color_g, color_b;

  PdfArray quadPoints;

  bbox_x1=bbox_y1=999999.9;
  bbox_x2=bbox_y2=-1.0;

  in_file=xmlGet(xml,"inFile");
  out_file=xmlGet(xml,"outFile");
  pageNo=atoi(xmlGet(xml,"page"));
  type=xmlGet(xml,"type");

  node = mxmlFindElement(xml, xml, "color", NULL, NULL,MXML_DESCEND);
  color_r=atof(xmlGet(xml,"red"));
  color_g=atof(xmlGet(xml,"green"));
  color_b=atof(xmlGet(xml,"blue"));

  PdfMemDocument document( in_file );
  PdfPage* page = document.GetPage( pageNo );
  PdfAnnotation* annotation;

  if (strcmp(type, "STICKY")==0){
    title=xmlGet(xml,"title");
    text=xmlGet(xml,"text");
    node = mxmlFindElement(xml, xml, "rect", NULL, NULL,MXML_DESCEND);
    x1=atof(xmlGet(node,"x1"));
    y1=atof(xmlGet(node,"y1"));
    x2=atof(xmlGet(node,"x2"));
    y2=atof(xmlGet(node,"y2"));
    
    annotation = page->CreateAnnotation( ePdfAnnotation_Text, PdfRect( x1, y2, x2-x2, y2-y1 ) );
    annotation->SetTitle( PdfString(title) );
    annotation->SetContents( PdfString(text) );
    annotation->SetColor( color_r,color_g,color_b);
    
    document.Write( "out.pdf" );
  }

  if (strcmp(type, "HIGHLIGHT")==0){
    for (node = mxmlFindElement(xml, xml, "rect", NULL, NULL,MXML_DESCEND);
         node != NULL;
         node = mxmlFindElement(node, xml, "rect", NULL, NULL, MXML_DESCEND)){

      x1=atof(xmlGet(node,"x1"));
      y1=atof(xmlGet(node,"y1"));
      x2=atof(xmlGet(node,"x2"));
      y2=atof(xmlGet(node,"y2"));
      
      /* Adobe Acrobat implementation and PDF specification (v. 1.7. p
         404 fig 64) are inconsitent. We use the ordering that is
         rendered correctly in Acrobat */

      // BL
      quadPoints.push_back( PdfVariant( x1 ));
      quadPoints.push_back( PdfVariant( y2 ));
      
      // BR
      quadPoints.push_back( PdfVariant( x2 ));
      quadPoints.push_back( PdfVariant( y2 ));
      
      // TL
      quadPoints.push_back( PdfVariant( x1 ));
      quadPoints.push_back( PdfVariant( y1 ));
      
      // TR
      quadPoints.push_back( PdfVariant( x2 ));
      quadPoints.push_back( PdfVariant( y1 ));
      
      
      if (x1<bbox_x1) bbox_x1=x1;
      if (x2<bbox_x1) bbox_x1=x2;
      if (y1<bbox_y1) bbox_y1=y1;
      if (y2<bbox_y1) bbox_y1=y2;
      
      if (x1>bbox_x2) bbox_x2=x1;
      if (x2>bbox_x2) bbox_x2=x2;
      if (y1>bbox_y2) bbox_y2=y1;
      if (y2>bbox_y2) bbox_y2=y2;
      
    }

    PdfRect bbox(bbox_x1,bbox_y2,bbox_x2-bbox_x1,bbox_y2-bbox_y1);

    PdfAnnotation* highlight = page->CreateAnnotation( ePdfAnnotation_Highlight, bbox ) ;
    highlight->SetQuadPoints( quadPoints );
    highlight->SetColor( 0, 0, 1, 0 );
    document.Write( "out.pdf" );

  }

  xmlout = mxmlNewXML("1.0");
  output_tag = mxmlNewElement(xmlout, "output");
  status_tag = mxmlNewElement(output_tag, "status");
  mxmlNewOpaque(status_tag, "OK");

}

