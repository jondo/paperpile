
#include <stdlib.h>
#include <iostream>
#include <podofo/podofo.h>

using namespace PoDoFo;

void PrintHelp();

int main( int argc, char* argv[] )
{

  char* fileName;

  if( argc != 7 ){
    printf("Usage: annotate file.pdf left bottom width height \"Note\"\n");
    exit( -1 );
  }

  fileName = argv[1];
  double left = atof(argv[2]);
  double bottom = atof(argv[3]);
  double width = atof(argv[4]);
  double height = atof(argv[5]);
  char* text =argv[6];
  
  printf("Reading file: %s\n", fileName );
  
  PdfMemDocument document( fileName );

  PdfPage* page = document.GetPage( 0 );

  PdfAnnotation* sticky = page->CreateAnnotation( ePdfAnnotation_Text, PdfRect( left, bottom, width, height ) );
  
  sticky->SetTitle( PdfString("Sticky note:") );
  sticky->SetContents( PdfString(text) );
  sticky->SetOpen(1);

  document.Write( "out.pdf" );
  
  return 0;
}


/*
void HelloWorld( const char* pszFilename ) 
{
    PdfStreamedDocument document( pszFilename );
    PdfPage* pPage;
    PdfPainter painter;
    PdfFont* pFont;
    pPage = document.CreatePage( PdfPage::CreateStandardPageSize( ePdfPageSize_A4 ) );
    if( !pPage ) 
    {
        PODOFO_RAISE_ERROR( ePdfError_InvalidHandle );
    }
    painter.SetPage( pPage );
    pFont = document.CreateFont( "Arial" );

    if( !pFont )
    {
        PODOFO_RAISE_ERROR( ePdfError_InvalidHandle );
    }
    pFont->SetFontSize( 18.0 );

    painter.SetFont( pFont );

    painter.DrawText( 56.69, pPage->GetPageSize().GetHeight() - 56.69, "Hello World!" );

    painter.FinishPage();
    document.GetInfo()->SetCreator ( PdfString("examplahelloworld - A PoDoFo test application") );
    document.GetInfo()->SetAuthor  ( PdfString("Dominik Seichter") );
    document.GetInfo()->SetTitle   ( PdfString("Hello World") );
    document.GetInfo()->SetSubject ( PdfString("Testing the PoDoFo PDF Library") );
    document.GetInfo()->SetKeywords( PdfString("Test;PDF;Hello World;") );

    document.Close();
}
*/
