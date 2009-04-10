//=================================================================================
//
// XmlOutputDev.cc (based on TextOutputDev.h, Copyright 1997-2003 Glyph & Cog, LLC)
// author: Hervé Déjean, Sophie Andrieu
// 04-2006
// Xerox Research Centre Europe
//
//=================================================================================

#include <aconf.h>
#ifdef USE_GCC_PRAGMAS
#pragma implementation
#endif

#include <libxml/xmlmemory.h>
#include <libxml/parser.h>
#include <time.h>
#include <string>
#include <vector>

#include <iostream>
using namespace std;

#include "ConstantsUtils.h"
using namespace ConstantsUtils;

#include "ConstantsXML.h"
using namespace ConstantsXML;

#include <stdio.h>
#include <stddef.h>
#include <math.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdarg.h>

#ifndef WIN32
#include <libgen.h>
#endif

#ifdef WIN32
#include <fcntl.h> // for O_BINARY
#include <io.h>    // for setmode
#include <direct.h>  // for _mkdir
#endif

#include "gmem.h"
#include "GList.h"
#include "config.h"
#include "Error.h"
#include "GlobalParams.h"
#include "UnicodeMap.h"
#include "UnicodeTypeTable.h"
#include "GfxState.h"
#include "PDFDoc.h"
#include "Outline.h"
#include "XmlOutputDev.h"
#include "Link.h"
#include "Catalog.h"
#include "Parameters.h"

#ifdef MACOS
// needed for setting type/creator of MacOS files
#include "ICSupport.h"
#endif

//------------------------------------------------------------------------
// parameters
//------------------------------------------------------------------------

// Inter-character space width which will cause addChar to start a new word.
#define minWordBreakSpace 0.1

// Negative inter-character space width, i.e., overlap, which will
// cause addChar to start a new word.
#define minDupBreakOverlap 0.3

// Maximum distance between baselines of two words on the same line,
// e.g., distance between subscript or superscript and the primary
// baseline, as a fraction of the font size.
#define maxIntraLineDelta 0.5

// Maximum distance value between the baseline of a word in a line
// and the yMin of an other word in a other line
#define maxSpacingWordsBetweenTwoLines 5

// Maximum inter-word spacing, as a fraction of the font size.
#define maxWordSpacing 1.5

// Maximum horizontal spacing which will allow a word to be pulled
// into a block.
#define maxColSpacing 0.3 

// Max distance between baselines of two lines within a block, as a
// fraction of the font size.
#define maxLineSpacingDelta 1.5 

// Max difference in primary font sizes on two lines in the same
// block.  Delta1 is used when examining new lines above and below the
// current block.
#define maxBlockFontSizeDelta1 0.05

// Max difference in primary,secondary coordinates (as a fraction of
// the font size) allowed for duplicated text (fake boldface, drop
// shadows) which is to be discarded.
#define dupMaxPriDelta 0.1
#define dupMaxSecDelta 0.2

//------------------------------------------------------------------------
// TextFontInfo
//------------------------------------------------------------------------

TextFontInfo::TextFontInfo(GfxState *state) {
  gfxFont = state->getFont();
#if TEXTOUT_WORD_LIST
  fontName = (gfxFont && gfxFont->getOrigName())
                 ? gfxFont->getOrigName()->copy()
                 : (GString *)NULL;
#endif
}

TextFontInfo::~TextFontInfo() {
#if TEXTOUT_WORD_LIST
  if (fontName) {
    delete fontName;
  }
#endif
}

GBool TextFontInfo::matches(GfxState *state) {
  return state->getFont() == gfxFont;
}

//------------------------------------------------------------------------
// ImageInline
//------------------------------------------------------------------------

ImageInline::ImageInline(int xPosition, int yPosition, int width, int height, int idWord, int idImage, GString* href) {
	xPositionImage = xPosition;
	yPositionImage = yPosition;
	widthImage = width;
	heightImage = height;
	idWordBefore = idWord;
  	idImageCurrent = idImage;
  	hrefImage = href;
	
}

ImageInline::~ImageInline() {

}

//------------------------------------------------------------------------
// TextWord
//------------------------------------------------------------------------

TextWord::TextWord(GfxState *state, int rotA, int angleDegre, int angleSkewingY, int angleSkewingX, double x0, double y0,
		   int charPosA, TextFontInfo *fontA, double fontSizeA, int idCurrentWord) {
  GfxFont *gfxFont;
  double x, y, ascent, descent;

  rot = rotA;
  angle = angleDegre;
  charPos = charPosA;
  charLen = 0;
  font = fontA;
  italic = gFalse;
  bold = gFalse;
  serif = gFalse;
  symbolic = gFalse;
  angleSkewing_Y = angleSkewingY;
  angleSkewing_X = angleSkewingX;
  idWord = idCurrentWord;
  
  base = 0;
  baseYmin = 0;
  fontName = NULL;

  if (state->getFont()){
    if (state->getFont()->getName()){
    	// PDF reference guide 5.5.3 For a font subset, the PostScript name of the font—the value of the font’s
		//BaseFont entry and the font descriptor’s FontName entry—begins with a tag
		//followed by a plus sign (+). The tag consists of exactly six uppercase letters; the
		//choice of letters is arbitrary, but different subsets in the same PDF file must have
		//different tags. For example, EOODIA+Poetica is the name of a subset of Poetica®, a
		//Type 1 font. (See implementation note 62 in Appendix H.)
      fontName = strdup(state->getFont()->getName()->getCString());
      if (strstr(state->getFont()->getName()->lowerCase()->getCString(),"bold"))  bold=gTrue;
      if (strstr(state->getFont()->getName()->lowerCase()->getCString(),"italic")||
    	strstr(state->getFont()->getName()->lowerCase()->getCString(),"oblique"))  italic=gTrue;
    }
    else{
	  fontName = NULL;
    }
    if (bold == gFalse) {bold = state->getFont()->isBold();}
    if (italic == gFalse) {italic = state->getFont()->isItalic();}
    symbolic = state->getFont()->isSymbolic();
    serif = state->getFont()->isSerif();
  }

  horizScaling = state->getHorizScaling();
  wordSpace = state->getWordSpace();
  charSpace = state->getCharSpace();
  rise = state->getRise();
  render = state->getRender();
  leading = state->getLeading();

  fontSize = fontSizeA;
  
  state->transform(x0, y0, &x, &y);
  if ((gfxFont = font->gfxFont)) {
    ascent = gfxFont->getAscent() * fontSize;
    descent = gfxFont->getDescent() * fontSize;
  } else {
    // this means that the PDF file draws text without a current font,
    // which should never happen
    ascent = 0.95 * fontSize;
    descent = -0.35 * fontSize;
    gfxFont = NULL;
  }
  
  // Rotation cases
  switch (rot) {
  case 0:
    yMin = y - ascent;
    yMax = y - descent;
    if (yMin == yMax) {
      // this is a sanity check for a case that shouldn't happen -- but
      // if it does happen, we want to avoid dividing by zero later
      yMin = y;
      yMax = y + 1;
    }
    base = y;
    baseYmin = yMin;
    break;
    
   case 3:
    xMin = x + descent;
    xMax = x + ascent;
    if (xMin == xMax) {
      // this is a sanity check for a case that shouldn't happen -- but
      // if it does happen, we want to avoid dividing by zero later
      xMin = x;
      xMax = x + 1;
    }
    base = x;
    baseYmin = xMin;
    break;
    
  case 2:
    yMin = y + descent;
    yMax = y + ascent;
    if (yMin == yMax) {
      // this is a sanity check for a case that shouldn't happen -- but
      // if it does happen, we want to avoid dividing by zero later
      yMin = y;
      yMax = y + 1;
    }
    base = y;
    baseYmin = yMin;
    break;
    
   case 1:
    xMin = x - ascent;
    xMax = x - descent;
    if (xMin == xMax) {
      // this is a sanity check for a case that shouldn't happen -- but
      // if it does happen, we want to avoid dividing by zero later
      xMin = x;
      xMax = x + 1;
    }
    base = x;
    baseYmin = xMin;
    break;
  }
  
  text = NULL;
  edge = NULL;
  len = size = 0;
  spaceAfter = gFalse;
  next = NULL;

  GfxRGB rgb;

  if ((state->getRender() & 3) == 1) {
    state->getStrokeRGB(&rgb);
  } else {
    state->getFillRGB(&rgb);
  }

  colorR = colToDbl(rgb.r);
  colorG = colToDbl(rgb.g);
  colorB = colToDbl(rgb.b);
}

TextWord::~TextWord() {
  gfree(text);
  gfree(edge);
}

void TextWord::addChar(GfxState *state, double x, double y,
		       double dx, double dy, Unicode u) {

  if (len == size) {
    size += 16;
    text = (Unicode *)grealloc(text, size * sizeof(Unicode));
    edge = (double *)grealloc(edge, (size + 1) * sizeof(double));
  }
  text[len] = u;
 switch (rot) {
  case 0:
    if (len == 0) {
      xMin = x;
    }
    edge[len] = x;
    xMax = edge[len+1] = x + dx;
    break;
case 3:
    if (len == 0) {
      yMin = y;
    }
    edge[len] = y;
    yMax = edge[len+1] = y + dy;
    break;
  case 2:
    if (len == 0) {
      xMax = x;
    }
    edge[len] = x;
    xMin = edge[len+1] = x + dx;
    break;
  case 1:
    if (len == 0) {
      yMax = y;
    }
    edge[len] = y;
    yMin = edge[len+1] = y + dy;
    break;
  }
  ++len;
}

void TextWord::merge(TextWord *word) {
  int i;

  if (word->xMin < xMin) {
    xMin = word->xMin;
  }
  if (word->yMin < yMin) {
    yMin = word->yMin;
  }
  if (word->xMax > xMax) {
    xMax = word->xMax;
  }
  if (word->yMax > yMax) {
    yMax = word->yMax;
  }
  if (len + word->len > size) {
    size = len + word->len;
    text = (Unicode *)grealloc(text, size * sizeof(Unicode));
    edge = (double *)grealloc(edge, (size + 1) * sizeof(double));
  }
  for (i = 0; i < word->len; ++i) {
    text[len + i] = word->text[i];
    edge[len + i] = word->edge[i];
  }
  edge[len + word->len] = word->edge[word->len];
  len += word->len;
  charLen += word->charLen;
}

inline int TextWord::primaryCmp(TextWord *word) {
  double cmp;

  cmp = 0; // make gcc happy
  switch (rot) {
  case 0:
    cmp = xMin - word->xMin;
    break;
  case 3:
    cmp = yMin - word->yMin;
    break;
  case 2:
    cmp = word->xMax - xMax;
    break;
  case 1:
    cmp = word->yMax - yMax;
    break;
  }
  return cmp < 0 ? -1 : cmp > 0 ? 1 : 0;
}

double TextWord::primaryDelta(TextWord *word) {
  double delta;

  delta = 0; // make gcc happy
  switch (rot) {
  case 0:
    delta = word->xMin - xMax;
    break;
  case 3:
    delta = word->yMin - yMax;
    break;
  case 2:
    delta = xMin - word->xMax;
    break;
  case 1:
    delta = yMin - word->yMax;
    break;
  }
  return delta;
}

int TextWord::cmpYX(const void *p1, const void *p2) {
  TextWord *word1 = *(TextWord **)p1;
  TextWord *word2 = *(TextWord **)p2;
  double cmp;

  cmp = word1->yMin - word2->yMin;
  if (cmp == 0) {
    cmp = word1->xMin - word2->xMin;
  }
  return cmp < 0 ? -1 : cmp > 0 ? 1 : 0;
}

GString *TextWord::convtoX(double xcol) const{
  GString *xret=new GString();
  char tmp;
  unsigned int k;
  k = static_cast<int>(xcol);
  k= k/16;
  if ((k>=0)&&(k<10)) tmp=(char) ('0'+k); else tmp=(char)('a'+k-10);
  xret->append(tmp);
  k = static_cast<int>(xcol);
  k= k%16;
  if ((k>=0)&&(k<10)) tmp=(char) ('0'+k); else tmp=(char)('a'+k-10);
  xret->append(tmp);
 return xret;
}

GString *TextWord::colortoString() const{
  GString *tmp=new GString("#");
  GString *tmpr=convtoX(static_cast<int>(255*colorR)); 
  GString *tmpg=convtoX(static_cast<int>(255*colorG));
  GString *tmpb=convtoX(static_cast<int>(255*colorB));
  tmp->append(tmpr);
  tmp->append(tmpg);
  tmp->append(tmpb);

  delete tmpr;
  delete tmpg;
  delete tmpb;
  return tmp;
} 

const char* TextWord::normalizeFontName(char* fontName){
	string name = fontName;
	size_t position = name.find_first_of('+');		 	
	if (position != string::npos){
		name = name.substr(position+1,name.size()-1);
	}
	position = name.find_first_of('-');
	if (position != string::npos){
		name = name.substr(0,position);
	}		 	
	position = name.find_first_of(',');
	if (position != string::npos){
		name = name.substr(0,position);
	}		
	return name.c_str();
}

//------------------------------------------------------------------------
// TextPage
//------------------------------------------------------------------------

TextPage::TextPage(GBool verboseA, xmlNodePtr node, GString* dir, GString *base, GString *nsURIA) {

  root = node;
  verbose = verboseA;
  rawOrder = 1;

  curWord = NULL;
  charPos = 0;
  curFont = NULL;
  curFontSize = 0;
  nest = 0;
  nTinyChars = 0;
  lastCharOverlap = gFalse;
  beginZoneClip = 0;
  endZoneClip = 0;
  idClip = 0;
  idClipBefore = 0;
  
  if (nsURIA){
  	namespaceURI = new GString(nsURIA);
  }else{
  	namespaceURI = NULL;
  }
  
  rawWords = NULL;
  rawLastWord = NULL;
  fonts = new GList();
  lastFindXMin = lastFindYMin = 0;
  haveLastFind = gFalse;

  if (parameters->getDisplayImage()){	
  	  RelfileName = new GString(dir);
	  ImgfileName = new GString(base);
  }
}

TextPage::~TextPage() {
  	clear();
  	delete fonts;
  	if (namespaceURI){
  		delete namespaceURI;
  	}
}

void TextPage::startPage(int pageNum, GfxState *state, GBool cut) {

  	clear();
  	char *tmp;
  	cutter = cut;
  	num = pageNum;
  	numToken = 1;
  	numImage = 1;
  	idWORD = 0;
  	indiceImage = -1;
  	idWORDBefore = -1;

  	page = xmlNewNode(NULL,(const xmlChar*)TAG_PAGE);
  	page->type = XML_ELEMENT_NODE;
  	if (state) {
    	pageWidth = state->getPageWidth();
    	pageHeight = state->getPageHeight();
  	} else {
   		pageWidth = pageHeight = 0;
  	}

  	tmp = (char*)malloc(20*sizeof(char));
  	sprintf(tmp,"%g",pageWidth);
  	xmlNewProp(page,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
  	sprintf(tmp,"%g",pageHeight);
  	xmlNewProp(page,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
  	sprintf(tmp,"%d",pageNum);
  	xmlNewProp(page,(const xmlChar*)ATTR_NUMBER,(const xmlChar*)tmp);
  	GString *id;
  	id = new GString("p");
  	id->append(tmp);
  	//xmlNewProp(page,(const xmlChar*)ATTR_ID,(const xmlChar*)id->getCString());
  	delete id;
  	
  	if (pageWidth>700 && pageHeight<700){
  		if((pageHeight==841 || pageHeight==842) && pageWidth==1224) {
  	  		xmlNewProp(page,(const xmlChar*)ATTR_FORMAT,(const xmlChar*)"A3");
  		}else {
  	  		xmlNewProp(page,(const xmlChar*)ATTR_FORMAT,(const xmlChar*)"landscape");
  		}
  	}
  	
  	// Cut all pages OK
  	if (cutter){
		docPage = xmlNewDoc((const xmlChar*)VERSION);
  		globalParams->setTextEncoding((char*)ENCODING_UTF8);
  		docPage->encoding = xmlStrdup((const xmlChar*)ENCODING_UTF8);
  		xmlDocSetRootElement(docPage,page);
  	}else{
  		xmlAddChild(root,page);
  	}
  
  	fprintf(stderr, "Page %d\n",pageNum);
  	fflush(stderr);

  	// New file for vectorials instructions 
  	vecdoc = xmlNewDoc((const xmlChar*)VERSION);
  	globalParams->setTextEncoding((char*)ENCODING_UTF8);
  	vecdoc->encoding = xmlStrdup((const xmlChar*)ENCODING_UTF8);
  	vecroot = xmlNewNode(NULL,(const xmlChar*)TAG_VECTORIALIMAGES);

  	// Add the namespace DS of the vectorial instructions file
  	if (namespaceURI){
  		xmlNewNs(vecroot,(const xmlChar*)namespaceURI->getCString(),NULL);
  	}
  	
  	xmlDocSetRootElement(vecdoc,vecroot);
  
  	free(tmp);
}

void TextPage::configuration() {
  	if (curWord) {
    	endWord();
  	}
   	if (rawOrder) {
    	primaryRot = 0;
    	primaryLR = gTrue;
  	}
}

void TextPage::endPage(GString *dataDir) {
  	if (curWord) {
    	endWord();
  	}
  
   	if (parameters->getDisplayImage()){

 		xmlNodePtr xiinclude=NULL;
 		xmlNsPtr xiNs = NULL;
    
  		GString *relname = new GString(RelfileName);
  		relname->append("-");
  		relname->append(GString::fromInt(num));
  		relname->append(EXTENSION_VEC);
  
   		GString *refname = new GString(ImgfileName);
  		refname->append("-");
  		refname->append(GString::fromInt(num));
  		refname->append(EXTENSION_VEC);
   
   		xiNs=xmlNewNs(NULL,(const xmlChar*)XI_URI,(const xmlChar*)XI_PREFIX);
		if(xiNs){
			xiinclude = xmlNewNode(xiNs,(const xmlChar*)XI_INCLUDE);
			xiNs=xmlNewNs(xiinclude,(const xmlChar*)XI_URI,(const xmlChar*)XI_PREFIX);
			xmlSetNs(xiinclude,xiNs);
		    	if (cutter){
		    		// Change the relative path of vectorials images when all pages are cutted
		    		GString *imageName = new GString("image");
  					imageName->append("-");
  					imageName->append(GString::fromInt(num));
  					imageName->append(EXTENSION_VEC);
					xmlNewProp(xiinclude,(const xmlChar*)ATTR_HREF,(const xmlChar*)imageName->getCString());
					delete imageName;
		    	} else {
					xmlNewProp(xiinclude,(const xmlChar*)ATTR_HREF,(const xmlChar*)refname->getCString());
		    	}
		    
		    if (namespaceURI){
				xmlNewNs(xiinclude,(const xmlChar*)namespaceURI->getCString(),NULL);
		    }
			xmlAddChild(page,xiinclude);
		}
		else{
			fprintf(stderr,"namespace %s : impossible creation\n",XI_PREFIX);
		}
        
  		// Save the file for example with relname 'p_06.xml_data/image-27.vec'
 		if (! xmlSaveFile(relname->getCString(),vecdoc)){
 			error(-1, "Couldn't open file '%s'", relname->getCString());
 		}

  		delete refname;
  		delete relname;
   	}
  
    // IF cutter is ok we build the file name for all pages separately  
    // and save all files in the data directory
    if (cutter){
    	dataDirectory = new GString(dataDir);
  		GString *pageFile = new GString(dataDirectory);
  		pageFile->append("/pageNum-");
  		pageFile->append(GString::fromInt(num));
  		pageFile->append(EXTENSION_XML);
  		
  		if (! xmlSaveFile(pageFile->getCString(),docPage)){
 			error(-1, "Couldn't open file '%s'", pageFile->getCString());
 		}

		// Add in the principal file XML all pages as a tag xi:include
 		xmlNodePtr nodeXiInclude = NULL;
 		xmlNsPtr nsXi = xmlNewNs(NULL,(const xmlChar*)XI_URI,(const xmlChar*)XI_PREFIX);
		if(nsXi){
			nodeXiInclude = xmlNewNode(nsXi,(const xmlChar*)XI_INCLUDE);
			nsXi = xmlNewNs(nodeXiInclude,(const xmlChar*)XI_URI,(const xmlChar*)XI_PREFIX);
			xmlSetNs(nodeXiInclude,nsXi);
			xmlNewProp(nodeXiInclude,(const xmlChar*)ATTR_HREF,(const xmlChar*)pageFile->getCString());
			if (namespaceURI){
				xmlNewNs(nodeXiInclude,(const xmlChar*)namespaceURI->getCString(),NULL);
			}
			xmlAddChild(root,nodeXiInclude);
		}
		delete pageFile;
    }
}

void TextPage::clear() {
  	TextWord *word;

  	if (curWord) {
    	delete curWord;
    	curWord = NULL;
  	}
  	if (rawOrder) {
    	while (rawWords) {
      		word = rawWords;
      		rawWords = rawWords->next;
      		delete word;
    	}
  	}
  	deleteGList(fonts, TextFontInfo);

  	curWord = NULL;
  	charPos = 0;
  	curFont = NULL;
  	curFontSize = 0;
  	nest = 0;
  	nTinyChars = 0;

  	rawWords = NULL;
  	rawLastWord = NULL;
  	fonts = new GList();

	// Clear the vector which contain images inline objects
  	int nb = listeImageInline.size();
  	for (int i=0 ; i<nb ; i++){
  		delete listeImageInline[i];
  	}
  	listeImageInline.clear();

}

void TextPage::updateFont(GfxState *state) {

  GfxFont *gfxFont;
  double *fm;
  char *name;
  int code, mCode, letterCode, anyCode;
  double w;
  int i;

  // get the font info object
  curFont = NULL;
  for (i = 0; i < fonts->getLength(); ++i) {
    curFont = (TextFontInfo *)fonts->get(i);
     	 
    if (curFont->matches(state)) {
      break;
    }
    curFont = NULL;
  }
  
  if (!curFont) {
    curFont = new TextFontInfo(state);
    fonts->append(curFont);
  }

  // adjust the font size
  gfxFont = state->getFont();
 
  curFontSize = state->getTransformedFontSize();
  if (gfxFont && gfxFont->getType() == fontType3) {
    // This is a hack which makes it possible to deal with some Type 3
    // fonts.  The problem is that it's impossible to know what the
    // base coordinate system used in the font is without actually
    // rendering the font.  This code tries to guess by looking at the
    // width of the character 'm' (which breaks if the font is a
    // subset that doesn't contain 'm').
    mCode = letterCode = anyCode = -1;
    for (code = 0; code < 256; ++code) {
      name = ((Gfx8BitFont *)gfxFont)->getCharName(code);
      if (name && name[0] == 'm' && name[1] == '\0') {
	mCode = code;
      }
      if (letterCode < 0 && name && name[1] == '\0' &&
	  ((name[0] >= 'A' && name[0] <= 'Z') ||
	   (name[0] >= 'a' && name[0] <= 'z'))) {
	letterCode = code;
      }
      if (anyCode < 0 && name &&
	  ((Gfx8BitFont *)gfxFont)->getWidth(code) > 0) {
	anyCode = code;
      }
    }
    if (mCode >= 0 &&
	(w = ((Gfx8BitFont *)gfxFont)->getWidth(mCode)) > 0) {
      // 0.6 is a generic average 'm' width -- yes, this is a hack
      curFontSize *= w / 0.6;
    } else if (letterCode >= 0 &&
	       (w = ((Gfx8BitFont *)gfxFont)->getWidth(letterCode)) > 0) {
      // even more of a hack: 0.5 is a generic letter width
      curFontSize *= w / 0.5;
    } else if (anyCode >= 0 &&
	       (w = ((Gfx8BitFont *)gfxFont)->getWidth(anyCode)) > 0) {
      // better than nothing: 0.5 is a generic character width
      curFontSize *= w / 0.5;
    }
    fm = gfxFont->getFontMatrix();
    if (fm[0] != 0) {
      curFontSize *= fabs(fm[3] / fm[0]);
    }
  }
}

void TextPage::beginWord(GfxState *state, double x0, double y0) {

	double *fontm;
	double m[4];
	double m2[4];
	int rot;
	int angle;
	int angleSkewingY = 0;
	int angleSkewingX = 0;
	double tan;

	// This check is needed because Type 3 characters can contain
	// text-drawing operations (when TextPage is being used via
	// {X,Win}SplashOutputDev rather than TextOutputDev).
	if (curWord) {
    	++nest;
    	return;
  	}

  	// Compute the rotation     
  	state->getFontTransMat(&m[0], &m[1], &m[2], &m[3]);

  	if (state->getFont()->getType() == fontType3) {
    	fontm = state->getFont()->getFontMatrix();
   		m2[0] = fontm[0] * m[0] + fontm[1] * m[2];
    	m2[1] = fontm[0] * m[1] + fontm[1] * m[3];
    	m2[2] = fontm[2] * m[0] + fontm[3] * m[2];
    	m2[3] = fontm[2] * m[1] + fontm[3] * m[3];
    	m[0] = m2[0];
    	m[1] = m2[1];
    	m[2] = m2[2];
    	m[3] = m2[3];
  	}

  	if (fabs(m[0] * m[3]) > fabs(m[1] * m[2])) {
    	rot = (m[3] < 0) ? 0 : 2;
  	} else {
    	rot = (m[2] > 0) ? 3 : 1;
  	}
  	
  	// Get the tangent
  	tan = m[2]/m[0];
  	// Get the angle value in radian 
  	tan = atan(tan);
  	// To convert radian angle to degree angle
  	tan = 180 * tan / M_PI;
  	
	angle = static_cast<int>(tan);
      	
    // Adjust the angle value
	switch (rot) {
  	case 0:
  		if (angle>0) angle = 360 - angle;
    	else angle = static_cast<int>(fabs(static_cast<double>(angle)));
    	break;
  	case 1:
  		if (angle>0) angle = 180 - angle;
  		else angle = static_cast<int>(fabs(static_cast<double>(angle)));
 	  	break;
  	case 2:
  		if (angle>0) angle = 180 - angle;
  		else angle = static_cast<int>(fabs(static_cast<double>(angle))) + 180;
		break;
  	case 3:
  		if (angle>0) angle = 360 - angle;
  		else angle = static_cast<int>(fabs(static_cast<double>(angle))) + 180;
  		break;
  	}

 	// Recover the skewing angle value
  	if (m[1]==0 && m[2]!=0){
  		double angSkew = atan(m[2]);
  		angSkew = (180 * angSkew / M_PI) - 90 ;
  		angleSkewingY = static_cast<int>(angSkew);
  		if (rot == 0) {
  			angle = 0;
  		}
  	}
  
  	if (m[1]!=0 && m[2]==0){
  		double angSkew = atan(m[1]);	
  		angSkew = 180 * angSkew / M_PI;	
  		angleSkewingX = static_cast<int>(angSkew);
  		if (rot == 0) {
  			angle = 0;
  		}
  	}

  	curWord = new TextWord(state, rot, angle, angleSkewingY, angleSkewingX, x0, y0, charPos, curFont, curFontSize, getIdWORD());
}

void TextPage::addChar(GfxState *state, double x, double y,
		       double dx, double dy,
		       CharCode c, int nBytes, Unicode *u, int uLen) {

  double x1, y1, w1, h1, dx2, dy2, base, sp, delta;
  GBool overlap;
  int i;	

  if (uLen == 0){
    endWord();
    return;
  }

  // if the previous char was a space, addChar will have called
  // endWord, so we need to start a new word
  if (!curWord) {
    beginWord(state, x, y);
  }

  // throw away chars that aren't inside the page bounds
  state->transform(x, y, &x1, &y1);
  if (x1 < 0 || x1 > pageWidth ||
      y1 < 0 || y1 > pageHeight) {
    charPos += nBytes;
    endWord();
    return;
  }

  // subtract char and word spacing from the dx,dy values // HD why ??
  sp = state->getCharSpace();
  if (c == (CharCode)0x20) {
    sp += state->getWordSpace();
  }
  state->textTransformDelta(sp * state->getHorizScaling(), 0, &dx2, &dy2);
  dx -= dx2; //HD
  dy -= dy2; //HD
  state->transformDelta(dx, dy, &w1, &h1);

  // check the tiny chars limit
  if (!globalParams->getTextKeepTinyChars() &&
      fabs(w1) < 3 && fabs(h1) < 3) {
    if (++nTinyChars > 50000) {
      charPos += nBytes;
      return;
    }
  }

  // break words at space character
  if (uLen == 1 && u[0] == (Unicode)0x20) {
  	if (curWord){	
    	++curWord->charLen;
  	}
  	charPos += nBytes;
    endWord();
    return;
  }

//  // HD : control characters: does not work with reflex2003.pdf
//  if (uLen == 1 &&  c> (CharCode)0x00 && c <= (CharCode)0x20) {
//    ++curWord->charLen;
//    ++charPos;
//    endWord();
//    return;
//  	}


  if (!curWord) {
    beginWord(state, x, y);
  }

  // start a new word if:
  // (1) this character doesn't fall in the right place relative to
  //     the end of the previous word (this places upper and lower
  //     constraints on the position deltas along both the primary
  //     and secondary axes), or
  // (2) this character overlaps the previous one (duplicated text), or
  // (3) the previous character was an overlap (we want each duplicated
  //     character to be in a word by itself at this stage)
  //     characters to be in a word by itself) // HD deleted
  if (curWord && curWord->len > 0) {
  base = sp = delta = 0; // make gcc happy
    switch (curWord->rot) {
    case 0:
      base = y1;
      sp = x1 - curWord->xMax ;
      delta = x1 - curWord->edge[curWord->len - 1];
      break;
    case 3:
      base = x1;
      sp = y1 - curWord->yMax ;
      delta = y1 - curWord->edge[curWord->len - 1];
      break;
    case 2:
      base = y1;
      sp = curWord->xMin - x1 ;
      delta = curWord->edge[curWord->len - 1] - x1;
      break;
    case 1:
      base = x1;
      sp = curWord->yMin - y1 ;
      delta = curWord->edge[curWord->len - 1] - y1;
      break;
    }
	sp -= curWord->charSpace;
    curWord->charSpace = state->getCharSpace();
	 overlap = fabs(delta) < dupMaxPriDelta * curWord->fontSize &&
              fabs(base - curWord->base) < dupMaxSecDelta * curWord->fontSize;
  
    // take into account rotation angle ??
if ( overlap || fabs(base - curWord->base) > 1 ||
	 sp > minWordBreakSpace * curWord->fontSize   ||
	 sp < -minDupBreakOverlap * curWord->fontSize ) {
      endWord();
      beginWord(state, x, y);
    }
    lastCharOverlap = overlap; 
  } 
  else {
    lastCharOverlap = gFalse;
  }
  
   if (uLen != 0) {
   	if (!curWord){
   		beginWord(state, x, y);
   	}
  // page rotation and/or transform matrices can cause text to be
  // drawn in reverse order -- in this case, swap the begin/end
  // coordinates and break text into individual chars
  if ((curWord->rot == 0 && w1 < 0) ||
  	  (curWord->rot == 3 && h1 < 0) ||
      (curWord->rot == 2 && w1 > 0) ||
  	  (curWord->rot == 1 && h1 > 0)) {
    endWord();
    beginWord(state, x + dx, y + dy);
    x1 += w1;
    y1 += h1;
    w1 = -w1;
    h1 = -h1;
  }

  // add the characters to the current word
    w1 /= uLen;
    h1 /= uLen;

  for (i = 0; i < uLen; ++i) {
    curWord->addChar(state, x1 + i*w1, y1 + i*h1, w1, h1, u[i]); 
  }
   }
   
  if (curWord){
  	curWord->charLen += nBytes;
  }
  charPos += nBytes;
   
}

void TextPage::endWord() {
  // This check is needed because Type 3 characters can contain
  // text-drawing operations (when TextPage is being used via
  // {X,Win}SplashOutputDev rather than TextOutputDev).
  if (nest > 0) {
    --nest;
    return;
  }

  if (curWord) {
    addWord(curWord);
    curWord = NULL;
    idWORD++;
  }

}

void TextPage::addWord(TextWord *word) {
  // throw away zero-length words -- they don't have valid xMin/xMax
  // values, and they're useless anyway
  if (word->len == 0) {
    delete word;
    return;
  }

  if (rawOrder) {
    if (rawLastWord) {
      rawLastWord->next = word;
    } else {
      rawWords = word;
    }
    rawLastWord = word;
  } 
}

void TextPage::addAttributTypeReadingOrder(xmlNodePtr node, char* tmp, TextWord *word){
	int nbLeft = 0;
   	int nbRight = 0;
   
   	// Recover the reading order for each characters of the word
    for (int i = 0; i < word->len; ++i) {
    	if (unicodeTypeR(word->text[i])){
    		nbLeft++;
    	}else{
    		nbRight++;
    	}
  	}
  	// IF there is more character where the reading order is left to right 
  	// then we add the type attribute with a true value
  	if (nbRight<nbLeft){
  		sprintf(tmp,"%d",gTrue);
    	xmlNewProp(node,(const xmlChar*)ATTR_TYPE,(const xmlChar*)tmp);      
  	}    	
}

void TextPage::addAttributsNodeVerbose(xmlNodePtr node, char* tmp, TextWord *word){
		  	sprintf(tmp,"%d",word->angleSkewing_Y);
	  		xmlNewProp(node,(const xmlChar*)ATTR_ANGLE_SKEWING_Y,(const xmlChar*)tmp);
	  		sprintf(tmp,"%d",word->angleSkewing_X);
	  		xmlNewProp(node,(const xmlChar*)ATTR_ANGLE_SKEWING_X,(const xmlChar*)tmp);
        	sprintf(tmp,"%.2f",word->leading);
        	xmlNewProp(node,(const xmlChar*)ATTR_LEADING,(const xmlChar*)tmp);
        	sprintf(tmp,"%.2f",word->render);
        	xmlNewProp(node,(const xmlChar*)ATTR_RENDER,(const xmlChar*)tmp);
        	sprintf(tmp,"%.2f",word->rise);
        	xmlNewProp(node,(const xmlChar*)ATTR_RISE,(const xmlChar*)tmp);
        	sprintf(tmp,"%.2f",word->horizScaling);
        	xmlNewProp(node,(const xmlChar*)ATTR_HORIZ_SCALING,(const xmlChar*)tmp);
        	sprintf(tmp,"%.2f",word->wordSpace);
        	xmlNewProp(node,(const xmlChar*)ATTR_WORD_SPACE,(const xmlChar*)tmp);
        	sprintf(tmp,"%.2f",word->charSpace);
        	xmlNewProp(node,(const xmlChar*)ATTR_CHAR_SPACE,(const xmlChar*)tmp);
        	sprintf(tmp,"%.2f",word->base);
        	xmlNewProp(node,(const xmlChar*)ATTR_BASE,(const xmlChar*)tmp);
}

void TextPage::addAttributsNode(xmlNodePtr node, char* tmp, TextWord *word, double &xMaxi, double &yMaxi, double &yMinRot, double &yMaxRot, double &xMinRot, double &xMaxRot){ 	


  



  //if (word->font !=NULL && word->font->gfxFont!=NULL){
  //		  if (word->font->gfxFont->isSymbolic()){
  //		  	xmlNewProp(node,(const xmlChar*)ATTR_SYMBOLIC,(const xmlChar*)YES);
  //		  }
  //		  if (word->font->gfxFont->isSerif()){
  //		  	xmlNewProp(node,(const xmlChar*)ATTR_SERIF,(const xmlChar*)YES);
  //		  }
  //		  if (word->font->gfxFont->isFixedWidth()){
  //		  	xmlNewProp(node,(const xmlChar*)ATTR_FIXED_WIDTH,(const xmlChar*)YES);
  //		  }
  //}

  if(word->isBold()) xmlNewProp(node,(const xmlChar*)ATTR_BOLD,(const xmlChar*)YES);
  else xmlNewProp(node,(const xmlChar*)ATTR_BOLD,(const xmlChar*)NO);
      	
  if (word->isItalic()) xmlNewProp(node,(const xmlChar*)ATTR_ITALIC,(const xmlChar*)YES);
  else xmlNewProp(node,(const xmlChar*)ATTR_ITALIC,(const xmlChar*)NO);
      	
      	sprintf(tmp,"%.0f",word->fontSize);
      	xmlNewProp(node,(const xmlChar*)ATTR_FONT_SIZE,(const xmlChar*)tmp);
      
      	//xmlNewProp(node,(const xmlChar*)ATTR_FONT_COLOR,(const xmlChar*)word->colortoString()->getCString());
      	
      	//sprintf(tmp,"%d",word->rot);
	//	xmlNewProp(node,(const xmlChar*)ATTR_ROTATION,(const xmlChar*)tmp);
		
      	sprintf(tmp,"%d",word->angle);
	xmlNewProp(node,(const xmlChar*)ATTR_ANGLE,(const xmlChar*)tmp);

      	sprintf(tmp,"%.0f",word->xMin);
      	xmlNewProp(node,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);

      	sprintf(tmp,"%.0f",word->yMin);
      	xmlNewProp(node,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);

      	sprintf(tmp,"%.0f",word->xMax - word->xMin);
      	xmlNewProp(node,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
      	if (word->xMax > xMaxi) {xMaxi = word->xMax;}
      	if (word->xMin < xMinRot) {xMinRot = word->xMin;}	
      	if (word->xMax > xMaxRot) {xMaxRot = word->xMax;}	

      	//sprintf(tmp,"%.0f",word->yMax - word->yMin);
      	//xmlNewProp(node,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
      	//if (word->yMax > yMaxi) {yMaxi = word->yMax;}	
      	//if (word->yMin < yMinRot) {yMinRot = word->yMin;}	
      	//if (word->yMax > yMaxRot) {yMaxRot = word->yMax;}	
}

void TextPage::dump(GBool blocks, GBool fullFontName) {
	UnicodeMap *uMap;
    
  	TextWord *word;
  	GString *stringTemp;
  	
  	GString *id;
  	char* tmp;
  	
  	tmp=(char*)malloc(10*sizeof(char));

  	// For TEXT tag attributes
  	double xMin = 0;
  	double yMin = 0; 
  	double xMax = 0;
  	double yMax = 0;
  	double yMaxRot = 0;
  	double yMinRot = 0;
  	double xMaxRot = 0;
  	double xMinRot = 0;
  	int firstword= 1; // firstword of a TEXT tag

  	xmlNodePtr node = NULL;
  	xmlNodePtr nodeline = NULL;
  	xmlNodePtr nodeblocks = NULL;
  	xmlNodePtr nodeImageInline = NULL;

  	GBool lineFinish = gFalse;
  	GBool newBlock = gFalse;
  	GBool endPage = gFalse;
  	  	
  	// Informations about the current line
  	double lineX = 0;
  	double lineYmin = 0;
  	double lineWidth = 0;
  	double lineHeight = 0;
  	double lineFontSize = 0;
  	
  	// Informations about the previous line
  	double linePreviousX = 0;
  	double linePreviousYmin = 0;
  	double linePreviousWidth = 0;
  	double linePreviousHeight = 0;
  	double linePreviousFontSize = 0;
 
  	// Get the output encoding
  	if (!(uMap = globalParams->getTextEncoding())) {
    	return;
  	}	
	
	numText = 1;
	numBlock = 1;
  	// Output the page in raw (content stream) order
  	if (rawOrder) {
		lineFontSize = 0;
    	nodeline = xmlNewNode(NULL,(const xmlChar*)TAG_TEXT);
    	nodeline->type = XML_ELEMENT_NODE;
    	
    	if (blocks){
     		nodeblocks = xmlNewNode(NULL,(const xmlChar*)TAG_BLOCK);
    		nodeblocks->type = XML_ELEMENT_NODE;
    	}
    		
    	if (rawWords)  {
    		if (blocks){
    			xmlAddChild(page,nodeblocks);
    			id = new GString("p");
    			//xmlNewProp(nodeblocks,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdBlock(num, numBlock, id)->getCString());
    			delete id;
    			numBlock = numBlock + 1;
    		}else {
    			xmlAddChild(page,nodeline);
    		}
    	}
    	xMin= yMin = xMax = yMax =0;

    	// TEXT properties : first from first word
    	for (word = rawWords; word; word = word->next) {
    		lineFinish = gFalse;
    		if (firstword){
				xMin = word->xMin;
				yMin = word->yMin;
				xMax = word->xMax;
				yMax = word->yMax;
				yMaxRot = word->yMax;
				yMinRot = word->yMin;
				xMaxRot = word->xMax;
				xMinRot = word->xMin;
				sprintf(tmp,"%.0f",word->xMin);
				xmlNewProp(nodeline,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
				sprintf(tmp,"%.0f",word->yMin);
				xmlNewProp(nodeline,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);	
				lineX = word->xMin;
				lineYmin = word->yMin;
				firstword = 0;
				lineFontSize = 0;
     		}
      	
      	node = xmlNewNode(NULL,(const xmlChar*)TAG_TOKEN);
      	node->type = XML_ELEMENT_NODE;   	
      	id = new GString("p");
      	//xmlNewProp(node,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdToken(num, numToken, id)->getCString());
      	delete id;
		numToken = numToken + 1;

		stringTemp = new GString();

      	dumpFragment(word->text, word->len, uMap, stringTemp);

		if (word->fontSize > lineFontSize){
			lineFontSize = word->fontSize;
		}
		
      	// If option verbose is selected
      	if (verbose){
      		addAttributsNodeVerbose(node, tmp, word);
      	}
      	    	
      	if (word->getFontName()) {
      		// If the font name normalization option is selected
      		//if (fullFontName){
	  //xmlNewProp(node,(const xmlChar*)ATTR_FONT_NAME,(const xmlChar*)word->getFontName());
	  //}else{
	  //	xmlNewProp(node,(const xmlChar*)ATTR_FONT_NAME,(const xmlChar*)word->normalizeFontName(word->getFontName()));
	  //}
      	}
    	
	    addAttributsNode(node, tmp, word, xMax, yMax, yMinRot, yMaxRot, xMinRot, xMaxRot);
      	addAttributTypeReadingOrder(node, tmp, word);
      
      	xmlNodeSetContent(node,(const xmlChar*)xmlEncodeEntitiesReentrant(node->doc,(const xmlChar*)stringTemp->getCString()));
		
		delete stringTemp;
		  	
		double xxMin, xxMax, xxMinNext;
		double yyMin, yyMax, yyMinNext;
	
		// Rotation cases
  		switch (word->rot) {
  		case 0:
  			xxMin = word->xMin;
  			xxMax = word->xMax;
  			yyMin = word->yMin;
  			yyMax = word->yMax;
  			if (word->next){
  				xxMinNext = word->next->xMin;
  				yyMinNext = word->next->yMin;
  			}
    		break;
    
   		case 3:
  			xxMin = word->yMin;
  			xxMax = word->yMax;
  			yyMin = word->xMax;
  			yyMax = word->xMin;
  			if (word->next){ 
  				xxMinNext = word->next->yMin; 
  				yyMinNext = word->next->xMax;
  			}
    		break;
    
  		case 2:
  			xxMin = word->xMax;
  			xxMax = word->xMin;
  			yyMin = word->yMax;
  			yyMax = word->yMin;
  			if (word->next){ 
  				xxMinNext = word->next->xMax;
  				yyMinNext = word->next->yMax;
  			}
    		break;
    
   		case 1:
  			xxMin = word->yMax;
  			xxMax = word->yMin;
  			yyMin = word->xMax;
  			yyMax = word->xMin;
  			if (word->next){ 
  				xxMinNext = word->next->yMax;
  				yyMinNext = word->next->xMax;
  			}
    		break;
  		}	
  		
  		// Get the rotation into four axis
	  	int rotation = -1;
	  	if (word->rot==0 && word->angle==0){rotation = 0;}
	  	if (word->rot==1 && word->angle==90){rotation = 1;}
	  	if (word->rot==2 && word->angle==180){rotation = 2;}
	  	if (word->rot==3 && word->angle==270){rotation = 3;}

	  	// Add next images inline whithin the current line if the noImageInline option is not selected	  	
	  	if (!parameters->getImageInline()){
	  		if (indiceImage != -1){
	  			int nb = listeImageInline.size();
	  			for (; indiceImage<nb ; indiceImage++){
	  				if (idWORDBefore == listeImageInline[indiceImage]->idWordBefore){
	  					nodeImageInline = xmlNewNode(NULL,(const xmlChar*)TAG_TOKEN);
    					nodeImageInline->type = XML_ELEMENT_NODE;
    					id = new GString("p");
      					//xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdToken(num, numToken, id)->getCString());
      					delete id;
						numToken = numToken + 1;				
    					sprintf(tmp,"%d",listeImageInline[indiceImage]->getXPositionImage());
						xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
						sprintf(tmp,"%d",listeImageInline[indiceImage]->getYPositionImage());
						xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);
						sprintf(tmp,"%d",listeImageInline[indiceImage]->getWidthImage());
						xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
						sprintf(tmp,"%d",listeImageInline[indiceImage]->getHeightImage());
						xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
						xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_HREF,(const xmlChar*)listeImageInline[indiceImage]->getHrefImage()->getCString());
    					xmlAddChild(nodeline,nodeImageInline);
	  				}
	  			}	  	
	  		}
	  	}

	  	// Add the attributes width and height to the node TEXT
	  	// The line is finish IF :
	  	// 		- there is no next word 
	  	//		- or IF the rotation if current word is different of the rotation next word
	  	//		- or IF the difference between the base of current word and the yMin next word is superior to the maxSpacingWordsBetweenTwoLines
	  	//		- or IF the difference between the base of current word and the base next word is superior to maxIntraLineDelta * lineFontSize
	  	//		- or IF the xMax current word ++ maxWordSpacing * lineFontSize is superior to the xMin next word.
      	if ( word->next && (word->rot==word->next->rot) &&
      		(( (fabs(word->base - word->next->baseYmin) < maxSpacingWordsBetweenTwoLines) ||
      		   (fabs(word->next->base - word->base) < maxIntraLineDelta * lineFontSize) ) && 
      		   (word->next->xMin <= word->xMax + maxWordSpacing * lineFontSize) )) {   

			// IF - switch the rotation : 
			//			base word and yMin word are inferior to yMin next word
			//			xMin word is superior to xMin next word
			//			xMax word is superior to xMin next word and the difference between the base of current word and the next word is superior to maxIntraLineDelta*lineFontSize
			//			xMin next word is superior to xMax word + maxWordSpacing * lineFontSize
			//THEN if one of these tests is true, the line is finish
			if (( (rotation==-1) ? ((word->base < word->next->yMin) && (word->yMin < word->next->yMin)) : (word->rot==0||word->rot==1) ? ((word->base < yyMinNext) && (yyMin < yyMinNext)) : ((word->base > yyMinNext) && (yyMin > yyMinNext)) ) || 
				( (rotation==-1) ? (word->next->xMin < word->xMin) : (word->rot==0) ? (xxMinNext < xxMin) : (word->rot==1 ? xxMinNext > xxMin : (word->rot==2 ? xxMinNext > xxMin : xxMinNext < xxMin) ) ) || 
				( (rotation==-1) ? (word->next->xMin<word->xMax) && (fabs(word->next->base-word->base)>maxIntraLineDelta*lineFontSize) : (word->rot==0||word->rot==3) ? ( (xxMinNext<xxMax) && (fabs(word->next->base-word->base)>maxIntraLineDelta*lineFontSize) ) : ( (xxMinNext > xxMax) && (fabs(word->next->base-word->base)>maxIntraLineDelta*lineFontSize) )) ||
				( (rotation==-1) ? (word->next->xMin > word->xMax + maxWordSpacing * lineFontSize) : (word->rot==0||word->rot==3) ? (xxMinNext > xxMax + maxWordSpacing * lineFontSize) : (xxMinNext < xxMax - maxWordSpacing * lineFontSize))){
	
		  		xmlAddChild(nodeline,node);
				double arr;
				if (word->rot==2){
		  			arr = fabs(ceil(xMaxRot-xMinRot));
		  			sprintf(tmp,"%.0f",arr);
		  			xmlNewProp(nodeline,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);			
					lineWidth = arr;
				}else{
					arr = ceil(xMax-xMin);
		  			sprintf(tmp,"%.0f",arr);
		  			xmlNewProp(nodeline,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);			
					lineWidth = arr;
				}
				
				if (word->rot==0||word->rot==2){
		  			arr = ceil(yMax-yMin);
		  			sprintf(tmp,"%.0f",arr);
		  			xmlNewProp(nodeline,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
					lineHeight = arr;
				}
				
				if (word->rot==1||word->rot==3){
					arr = ceil(yMaxRot-yMinRot);
		  			sprintf(tmp,"%.0f",arr);
		  			xmlNewProp(nodeline,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
					lineHeight = arr;
				}
				
				// Add the ID attribute for the TEXT tag
				id = new GString("p");
				//xmlNewProp(nodeline,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdText(num, numText, id)->getCString());
				delete id;
				numText = numText + 1;
					
				if (word->fontSize > lineFontSize){
					lineFontSize = word->fontSize;
				}
				
				// Include a TOKEN tag for the image inline if it exists
				if (!parameters->getImageInline()){
  					addImageInlineNode(nodeline, nodeImageInline, tmp, word);
				}
				
				if (word->next){
	    			firstword = 1;
	    			if (blocks){
	    				lineFinish = gTrue;
	    			}else {
	    				nodeline = xmlNewNode(NULL,(const xmlChar*)TAG_TEXT);
	    				nodeline->type = XML_ELEMENT_NODE;	    				
	    				xmlAddChild(page,nodeline);	   
	    			} 				
	  			}else{
					endPage = gTrue;
				}  				
	  			xMin = yMin = xMax = yMax = yMinRot = yMaxRot = xMaxRot = xMinRot = 0;
			}
			else{
	  			xmlAddChild(nodeline,node);
	  			
	  			// Include a TOKEN tag for the image inline if it exists
	  			if (!parameters->getImageInline()){
  					addImageInlineNode(nodeline, nodeImageInline, tmp, word);
	  			}
			}
    	}
    	else {
    		double arr;
			if (word->rot==2){
    			arr = fabs(ceil(xMaxRot-xMinRot));
    			sprintf(tmp,"%.0f",arr);
				xmlNewProp(nodeline,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
				lineWidth = arr;
			}
			else{
				arr = ceil(xMax-xMin);
    			sprintf(tmp,"%.0f",arr);
				xmlNewProp(nodeline,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
				lineWidth = arr;
			}
			
			if (word->rot==0||word->rot==2){
				arr = ceil(yMax-yMin);
				sprintf(tmp,"%.0f",arr);
				xmlNewProp(nodeline,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
				lineHeight = arr;
			}
			
			if (word->rot==1||word->rot==3){
				arr = ceil(yMaxRot-yMinRot);
		  		sprintf(tmp,"%.0f",arr);
		  		xmlNewProp(nodeline,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
				lineHeight = arr;
			}
			
			xmlAddChild(nodeline,node);
			
			// Include a TOKEN tag for the image inline if it exists
			if (!parameters->getImageInline()){
				addImageInlineNode(nodeline, nodeImageInline, tmp, word);
			}
			
			// Add the ID attribute for the TEXT tag
			id = new GString("p");
			//xmlNewProp(nodeline,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdText(num, numText, id)->getCString());
			delete id;
			numText = numText + 1;
				
			if (word->fontSize > lineFontSize){
				lineFontSize = word->fontSize;
			}
			
			firstword = 1;
			xMin = yMin = xMax = yMax = yMinRot = yMaxRot = xMaxRot = xMinRot = 0;
		
			if (word->next){
				if (blocks){
					lineFinish = gTrue;
				}else{
	  				nodeline = xmlNewNode(NULL,(const xmlChar*)TAG_TEXT);
	  				nodeline->type = XML_ELEMENT_NODE;
	  				xmlAddChild(page,nodeline);	  	
				}			
			}else{
				endPage = gTrue;
			}
      	}
  			
  		// IF block option is selected
  		// IF it's the end of line or the end of page   			
      	if ( (blocks && lineFinish) || (blocks && endPage)){
      		// IF it's the first line
      		if (linePreviousX == 0) {
      			if (word->next){
      				if ( word->next->xMin > (lineX + lineWidth) + (maxColSpacing * lineFontSize)){
    	  				newBlock = gTrue; 				
      				} 
      			}
    			xmlAddChild(nodeblocks,nodeline);      			
      		} 
      		else { 
      			if (newBlock){
      				nodeblocks = xmlNewNode(NULL,(const xmlChar*)TAG_BLOCK);
    				nodeblocks->type = XML_ELEMENT_NODE;
    				xmlAddChild(page,nodeblocks);
    				id = new GString("p");
    				//xmlNewProp(nodeblocks,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdBlock(num, numBlock, id)->getCString());
    				delete id;
    				numBlock = numBlock + 1;
    				xmlAddChild(nodeblocks,nodeline);
					newBlock = gFalse;
      			}else{   			
      				if (((lineYmin + lineHeight) >= linePreviousYmin) 
      				&& (fabs(lineFontSize - linePreviousFontSize) < lineFontSize * maxBlockFontSizeDelta1)
      				&& ((lineYmin - linePreviousYmin) < (linePreviousFontSize * maxLineSpacingDelta))){    					
      					xmlAddChild(nodeblocks,nodeline);
      				} else {
      					nodeblocks = xmlNewNode(NULL,(const xmlChar*)TAG_BLOCK);
    					nodeblocks->type = XML_ELEMENT_NODE;
    					xmlAddChild(page,nodeblocks);
    					id = new GString("p");
    					//xmlNewProp(nodeblocks,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdBlock(num, numBlock, id)->getCString());
    					delete id;
    					numBlock = numBlock + 1;
    					xmlAddChild(nodeblocks,nodeline);
      				}
      			}
      		}
      		if (endPage){endPage = gFalse;}
      		      			
      		// We save informations about the future previous line
      		linePreviousX = lineX;
      		linePreviousYmin = lineYmin;
      		linePreviousWidth = lineWidth;
      		linePreviousHeight = lineHeight;
      		linePreviousFontSize = lineFontSize;
      		
      		nodeline = xmlNewNode(NULL,(const xmlChar*)TAG_TEXT);
	  		nodeline->type = XML_ELEMENT_NODE;
      	}
    } // end FOR
  	} 
  	free(tmp);
  	delete word;
  	uMap->decRefCnt();
}

void TextPage::addImageInlineNode(xmlNodePtr nodeline, xmlNodePtr nodeImageInline, char* tmp, TextWord *word){
	indiceImage = -1;
	idWORDBefore = -1;
	GBool first = gTrue;
	int nb = listeImageInline.size();
  	for (int i=0 ; i<nb ; i++){
  		if (word->idWord == listeImageInline[i]->idWordBefore){
  			if (listeImageInline[i]->getXPositionImage()>word->xMax && listeImageInline[i]->getYPositionImage()<= word->yMax){  		
  				nodeImageInline = xmlNewNode(NULL,(const xmlChar*)TAG_TOKEN);
    			nodeImageInline->type = XML_ELEMENT_NODE;
    			GString *id;
    			id = new GString("p");
      			//xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdToken(num, numToken, id)->getCString());
      			delete id;
				numToken = numToken + 1;
    			sprintf(tmp,"%d",listeImageInline[i]->getXPositionImage());
				xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
				sprintf(tmp,"%d",listeImageInline[i]->getYPositionImage());
				xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);
				sprintf(tmp,"%d",listeImageInline[i]->getWidthImage());
				xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
				sprintf(tmp,"%d",listeImageInline[i]->getHeightImage());
				xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
				xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_HREF,(const xmlChar*)listeImageInline[i]->getHrefImage()->getCString());
    			xmlAddChild(nodeline,nodeImageInline);
    			idImageInline = listeImageInline[i]->getIdImageCurrent();
  			}
    		int j = i;
    		for (;j<nb ; j++) {
    			if (word->idWord == listeImageInline[j]->idWordBefore){
    				if (listeImageInline[j]->getXPositionImage()>word->xMax && listeImageInline[j]->getYPositionImage()<= word->yMax){ 
    					if (idImageInline != listeImageInline[j]->getIdImageCurrent()){	  				  		
    			  			nodeImageInline = xmlNewNode(NULL,(const xmlChar*)TAG_TOKEN);
    						nodeImageInline->type = XML_ELEMENT_NODE;
    						GString *id;
    						id = new GString("p");
      						//xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdToken(num, numToken, id)->getCString());
      						delete id;
							numToken = numToken + 1;
    						sprintf(tmp,"%d",listeImageInline[j]->getXPositionImage());
							xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
							sprintf(tmp,"%d",listeImageInline[j]->getYPositionImage());
							xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);
							sprintf(tmp,"%d",listeImageInline[j]->getWidthImage());
							xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
							sprintf(tmp,"%d",listeImageInline[j]->getHeightImage());
							xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
							xmlNewProp(nodeImageInline,(const xmlChar*)ATTR_HREF,(const xmlChar*)listeImageInline[j]->getHrefImage()->getCString());
	   						xmlAddChild(nodeline,nodeImageInline);
							idImageInline = listeImageInline[j]->getIdImageCurrent();
    					}
    				}else{
    					if (first){
    						indiceImage = j;
    						idWORDBefore = word->idWord;
    						first = gFalse;
    					}
    				}
    			}
    		}
    		break;
  		}
  	}
}

GString* TextPage::buildIdImage(int pageNum, int imageNum, GString *id){
	char* tmp=(char*)malloc(10*sizeof(char));
	sprintf(tmp,"%d",pageNum);
	id->append(tmp);
	id->append("_i");
	sprintf(tmp,"%d",imageNum);
	id->append(tmp);
	free(tmp);
	return id;
}

GString* TextPage::buildIdText(int pageNum, int textNum, GString *id){
	char* tmp=(char*)malloc(10*sizeof(char));
	sprintf(tmp,"%d",pageNum);
	id->append(tmp);
	id->append("_t");
	sprintf(tmp,"%d",textNum);
	id->append(tmp);
	free(tmp);
	return id;
}

GString* TextPage::buildIdToken(int pageNum, int tokenNum, GString *id){
	char* tmp=(char*)malloc(10*sizeof(char));
	sprintf(tmp,"%d",pageNum);
	id->append(tmp);
	id->append("_w");
	sprintf(tmp,"%d",tokenNum);
	id->append(tmp);
	free(tmp);
	return id;
}

GString* TextPage::buildIdBlock(int pageNum, int blockNum, GString *id){
	char* tmp=(char*)malloc(10*sizeof(char));
	sprintf(tmp,"%d",pageNum);
	id->append(tmp);
	id->append("_b");
	sprintf(tmp,"%d",blockNum);
	id->append(tmp);
	free(tmp);
	return id;
}

GString* TextPage::buildIdClipZone(int pageNum, int clipZoneNum, GString *id){
	char* tmp=(char*)malloc(10*sizeof(char));
	sprintf(tmp,"%d",pageNum);
	id->append(tmp);
	id->append("_c");
	sprintf(tmp,"%d",clipZoneNum);
	id->append(tmp);
	free(tmp);
	return id;
}

int TextPage::dumpFragment(Unicode *text, int len, UnicodeMap *uMap, GString *s) {
  char lre[8], rle[8], popdf[8], buf[8];
  int lreLen, rleLen, popdfLen, n;
  int nCols, i, j, k;

  nCols = 0;
 
  // Unicode OK
  if (uMap->isUnicode()) {

    lreLen = uMap->mapUnicode(0x202a, lre, sizeof(lre));
    rleLen = uMap->mapUnicode(0x202b, rle, sizeof(rle));
    popdfLen = uMap->mapUnicode(0x202c, popdf, sizeof(popdf));

	// IF primary direction is Left to Right
    if (primaryLR) {

      i = 0;
      while (i < len) {
		// output a left-to-right section
		for (j = i; j < len && !unicodeTypeR(text[j]); ++j) ;
		for (k = i; k < j; ++k) {
	  		n = uMap->mapUnicode(text[k], buf, sizeof(buf));
	  		s->append(buf, n);
	  		++nCols;
		}
		i = j;
		// output a right-to-left section
		for (j = i; j < len && !unicodeTypeL(text[j]); ++j) ;
		if (j > i) {
	  		s->append(rle, rleLen);
	  		for (k = j - 1; k >= i; --k) {
	    		n = uMap->mapUnicode(text[k], buf, sizeof(buf));
	    		s->append(buf, n);
	    		++nCols;
	  		}
	  		s->append(popdf, popdfLen);
	  		i = j;
		}
      }

    } 
    // ELSE primary direction is Right to Left
    else {

      	s->append(rle, rleLen);
      	i = len - 1;
      	while (i >= 0) {
			// output a right-to-left section
			for (j = i; j >= 0 && !unicodeTypeL(text[j]); --j) ;
			for (k = i; k > j; --k) {
	 			n = uMap->mapUnicode(text[k], buf, sizeof(buf));
	  			s->append(buf, n);
	  			++nCols;
			}
			i = j;
			// output a left-to-right section
			for (j = i; j >= 0 && !unicodeTypeR(text[j]); --j) ;
			if (j < i) {
	  			s->append(lre, lreLen);
	  			for (k = j + 1; k <= i; ++k) {
	    			n = uMap->mapUnicode(text[k], buf, sizeof(buf));
	    			s->append(buf, n);
	    			++nCols;
	  			}
	  			s->append(popdf, popdfLen);
	  			i = j;
			}
      }
      s->append(popdf, popdfLen);
    }
  }
  // Unicode NOT OK 
  else {
  	for (i = 0; i < len; ++i) {
      n = uMap->mapUnicode(text[i], buf, sizeof(buf));
      s->append(buf, n);
      nCols += n;
    }
  }

  return nCols;
}

void TextPage::saveState(GfxState *state) {
	idClipBefore = idClip;
	idClip++;
	beginZoneClip = 1;
	endZoneClip = 2;
}

void TextPage::restoreState(GfxState *state) {
	beginZoneClip = 2;
	endZoneClip = 1;
}

void TextPage::doPathForClip(GfxPath *path, GfxState *state, xmlNodePtr currentNode) {
  	char * tmp; 
  	tmp = (char*)malloc(500*sizeof(char));
  
  	xmlNodePtr groupNode = NULL;
  
  	// GROUP tag
  	groupNode = xmlNewNode(NULL,(const xmlChar*)TAG_GROUP);
  	xmlAddChild(currentNode, groupNode);
  
  	createPath(path, state, groupNode);
    free(tmp);
}

void TextPage::doPath(GfxPath *path, GfxState *state, GString* gattributes) {
  	char *tmp; 
  	tmp = (char*)malloc(500*sizeof(char));
  
  	xmlNodePtr groupNode = NULL;
  
  	// GROUP tag
  	groupNode = xmlNewNode(NULL,(const xmlChar*)TAG_GROUP);
  	xmlAddChild(vecroot, groupNode);

  	xmlNewProp(groupNode,(const xmlChar*)ATTR_STYLE,(const xmlChar*)gattributes->getCString());

  	if ((beginZoneClip==1 && endZoneClip==2) || (beginZoneClip==2 && endZoneClip==1)){
  		if ((beginZoneClip==2 && endZoneClip==1)){
   			GString *id;
   			id = new GString("p");
   			xmlNewProp(groupNode,(const xmlChar*)ATTR_CLIPZONE,(const xmlChar*)buildIdClipZone(num, idClipBefore, id)->getCString());
   			delete id;
  		}else{
   			GString *id;
   			id = new GString("p");
   			xmlNewProp(groupNode,(const xmlChar*)ATTR_CLIPZONE,(const xmlChar*)buildIdClipZone(num, idClip, id)->getCString());
   			delete id;
  		}
  	}
 	createPath(path, state, groupNode);
  	free(tmp);
}

void TextPage::createPath(GfxPath *path, GfxState *state, xmlNodePtr groupNode){
	GfxSubpath *subpath;
  	double x0, y0, x1, y1, x2, y2, x3, y3;
  	int n, m, i, j;
  	double a,b;
    char *tmp; 
  	tmp = (char*)malloc(500*sizeof(char));
  
    xmlNodePtr pathnode = NULL;
  
	n = path->getNumSubpaths();

  	for (i = 0; i < n; ++i) {
    	subpath = path->getSubpath(i);
    	m = subpath->getNumPoints();  
    	x0 = subpath->getX(0);
    	y0 = subpath->getY(0);
    	state->transform(x0, y0, &a, &b);
    	x0 = a; 
    	y0 = b;
    
    	// M tag : moveto
    	pathnode = xmlNewNode(NULL,(const xmlChar*)TAG_M);
    	sprintf(tmp,"%g",x0);
    	xmlNewProp(pathnode,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
    	sprintf(tmp,"%g",y0);
    	xmlNewProp(pathnode,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);
    	xmlAddChild(groupNode,pathnode);

    	j = 1;
    	while (j < m) {
      		if (subpath->getCurve(j)) {
				x1 = subpath->getX(j);
				y1 = subpath->getY(j);
				x2 = subpath->getX(j+1);
				y2 = subpath->getY(j+1);
				x3 = subpath->getX(j+2);
				y3 = subpath->getY(j+2);
				state->transform(x1, y1, &a, &b);
				x1 = a; 
				y1=b;
				state->transform(x2, y2, &a, &b);
				x2 = a; 
				y2=b;
				state->transform(x3, y3, &a, &b);
				x3 = a; 
				y3=b;
		
				// C tag  : curveto
				pathnode=xmlNewNode(NULL,(const xmlChar*)TAG_C);
				sprintf(tmp,"%g",x1);
				xmlNewProp(pathnode,(const xmlChar*)ATTR_X1,(const xmlChar*)tmp);
				sprintf(tmp,"%g",y1);
				xmlNewProp(pathnode,(const xmlChar*)ATTR_Y1,(const xmlChar*)tmp);
				sprintf(tmp,"%g",x2);
				xmlNewProp(pathnode,(const xmlChar*)ATTR_X2,(const xmlChar*)tmp);
				sprintf(tmp,"%g",y2);
				xmlNewProp(pathnode,(const xmlChar*)ATTR_Y2,(const xmlChar*)tmp);
				sprintf(tmp,"%g",x3);
				xmlNewProp(pathnode,(const xmlChar*)ATTR_X3,(const xmlChar*)tmp);
				sprintf(tmp,"%g",y3);
				xmlNewProp(pathnode,(const xmlChar*)ATTR_Y3,(const xmlChar*)tmp);
				xmlAddChild(groupNode,pathnode);

				j += 3;
      		} 
      		else {
				x1 = subpath->getX(j);
				y1 = subpath->getY(j);
				state->transform(x1, y1, &a, &b);
				x1 = a; 
				y1=b;
		
				// L tag : lineto
				pathnode=xmlNewNode(NULL,(const xmlChar*)TAG_L);
				sprintf(tmp,"%g",x1);
				xmlNewProp(pathnode,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
				sprintf(tmp,"%g",y1);
				xmlNewProp(pathnode,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);
				xmlAddChild(groupNode,pathnode);

				++j;
      		}
    	}
    
    	if (subpath->isClosed()) {
      		if (!xmlHasProp(groupNode,(const xmlChar*)ATTR_CLOSED)){
        		xmlNewProp(groupNode,(const xmlChar*)ATTR_CLOSED,(const xmlChar*)"true");
      		}
    	}
  	}
  	free(tmp);
}

void TextPage::clip(GfxState *state) {
	idClipBefore = idClip;
	idClip++;
    xmlNodePtr gnode = NULL;
  	char tmp[100];
  	double xMin = 0;
  	double yMin = 0;
  	double xMax = 0;
  	double yMax = 0;
 
 	// CLIP tag
  	gnode = xmlNewNode(NULL,(const xmlChar*)TAG_CLIP);
  	xmlAddChild(vecroot,gnode);

   	// Get the clipping box 
   	state->getClipBBox(&xMin,&yMin,&xMax,&yMax);
   	sprintf(tmp,"%g",xMin);
   	xmlNewProp(gnode,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
   	sprintf(tmp,"%g",yMin);
   	xmlNewProp(gnode,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);
   	sprintf(tmp,"%g",xMax-xMin);
   	xmlNewProp(gnode,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
   	sprintf(tmp,"%g",yMax-yMin);
   	xmlNewProp(gnode,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
   	
   	GString *id; 
   	id = new GString("p");
   	xmlNewProp(gnode,(const xmlChar*)ATTR_IDCLIPZONE,(const xmlChar*)buildIdClipZone(num, idClip, id)->getCString());
   	delete id;

   	doPathForClip(state->getPath(), state, gnode);
}

void TextPage::eoClip(GfxState *state) { 
  	idClipBefore = idClip;
	idClip++;
  	xmlNodePtr gnode = NULL;
  	char tmp[100];
  	double xMin = 0;
  	double yMin = 0;
  	double xMax = 0;
  	double yMax = 0;
  
  	// CLIP tag
  	gnode=xmlNewNode(NULL,(const xmlChar*)TAG_CLIP);
  	xmlAddChild(vecroot,gnode);

   	// Get the clipping box 
   	state->getClipBBox(&xMin,&yMin,&xMax,&yMax);
   	sprintf(tmp,"%g",xMin);
   	xmlNewProp(gnode,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
   	sprintf(tmp,"%g",yMin);
   	xmlNewProp(gnode,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);
   	sprintf(tmp,"%g",xMax-xMin);
   	xmlNewProp(gnode,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
   	sprintf(tmp,"%g",yMax-yMin);
   	xmlNewProp(gnode,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
   	
   	GString *id;
   	id = new GString("p");
   	xmlNewProp(gnode,(const xmlChar*)ATTR_IDCLIPZONE,(const xmlChar*)buildIdClipZone(num, idClip, id)->getCString());
   	delete id;

   	xmlNewProp(gnode,(const xmlChar*)ATTR_EVENODD,(const xmlChar*)"true");
   	
   	doPathForClip(state->getPath(), state, gnode);
}

// Draw the image mask
void TextPage::drawImageMask(GfxState *state, Object *ref, Stream *str,
			      int width, int height, GBool invert,
			      GBool inlineImg, GBool dumpJPEG, int imageIndex) {

  int i;
  FILE *f;
  int c;
  int size;
  
  int x0, y0;				// top left corner of image
  int w0, h0, w1, h1;		// size of image
  double xt, yt, wt, ht;
  GBool rotate, xFlip, yFlip;
  char tmp[10];
  
  xmlNodePtr node = NULL;
 
  // get image position and size
  state->transform(0, 0, &xt, &yt);
  state->transformDelta(1, 1, &wt, &ht);
  if (wt > 0) {
    x0 = xoutRound(xt);
    w0 = xoutRound(wt);
  } else {
    x0 = xoutRound(xt + wt);
    w0 = xoutRound(-wt);
  }
  if (ht > 0) {
    y0 = xoutRound(yt);
    h0 = xoutRound(ht);
  } else {
    y0 = xoutRound(yt + ht);
    h0 = xoutRound(-ht);
  }
  state->transformDelta(1, 0, &xt, &yt);
  rotate = fabs(xt) < fabs(yt);
  if (rotate) {
    w1 = h0;
    h1 = w0;
    xFlip = ht < 0;
    yFlip = wt > 0;
  } else {
    w1 = w0;
    h1 = h0;
    xFlip = wt < 0;
    yFlip = ht > 0;
  }
  
  GString *relname = new GString(RelfileName);
  relname->append("-");
  relname->append(GString::fromInt(imageIndex));
  
  GString *refname = new GString(ImgfileName);
  refname->append("-");
  refname->append(GString::fromInt(imageIndex));
    
  // HREF
  if (dumpJPEG && str->getKind() == strDCT && !inlineImg) {
		relname->append(".jpg");
      	refname->append(".jpg");
		// initialize stream
    	str = ((DCTStream *)str)->getRawStream();
    	str->reset();

    	// copy the stream
    	while ((c = str->getChar()) != EOF)
      		fputc(c, f);

    	str->close();
    	fclose(f);	
  }
  else{
  		// open the image file and write the PBM header
  		relname->append(".pbm");
      	refname->append(".pbm");

    	if (!(f = fopen(relname->getCString(), "wb"))) {
     		error(-1, "Couldn't open image file '%s'", relname->getCString());
      		return;
    	}
    	fprintf(f, "P4\n");
    	fprintf(f, "%d %d\n", width, height);

    	// initialize stream
    	str->reset();

    	// copy the stream
    	size = height * ((width + 7) / 8);
    	for (i = 0; i < size; ++i) {
      		fputc(str->getChar(), f);
    	}

    	str->close();
    	fclose(f);
  }
  
  if (!inlineImg || (inlineImg && parameters->getImageInline())) {
  	node = xmlNewNode(NULL,(const xmlChar*)TAG_IMAGE);
  	GString *id;
    id = new GString("p");
    //xmlNewProp(node,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdImage(num, numImage, id)->getCString());
    delete id;
	numImage = numImage + 1;  	
  	sprintf(tmp,"%d",x0);
  	xmlNewProp(node,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
  	sprintf(tmp,"%d",y0);
  	xmlNewProp(node,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);
  	sprintf(tmp,"%d",w0);
  	xmlNewProp(node,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
  	sprintf(tmp,"%d",h0);
  	xmlNewProp(node,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
  	sprintf(tmp,"%d",inlineImg);
  	xmlNewProp(node,(const xmlChar*)ATTR_INLINE,(const xmlChar*)tmp);
  	xmlNewProp(node,(const xmlChar*)ATTR_MASK,(const xmlChar*)YES);
  	xmlNewProp(node,(const xmlChar*)ATTR_HREF,(const xmlChar*)refname->getCString());
  	xmlAddChild(page,node);
  }
  
  if (inlineImg && !parameters->getImageInline()){
  	listeImageInline.push_back(new ImageInline(x0, y0, w0, h0, getIdWORD(), imageIndex, refname));
  }
  

  
  return;
}

// Draw the image
void TextPage::drawImage(GfxState *state, Object *ref, Stream *str,
			  int width, int height, GfxImageColorMap *colorMap,
			  int *maskColors, GBool inlineImg, GBool dumpJPEG, int imageIndex) {
  int i; 
  FILE *f;
  int size;
  Guchar *p;
  GfxRGB rgb;
  ImageStream *imgStr;
  int c;
  int x0, y0;				// top left corner of image
  int w0, h0, w1, h1;		// size of image
  double xt, yt, wt, ht;
  GBool rotate, xFlip, yFlip;
  int x, y;

  xmlNodePtr node = NULL;
  
  char tmp[10];
 
  // get image position and size
  state->transform(0, 0, &xt, &yt);
  state->transformDelta(1, 1, &wt, &ht);
  if (wt > 0) {
    x0 = xoutRound(xt);
    w0 = xoutRound(wt);
  } else {
    x0 = xoutRound(xt + wt);
    w0 = xoutRound(-wt);
  }
  if (ht > 0) {
    y0 = xoutRound(yt);
    h0 = xoutRound(ht);
  } else {
    y0 = xoutRound(yt + ht);
    h0 = xoutRound(-ht);
  }
  state->transformDelta(1, 0, &xt, &yt);
  rotate = fabs(xt) < fabs(yt);
  if (rotate) {
    w1 = h0;
    h1 = w0;
    xFlip = ht < 0;
    yFlip = wt > 0;
  } else {
    w1 = w0;
    h1 = h0;
    xFlip = wt < 0;
    yFlip = ht > 0;
  }

  GString *relname = new GString(RelfileName);
  relname->append("-");
  relname->append(GString::fromInt(imageIndex));
  
  GString *refname = new GString(ImgfileName);
  refname->append("-");
  refname->append(GString::fromInt(imageIndex));

  // HREF
  if (dumpJPEG && str->getKind() == strDCT &&
      colorMap->getNumPixelComps() == 3 &&
      !inlineImg) {
   		refname->append(".jpg");
   		relname->append(".jpg");
		if (!(f = fopen(relname->getCString(), "wb"))) {
      		error(-1, "Couldn't open image file '%s'", relname->getCString());
      		return;
    	}

    	// initialize stream
    	str = ((DCTStream *)str)->getRawStream();
    	str->reset();

    	// copy the stream
    	while ((c = str->getChar()) != EOF)
      		fputc(c, f);

    	str->close();
    	fclose(f); 	
  }
  else if (colorMap->getNumPixelComps() == 1 &&
	     colorMap->getBits() == 1) {
	   	refname->append(".pbm");
      	relname->append(".pbm");
      	
	    // open the image file and write the PBM header
    	if (!(f = fopen(relname->getCString(), "wb"))) {
      		error(-1, "Couldn't open image file '%s'", relname->getCString());
      		return;
    	}
    	fprintf(f, "P4\n");
    	fprintf(f, "%d %d\n", width, height);

    	// initialize stream
    	str->reset();

    	// copy the stream
    	size = height * ((width + 7) / 8);
    	for (i = 0; i < size; ++i) {
      		fputc(str->getChar() ^ 0xff, f);
    	}

    	str->close();
    	fclose(f);     	
  }
  else{
  		refname->append(".ppm");
      	relname->append(".ppm");
  		if (!(f = fopen(relname->getCString(), "wb"))) {
      		error(-1, "Couldn't open image file '%s'", relname->getCString());
      		return;
    	}
    	fprintf(f, "P6\n");
    	fprintf(f, "%d %d\n", width, height);
    	fprintf(f, "255\n");

    	// initialize stream
    	imgStr = new ImageStream(str, width, colorMap->getNumPixelComps(), colorMap->getBits());
    	imgStr->reset();

    	// for each lin21e...
    	for (y = 0; y < height; ++y) {

      		// write the line
      		p = imgStr->getLine();
      		for (x = 0; x < width; ++x) {
				colorMap->getRGB(p, &rgb);
				fputc((int)(rgb.r * 255 + 0.5), f);
				fputc((int)(rgb.g * 255 + 0.5), f);
				fputc((int)(rgb.b * 255 + 0.5), f);
				p += colorMap->getNumPixelComps();
      		}
    	}
    	delete imgStr;
    	fclose(f);	 
  }
  
  if (!inlineImg || (inlineImg && parameters->getImageInline())) {
	node = xmlNewNode(NULL,(const xmlChar*)TAG_IMAGE);
  	GString *id;
    id = new GString("p");
    //xmlNewProp(node,(const xmlChar*)ATTR_ID,(const xmlChar*)buildIdImage(num, numImage, id)->getCString());
    delete id;
	numImage = numImage + 1;
  	sprintf(tmp,"%d",x0);
  	xmlNewProp(node,(const xmlChar*)ATTR_X,(const xmlChar*)tmp);
  	sprintf(tmp,"%d",y0);
  	xmlNewProp(node,(const xmlChar*)ATTR_Y,(const xmlChar*)tmp);
  	sprintf(tmp,"%d",w0);
  	xmlNewProp(node,(const xmlChar*)ATTR_WIDTH,(const xmlChar*)tmp);
  	sprintf(tmp,"%d",h0);
  	xmlNewProp(node,(const xmlChar*)ATTR_HEIGHT,(const xmlChar*)tmp);
  	sprintf(tmp,"%d",inlineImg);
  	xmlNewProp(node,(const xmlChar*)ATTR_INLINE,(const xmlChar*)tmp);
  	xmlNewProp(node,(const xmlChar*)ATTR_HREF,(const xmlChar*)refname->getCString());
    xmlAddChild(page,node);
  }
  
  if (inlineImg && !parameters->getImageInline()){
  	listeImageInline.push_back(new ImageInline(x0, y0, w0, h0, getIdWORD(), imageIndex, refname));
  }

  return;
}

//------------------------------------------------------------------------
// XmlOutputDev
//------------------------------------------------------------------------

XmlOutputDev::XmlOutputDev(GString *fileName, GString *fileNamePdf, GBool physLayoutA,
			     GBool verboseA, GString *nsURIA, GString *cmdA) {
  	text = NULL;
  	physLayout = physLayoutA;
  	rawOrder = 1;
  	ok = gTrue;
  	doc = NULL;
  	vecdoc = NULL;
  	docroot = NULL;
  	vecroot = NULL;
  	verbose = verboseA;
  	GString *imgDirName;
  	
  	blocks = parameters->getDisplayBlocks();
  	fullFontName = parameters->getFullFontName();
  	noImageInline = parameters->getImageInline();
  	
  	fileNamePDF = new GString(fileNamePdf);

  	if (nsURIA){
  		nsURI = new GString(nsURIA);
  	}else{
  		nsURI = NULL;
  	}

  	myfilename = new GString(fileName);

	dataDir = new GString(fileName);
 	dataDir->append("_data");
  	imgDirName = new GString(dataDir);
 		
  	// Display images
  	if (parameters->getDisplayImage() || !parameters->getCutAllPages()){

  	#ifdef WIN32
  		_mkdir(dataDir->getCString()); 
  	#else
	  	mkdir(dataDir->getCString(),00777);
  	#endif
  
  	
  	imgDirName->append("/image");
  	imageIndex = 0;
  
  	#ifndef WIN32
	  char *aux = strdup(fileName->getCString());
	  baseFileName = new GString(basename(aux));
	  baseFileName->append("_data/image");
	  free(aux);
  	#endif
 
  	#ifdef WIN32
 		baseFileName = new GString(fileName);
 		baseFileName->append("_data/image");
  	#endif
	  
   	}// end IF

  doc = xmlNewDoc((const xmlChar*)VERSION);

  globalParams->setTextEncoding((char*)ENCODING_UTF8);
  doc->encoding = xmlStrdup((const xmlChar*)ENCODING_UTF8);
  docroot = xmlNewNode(NULL,(const xmlChar*)TAG_DOCUMENT);
  
  // The namespace DS to add at the DOCUMENT tag
  if (nsURI){
   	xmlNewNs(docroot,(const xmlChar*)nsURI->getCString(),NULL);
  }

  xmlDocSetRootElement(doc,docroot);
  
  xmlNodePtr nodeMetadata = xmlNewNode(NULL,(const xmlChar*)TAG_METADATA);
  nodeMetadata->type = XML_ELEMENT_NODE;
  
  xmlAddChild(docroot,nodeMetadata);
  
  xmlNodePtr nodeNameFilePdf = xmlNewNode(NULL,(const xmlChar*)TAG_PDFFILENAME);
  nodeNameFilePdf->type = XML_ELEMENT_NODE;
  
  xmlAddChild(nodeMetadata,nodeNameFilePdf);
  xmlNodeSetContent(nodeNameFilePdf,(const xmlChar*)xmlEncodeEntitiesReentrant(nodeNameFilePdf->doc,(const xmlChar*)fileNamePDF->getCString()));
  
  xmlNodePtr nodeProcess = xmlNewNode(NULL,(const xmlChar*)TAG_PROCESS);
  nodeProcess->type = XML_ELEMENT_NODE;
  xmlAddChild(nodeMetadata,nodeProcess);
  xmlNewProp(nodeProcess,(const xmlChar*)ATTR_NAME,(const xmlChar*)PDFTOXML_NAME);
  xmlNewProp(nodeProcess,(const xmlChar*)ATTR_CMD,(const xmlChar*)cmdA->getCString());
      	  			
  xmlNodePtr nodeVersion = xmlNewNode(NULL,(const xmlChar*)TAG_VERSION);
  nodeVersion->type = XML_ELEMENT_NODE;
  xmlAddChild(nodeProcess,nodeVersion);
  xmlNewProp(nodeVersion,(const xmlChar*)ATTR_VALUE,(const xmlChar*)PDFTOXML_VERSION);	

  xmlNodePtr nodeComment = xmlNewNode(NULL,(const xmlChar*)TAG_COMMENT);
  nodeComment->type = XML_ELEMENT_NODE;
  xmlAddChild(nodeVersion,nodeComment);

  xmlNodePtr nodeDate = xmlNewNode(NULL,(const xmlChar*)TAG_CREATIONDATE);
  nodeDate->type = XML_ELEMENT_NODE;
  xmlAddChild(nodeProcess,nodeDate);
  time_t t;
  time(&t);
  xmlNodeSetContent(nodeDate,(const xmlChar*)xmlEncodeEntitiesReentrant(nodeDate->doc,(const xmlChar*)ctime(&t)));
  
  // The file of vectorials instructions
  vecdoc = xmlNewDoc((const xmlChar*)VERSION);
  vecdoc->encoding = xmlStrdup((const xmlChar*)ENCODING_UTF8);
  vecroot = xmlNewNode(NULL,(const xmlChar*)TAG_VECTORIALINSTRUCTIONS);
   
  xmlDocSetRootElement(vecdoc,vecroot);

  xmlNewProp(vecroot,(const xmlChar*)"file",(const xmlChar*)fileName->getCString());

  needClose = gFalse;
  
  delete fileNamePDF;

  text = new TextPage(verbose, docroot, imgDirName, baseFileName, nsURI);
 }

XmlOutputDev::~XmlOutputDev() {
  xmlSaveFile(myfilename->getCString(),doc);
  xmlFreeDoc(doc);
    
  if (text) {
    delete text;
  }
   if (nsURI){
   	delete nsURI;
  }
}

void XmlOutputDev::startPage(int pageNum, GfxState *state) {
	if (parameters->getCutAllPages() == 1){
		  text->startPage(pageNum, state, gFalse);
	}
	if (parameters->getCutAllPages() == 0){
		  text->startPage(pageNum, state, gTrue);
	}
}

void XmlOutputDev::endPage() {
	text->configuration();
	if (parameters->getDisplayText()) {
    	text->dump(blocks, fullFontName);
	}
  	text->endPage(dataDir);
}

void XmlOutputDev::updateFont(GfxState *state) {
	text->updateFont(state);
}

void XmlOutputDev::drawChar(GfxState *state, double x, double y,
			     double dx, double dy,
			     double originX, double originY,
			     CharCode c, int nBytes, Unicode *u, int uLen) {
  	if (uLen ==0){uLen=1;}
  	text->addChar(state, x, y, dx, dy, c, nBytes, u, uLen);
}
 
void XmlOutputDev::stroke(GfxState *state) {
	GString * attr = new GString();
  	char tmp[100];
  	GfxRGB rgb;

	// The stroke attribute : the stroke color value
  	state->getStrokeRGB(&rgb);
  	GString * hexColor = colortoString(rgb);
  	sprintf(tmp, "stroke: %s;", hexColor->getCString() );
  	attr->append(tmp);
  	delete hexColor;
  
  	// The stroke-opacity attribute
  	double fo = state->getStrokeOpacity();
  	if (fo != 1){
  		sprintf(tmp,  "stroke-opacity: %g;", fo);
  		attr->append( tmp);
  	}
  
  	// The stroke-dasharray attribute : line dasharray information
  	// We use the transformWidth function to adjust the values with the CTM value
  	double *dash;
  	int length;
  	int i;
  	double start;
  	state->getLineDash(&dash,&length,&start);     
  	// IF there is information about line dash
  	if (length != 0){
  		attr->append("stroke-dasharray:");
  		for (i=0;i<length;i++){
  	  		sprintf(tmp,"%g",state->transformWidth(dash[i]) == 0 ? 1 : state->transformWidth(dash[i]));
  	  		attr->append(tmp);
  	    	sprintf(tmp,"%s",(i == length-1) ? "" : ", ");
  	    	attr->append(tmp);
  		}
  		attr->append(";");
  	}

  	// The fill attribute : none value
  	attr->append("fill:none;");

 	// The stroke-width attribute
 	// Change the line width value with the CTM value
 	double lineWidth1 = state->getLineWidth();
  	state->setLineWidth(state->getTransformedLineWidth());
  	double lineWidth2 = state->getLineWidth();
  	if (lineWidth1 != lineWidth2){
  		lineWidth2 = lineWidth2 + 0.5;
  	}
  	sprintf(tmp, "stroke-width: %g;", lineWidth2);
  	attr->append(tmp);
	
  	// The stroke-linejoin attribute
  	int lineJoin = state->getLineJoin();
  	switch(lineJoin){
  		case 0: attr->append("stroke-linejoin:miter;");break;
  		case 1: attr->append("stroke-linejoin:round;");break;
  		case 2: attr->append("stroke-linejoin:bevel;");break;
  	}

  	// The stroke-linecap attribute
  	int lineCap = state->getLineCap();
  	switch(lineCap){
  		case 0: attr->append("stroke-linecap:butt;");break;
  		case 1: attr->append("stroke-linecap:round;");break;
  		case 2: attr->append("stroke-linecap:square;");break;
  	}

  	// The stroke-miterlimit attribute
 	double miter = state->getMiterLimit();
 	if (miter != 4) {sprintf(tmp, "stroke-miterlimit: %g;", miter);}
  	attr->append(tmp);  

  	doPath(state->getPath(),state,attr);
}

void XmlOutputDev::fill(GfxState *state) {
  	GString * attr = new GString();
  	char tmp[100];
  	GfxRGB rgb;
  
  	// The fill attribute which give color value
  	state->getFillRGB(&rgb);
  	GString * hexColor = colortoString(rgb);
  	sprintf(tmp, "fill: %s;", hexColor->getCString() );
  	attr->append(tmp);
  	delete hexColor;

	// The fill-opacity attribute
  	double fo = state->getFillOpacity();
  	sprintf(tmp,  "fill-opacity: %g;", fo);
  	attr->append( tmp);
 
  	doPath(state->getPath(),state,attr);
}

void XmlOutputDev::eoFill(GfxState *state) {
  	GString * attr = new GString();
  	char tmp[100];
  	GfxRGB rgb;

	// The fill attribute which give color value
  	state->getFillRGB(&rgb);
  	GString * hexColor = colortoString(rgb);
  	sprintf(tmp, "fill: %s;", hexColor->getCString() );
  	attr->append(tmp);
  	delete hexColor;
  
  	// The fill-rule attribute with evenodd value
  	attr->append( "fill-rule: evenodd;");

	// The fill-opacity attribute
  	double fo = state->getFillOpacity();
  	sprintf(tmp,  "fill-opacity: %g;", fo);
  	attr->append( tmp);

  	doPath(state->getPath(),state,attr);
}

void XmlOutputDev::clip(GfxState *state) {
	text->clip(state);
}

void XmlOutputDev::eoClip(GfxState *state) {
	text->eoClip(state);
}

void XmlOutputDev::doPath(GfxPath *path,GfxState *state,GString *gattributes) {
  if (parameters->getDisplayImage()){
    text->doPath(path,state,gattributes);
  }
}

void XmlOutputDev::saveState(GfxState *state) {
	text->saveState(state);
}

void XmlOutputDev::restoreState(GfxState *state) {
	text->restoreState(state);
}

// Return the hexadecimal value of the color of string
GString *XmlOutputDev::colortoString(GfxRGB rgb) const{
  	char* temp;	
  	temp = (char*)malloc(10*sizeof(char)); 
   	sprintf(temp,"#%02X%02X%02X",static_cast<int>(255*colToDbl(rgb.r)), static_cast<int>(255*colToDbl(rgb.g)), static_cast<int>(255*colToDbl(rgb.b)));
	GString *tmp = new GString(temp);

  	free(temp);
  	
  	return tmp;
} 

GString *XmlOutputDev::convtoX(unsigned int xcol) const{
  GString *xret=new GString();
  char tmp;
  unsigned  int k;
  k = (xcol/16);
  if ((k>=0)&&(k<10)) tmp=(char) ('0'+k); else tmp=(char)('a'+k-10);
  xret->append(tmp);
  k = (xcol%16);
  if ((k>=0)&&(k<10)) tmp=(char) ('0'+k); else tmp=(char)('a'+k-10);
  xret->append(tmp);
 return xret;
}

void XmlOutputDev::drawImage(GfxState *state, Object *ref, Stream *str,
			  int width, int height, GfxImageColorMap *colorMap,
			  int *maskColors, GBool inlineImg) {
  	if (parameters->getDisplayImage()){
  		imageIndex+=1;
  		text->drawImage(state, ref, str, width, height, colorMap, maskColors, inlineImg, dumpJPEG, imageIndex);
  	}
}

void XmlOutputDev::drawImageMask(GfxState *state, Object *ref, Stream *str,
			      int width, int height, GBool invert, GBool inlineImg) {			      	
	if (parameters->getDisplayImage()){
  		imageIndex +=1;
  		text->drawImageMask(state, ref, str, width, height, invert, inlineImg, dumpJPEG, imageIndex);
  	}
}

void XmlOutputDev::initOutline(int nbPage){
	char* tmp = (char*)malloc(10*sizeof(char));
	docOutline = xmlNewDoc((const xmlChar*)VERSION);
	globalParams->setTextEncoding((char*)ENCODING_UTF8);
	docOutline->encoding = xmlStrdup((const xmlChar*)ENCODING_UTF8);
	docOutlineRoot = xmlNewNode(NULL,(const xmlChar*)TAG_TOCITEMS);
	sprintf(tmp,"%d",nbPage);
 	xmlNewProp(docOutlineRoot,(const xmlChar*)ATTR_NB_PAGES,(const xmlChar*)tmp);
	xmlDocSetRootElement(docOutline,docOutlineRoot);
}

void XmlOutputDev::generateOutline(GList *itemsA, PDFDoc *docA, int levelA){	
	UnicodeMap *uMap;
  	GString *enc;
  	idItemToc = 0;	
  	if (itemsA && itemsA->getLength() > 0) {
      enc = new GString("Latin1");
      uMap = globalParams->getUnicodeMap(enc);
      delete enc;
      dumpOutline(itemsA, docA, uMap, levelA, idItemToc);
      uMap->decRefCnt();
    }
}

GBool XmlOutputDev::dumpOutline(GList *itemsA, PDFDoc *docA, UnicodeMap *uMapA, int levelA, int idItemTocParentA) {
	xmlNodePtr nodeTocItem = NULL;
    xmlNodePtr nodeItem = NULL;
    xmlNodePtr nodeString = NULL;
    xmlNodePtr nodeLink = NULL;
    
    GBool atLeastOne = gFalse;
    
    char* tmp = (char*)malloc(10*sizeof(char));
         
    int i, j, n;
  	GString *title;
  	char buf[8];
  	  
  	nodeTocItem = xmlNewNode(NULL,(const xmlChar*)TAG_TOCITEMLIST);
 	sprintf(tmp,"%d",levelA);
 	xmlNewProp(nodeTocItem,(const xmlChar*)ATTR_LEVEL,(const xmlChar*)tmp);

	if (levelA != 0 && idItemTocParentA != 0){
    	sprintf(tmp,"%d",idItemTocParentA);
		xmlNewProp(nodeTocItem,(const xmlChar*)ATTR_ID_ITEM_PARENT,(const xmlChar*)tmp);
    }
    xmlAddChild(docOutlineRoot,nodeTocItem);

   	for (i = 0; i < itemsA->getLength(); ++i) {
      	 	
    	title = new GString();

    	((OutlineItem *)itemsA->get(i))->open(); // open the kids 	
    	
    	for (j = 0; j < ((OutlineItem *)itemsA->get(i))->getTitleLength(); ++j) {
    		
      		n = uMapA->mapUnicode(((OutlineItem *)itemsA->get(i))->getTitle()[j], buf, sizeof(buf));
      		title->append(buf, n);   
    	}

    	LinkActionKind kind;

 		LinkDest *dest;
  		GString *namedDest;

  		GString *fileName;
   		int page = 0;
	
		double left = 0;
    	double top = 0;
    	double right = 0;
    	double bottom = 0;

    	if (((OutlineItem *)itemsA->get(i))->getAction()){
    		
    		switch (kind = ((OutlineItem *)itemsA->get(i))->getAction()->getKind()) {
    	
    		// GOTO action
			case actionGoTo: 		 		
  				dest = NULL;
      			namedDest = NULL;

      			if ((dest = ((LinkGoTo *)((OutlineItem *)itemsA->get(i))->getAction())->getDest())) {
					dest = dest->copy();
      			}else if ((namedDest = ((LinkGoTo *)((OutlineItem *)itemsA->get(i))->getAction())->getNamedDest())) {
					namedDest = namedDest->copy();
      			}
      			if (namedDest) {
      				dest = docA->findDest(namedDest);
    			}
    	
      			if (dest) {     		
	  				if (dest->isPageRef()) {
			  			Ref pageref = dest->getPageRef();
						page=docA->getCatalog()->findPage(pageref.num,pageref.gen);
	  				} 
					else {
			  			page = dest->getPageNum();
	  				}  	
				}
			
				left = dest->getLeft();
				top = dest->getTop();
				bottom = dest->getBottom();
				right = dest->getRight();
			  
      			if (dest) {
	  				delete dest;
				}
				if (namedDest) {
	  				delete namedDest;
				}
  				break;  	
  				
  			// GOTOR action
  			case actionGoToR:  		
  				dest = NULL;
      			namedDest = NULL;

      			if ((dest = ((LinkGoToR *)((OutlineItem *)itemsA->get(i))->getAction())->getDest())) {
					dest = dest->copy();
      			} else if ((namedDest = ((LinkGoToR *)((OutlineItem *)itemsA->get(i))->getAction())->getNamedDest())) {
					namedDest = namedDest->copy();
      			}
      	    	if (namedDest) {
      				dest = docA->findDest(namedDest);
    			}
      			if (dest) {     		
	  				if (dest->isPageRef()) {
			  			Ref pageref = dest->getPageRef();
						page=docA->getCatalog()->findPage(pageref.num,pageref.gen);
	  				}else {
			  			page = dest->getPageNum();
	  				}  	
				}
      			left = dest->getLeft();
				top = dest->getTop();
				bottom = dest->getBottom();
				right = dest->getRight();
			
      			if (dest) {
	  				delete dest;
				}
				if (namedDest) {
	  				delete namedDest;
				}
  				break; 
  			 		
  			// LAUNCH action
  			case actionLaunch:
  				fileName = ((LinkLaunch *)((OutlineItem *)itemsA->get(i))->getAction())->getFileName();
    			delete fileName;
  				break;
  			
  			// URI action
  			case actionURI:
 				break;
 			
    		// NAMED action
  			case actionNamed:
  				break;
  			
    		// MOVIE action
  			case actionMovie:
  				break;
  			
  			// UNKNOWN action
  			case actionUnknown:
  				break;
      		} // end SWITCH
    	} // end IF

      	// ITEM node
     	nodeItem = xmlNewNode(NULL,(const xmlChar*)TAG_ITEM);
      	nodeItem->type = XML_ELEMENT_NODE;
      	sprintf(tmp,"%d",idItemToc);
      	//xmlNewProp(nodeItem,(const xmlChar*)ATTR_ID,(const xmlChar*)tmp);
      	xmlAddChild(nodeTocItem,nodeItem);

	  	// STRING node      
      	nodeString = xmlNewNode(NULL,(const xmlChar*)TAG_STRING);
      	nodeString->type = XML_ELEMENT_NODE;
   	  	xmlNodeSetContent(nodeString,(const xmlChar*)xmlEncodeEntitiesReentrant(nodeString->doc,(const xmlChar*)title->getCString()));
      	xmlAddChild(nodeItem,nodeString);

	  	// LINK node
      	nodeLink = xmlNewNode(NULL,(const xmlChar*)TAG_LINK);
      	nodeLink->type = XML_ELEMENT_NODE;
      
      	sprintf(tmp,"%d",page);
      	xmlNewProp(nodeLink,(const xmlChar*)ATTR_PAGE,(const xmlChar*)tmp);
      	sprintf(tmp,"%.2f",top);
      	xmlNewProp(nodeLink,(const xmlChar*)ATTR_TOP,(const xmlChar*)tmp);
      	sprintf(tmp,"%.2f",bottom);
      	xmlNewProp(nodeLink,(const xmlChar*)ATTR_BOTTOM,(const xmlChar*)tmp);
      	sprintf(tmp,"%.2f",left);
      	xmlNewProp(nodeLink,(const xmlChar*)ATTR_LEFT,(const xmlChar*)tmp);
      	sprintf(tmp,"%.2f",right);
      	xmlNewProp(nodeLink,(const xmlChar*)ATTR_RIGHT,(const xmlChar*)tmp);
            
      	xmlAddChild(nodeItem,nodeLink);
	  	int idItemCurrent = idItemToc;
      	idItemToc++;         
      	if (((OutlineItem *)itemsA->get(i))->hasKids()){
    		dumpOutline(((OutlineItem *)itemsA->get(i))->getKids(), docA, uMapA, levelA+1, idItemCurrent);
      	}
            
      	delete title;
      	((OutlineItem *)itemsA->get(i))->close(); // close the kids 	
      	
      	atLeastOne = gTrue;
    } // end FOR
    
   return atLeastOne;
}

void XmlOutputDev::closeOutline(GString *shortFileName){
	shortFileName->append("_");
	shortFileName->append(NAME_OUTLINE);
	shortFileName->append(EXTENSION_XML);
	xmlSaveFile(shortFileName->getCString(),docOutline);
	xmlFreeDoc(docOutline);
}
