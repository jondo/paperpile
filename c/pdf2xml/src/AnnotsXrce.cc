//====================================================================
//
// AnnotsXrce.cc
//
// author: Sophie Andrieu
//
// 09-2006
//
// Xerox Research Centre Europe
//
//====================================================================

#include "AnnotsXrce.h"
#include <stdlib.h>
#include "Object.h"

#include "ConstantsXML.h"
using namespace ConstantsXML;

#include <libxml/xmlmemory.h>
#include <libxml/parser.h>

AnnotsXrce::AnnotsXrce(Object &objA, xmlNodePtr docrootA, double *ctmA, int pageNumA){
	
	idAnnot = 1;
	double x, y;
	
	xmlNodePtr nodeAnnot = NULL;
  	xmlNodePtr nodePopup = NULL;
  	xmlNodePtr nodeContent = NULL;
  	
  	Object objSubtype;
  	Object objContents;
  	Object objPopup;
  	Object objT;
  	Object objQuadPoints;
  	Object objAP;
  	Object objRect;
  	Object rectPoint;
  	Object objAct;
  	GBool current = gFalse;
  	GBool isLink = gFalse;
  
	Object kid;
  	for (int i = 0 ; i < objA.arrayGetLength() ; ++i){
  		objA.arrayGet(i, &kid);
  		if (kid.isDict()) {
  			Dict *dict;
  			dict = kid.getDict();	
			char* tmpor=(char*)malloc(10*sizeof(char));
			
			// Get the annotation's type
  			if (dict->lookup("Subtype", &objSubtype)->isName()){
  				// It can be 'Highlight' or 'Underline' or 'Link' (Subtype 'Squiggly' or 'StrikeOut' are not supported)
  				if (!strcmp(objSubtype.getName(), "Highlight") || !strcmp(objSubtype.getName(), "Underline") || !strcmp(objSubtype.getName(), "Link")){
  					nodeAnnot = xmlNewNode(NULL,(const xmlChar*)TAG_ANNOTATION);
  					nodeAnnot->type = XML_ELEMENT_NODE;
  					xmlNewProp(nodeAnnot,(const xmlChar*)ATTR_SUBTYPE,(const xmlChar*)objSubtype.getName());
  					xmlAddChild(docrootA,nodeAnnot);  				
  					current = gTrue;	
  					sprintf(tmpor,"%d",pageNumA);
  					xmlNewProp(nodeAnnot,(const xmlChar*)ATTR_PAGENUM,(const xmlChar*)tmpor);
  					free(tmpor);
  					isLink = gFalse;
  				}  			
  				if (!strcmp(objSubtype.getName(), "Link")){
  					isLink = gTrue;
  				}	
  			}
  			objSubtype.free();
  			
  			// Get informations about Link annotation
  			if (isLink){
  				
  				// Get the Action information
  				if (dict->lookup("A", &objAct)->isDict()){
  					xmlNodePtr nodeActionAction;
  					xmlNodePtr nodeActionDEST;
  					if (nodeAnnot){
  	  					nodeActionAction = xmlNewNode(NULL,(const xmlChar*)"ACTION");
  						nodeActionAction->type = XML_ELEMENT_NODE;
  						
  						xmlAddChild(nodeAnnot, nodeActionAction);
					}
						
  					Dict *dictAction;
					Object objURI;
					Object objGoTo;
					dictAction = objAct.getDict();
					Object objS;
					Object objF;
					
					// Get the type of link
					if (dictAction->lookup("S", &objS)->isName()){
						if (!strcmp(objS.getName(), "URI")){
							xmlNewProp(nodeActionAction,(const xmlChar*)"type",(const xmlChar*)"URI");
							if (dictAction->lookup("URI", &objURI)->isString()){																			
								if (nodeAnnot){
  	  								nodeActionDEST = xmlNewNode(NULL,(const xmlChar*)"DEST");
  									nodeActionDEST->type = XML_ELEMENT_NODE;
  									xmlNodeSetContent(nodeActionDEST,(const xmlChar*)xmlEncodeEntitiesReentrant(nodeActionDEST->doc,(const xmlChar*)objURI.getString()->getCString()));
  									xmlAddChild(nodeActionAction, nodeActionDEST);
								}
								objURI.free();
							}
						}
						if (!strcmp(objS.getName(), "GoTo") || !strcmp(objS.getName(), "GoToR")){
							xmlNewProp(nodeActionAction,(const xmlChar*)"type",(const xmlChar*)objS.getName());
							// Get the destination to jump to
							if (dictAction->lookup("D", &objGoTo)->isString()){															
								if (nodeAnnot){
  	  								nodeActionDEST = xmlNewNode(NULL,(const xmlChar*)"DEST");
  									nodeActionDEST->type = XML_ELEMENT_NODE;
  									xmlNodeSetContent(nodeActionDEST,(const xmlChar*)xmlEncodeEntitiesReentrant(nodeActionDEST->doc,(const xmlChar*)objGoTo.getString()->getCString()));
  									xmlAddChild(nodeActionAction, nodeActionDEST);
								}
							}
							objGoTo.free();
							// Get the file in which the destination is located
							if (dictAction->lookup("F", &objF)->isString()){							
								if (nodeActionDEST){
									xmlNewProp(nodeActionDEST,(const xmlChar*)"filedest",(const xmlChar*)objF.getString()->getCString());							
								}
							}
							objF.free();						
						}
					}
					objS.free();
  				}
  				objAct.free();
				
				// Get the rectangle location link annotation
  				if (dict->lookup("Rect", &objRect)->isArray()){
  					double xMin = 0.;
  					double xMax = 0.;
  					double yMin = 0.;
  					double yMax = 0.;
  					
  					for (int i = 0 ; i < objRect.arrayGetLength() ; ++i){
  						objRect.arrayGet(i, &rectPoint);
  						if (i==0){
  							if (rectPoint.isInt()) xMin = static_cast<double>(rectPoint.getInt()); 								 
  							if (rectPoint.isReal()) xMin = rectPoint.getReal();
  						}
  						if (i==1){
  							if (rectPoint.isInt()) yMin = static_cast<double>(rectPoint.getInt());
  							if (rectPoint.isReal()) yMin = rectPoint.getReal();
  						}
  						if (i==2){
  							if (rectPoint.isInt()) xMax = static_cast<double>(rectPoint.getInt());
  							if (rectPoint.isReal()) xMax = rectPoint.getReal();
  						}
  						if (i==3){
  							if (rectPoint.isInt()) yMax = static_cast<double>(rectPoint.getInt());
  							if (rectPoint.isReal()) yMax = rectPoint.getReal();
  							
  							double xMinT,xMaxT,yMinT,yMaxT;
  							xMinT = xMaxT = yMinT = yMaxT = 0.;
  							transform(xMin, yMin, &xMinT, &yMinT, ctmA);
  							transform(xMax, yMax, &xMaxT, &yMaxT, ctmA);
  							
  							xmlNodePtr nodeQuadR;
  							xmlNodePtr nodeQuadrilR;
  							xmlNodePtr nodePointsR1;

  							if (nodeAnnot){
  	  							nodeQuadR = xmlNewNode(NULL,(const xmlChar*)TAG_QUADPOINTS);
  								nodeQuadR->type = XML_ELEMENT_NODE;
  								xmlAddChild(nodeAnnot, nodeQuadR);
  								nodeQuadrilR = xmlNewNode(NULL,(const xmlChar*)TAG_QUADRILATERAL);
  								nodeQuadrilR->type = XML_ELEMENT_NODE;
  								xmlAddChild(nodeQuadR, nodeQuadrilR);
  								
  								char* t = (char*)malloc(10*sizeof(char));
  		
  								nodePointsR1 = xmlNewNode(NULL,(const xmlChar*)TAG_POINT);
  								nodePointsR1->type = XML_ELEMENT_NODE;
  								xmlAddChild(nodeQuadrilR, nodePointsR1);							
  								sprintf(t,"%lg",xMinT);
  								xmlNewProp(nodePointsR1,(const xmlChar*)ATTR_X,(const xmlChar*)t);		
  								sprintf(t,"%lg",yMinT);
  								xmlNewProp(nodePointsR1,(const xmlChar*)ATTR_Y,(const xmlChar*)t);
  								
  								nodePointsR1 = xmlNewNode(NULL,(const xmlChar*)TAG_POINT);
  								nodePointsR1->type = XML_ELEMENT_NODE;
  								xmlAddChild(nodeQuadrilR, nodePointsR1);							
  								sprintf(t,"%lg",xMinT);
  								xmlNewProp(nodePointsR1,(const xmlChar*)ATTR_X,(const xmlChar*)t);		
  								sprintf(t,"%lg",yMaxT);
  								xmlNewProp(nodePointsR1,(const xmlChar*)ATTR_Y,(const xmlChar*)t);
  								
  								nodePointsR1 = xmlNewNode(NULL,(const xmlChar*)TAG_POINT);
  								nodePointsR1->type = XML_ELEMENT_NODE;
  								xmlAddChild(nodeQuadrilR, nodePointsR1);							
  								sprintf(t,"%lg",xMaxT);
  								xmlNewProp(nodePointsR1,(const xmlChar*)ATTR_X,(const xmlChar*)t);		
  								sprintf(t,"%lg",yMinT);
  								xmlNewProp(nodePointsR1,(const xmlChar*)ATTR_Y,(const xmlChar*)t);
  								
  								nodePointsR1 = xmlNewNode(NULL,(const xmlChar*)TAG_POINT);
  								nodePointsR1->type = XML_ELEMENT_NODE;
  								xmlAddChild(nodeQuadrilR, nodePointsR1);							
  								sprintf(t,"%lg",xMaxT);
  								xmlNewProp(nodePointsR1,(const xmlChar*)ATTR_X,(const xmlChar*)t);		
  								sprintf(t,"%lg",yMaxT);
  								xmlNewProp(nodePointsR1,(const xmlChar*)ATTR_Y,(const xmlChar*)t);
	
  								free(t); 
  							}	
  						}			
  						rectPoint.free();	
  					}
  				}
  				objRect.free();
  			}
  	
  			// Add the id attribut into the annotation tag : format is 'p<pageNumber>_a<annotationNumber>
  			if (nodeAnnot && current){
  				char* tmp=(char*)malloc(10*sizeof(char));
  				GString *idValue;
  				idValue = new GString("p");
  				sprintf(tmp,"%d",pageNumA);
  				idValue->append(tmp);
  				idValue->append("_a");
  				sprintf(tmp,"%d",idAnnot);
  				idValue->append(tmp);
  				xmlNewProp(nodeAnnot,(const xmlChar*)"id",(const xmlChar*)idValue->getCString());
  				free(tmp);
  				delete idValue;
  				idAnnot++;
  				current = gFalse;
  			}
  			
  			// Get the annotation's author
  			if (dict->lookup("T", &objT)->isString()){
  				if (nodeAnnot){
  					xmlNewProp(nodeAnnot,(const xmlChar*)ATTR_AUTHOR,(const xmlChar*)objT.getString()->getCString());
  				}	
  			}
  			objT.free();
  	
  			// Get the popup object if it exists
    		if (dict->lookup("Popup", &objPopup)->isDict()){ 	
  				if (nodeAnnot){
  	  				nodePopup = xmlNewNode(NULL,(const xmlChar*)TAG_POPUP);
  					nodePopup->type = XML_ELEMENT_NODE;
  					xmlAddChild(nodeAnnot, nodePopup);
  				}
  		
				Dict *dictPopup;
				Object open;
				dictPopup = objPopup.getDict();

				if (dictPopup->lookup("Open", &open)->isBool()){
					if (nodePopup){	
						if (open.getBool()){
							xmlNewProp(nodePopup,(const xmlChar*)ATTR_OPEN,(const xmlChar*)"true");
						}else{
							xmlNewProp(nodePopup,(const xmlChar*)ATTR_OPEN,(const xmlChar*)"false");
						}
					}
				}
				open.free();
  			}
  			objPopup.free();
  
  			// Get the popup's contents 
  			if (dict->lookup("Contents", &objContents)->isString()){
  				if (nodeAnnot){
  					if (nodePopup){
  						nodeContent = xmlNewNode(NULL,(const xmlChar*)TAG_CONTENT);
  						nodeContent->type = XML_ELEMENT_NODE;
  						xmlNodeSetContent(nodeContent,(const xmlChar*)xmlEncodeEntitiesReentrant(nodeContent->doc,(const xmlChar*)objContents.getString()->getCString()));
  						xmlAddChild(nodePopup, nodeContent);
  					} 		
  				}			
  			}
  			objContents.free();
  
  			// Get the localization (points series) of the annotation into the page
   			if (dict->lookup("QuadPoints", &objQuadPoints)->isArray()){
  				xmlNodePtr nodeQuad;
  				xmlNodePtr nodeQuadril;
  				xmlNodePtr nodePoints;
  				
  				if (nodeAnnot){
  	  				nodeQuad = xmlNewNode(NULL,(const xmlChar*)TAG_QUADPOINTS);
  					nodeQuad->type = XML_ELEMENT_NODE;
  					xmlAddChild(nodeAnnot, nodeQuad);
  				}			
  				Object point;
  				char* temp=(char*)malloc(10*sizeof(char));
   				double xx = 0;
   				double yy = 0;
   				
  				for (int i = 0 ; i < objQuadPoints.arrayGetLength() ; ++i){
  					objQuadPoints.arrayGet(i, &point);
  					
  					if (i%8==0){
  						nodeQuadril = xmlNewNode(NULL,(const xmlChar*)TAG_QUADRILATERAL);
  						nodeQuadril->type = XML_ELEMENT_NODE;
  						xmlAddChild(nodeQuad, nodeQuadril);
  					}
					if (i%2==0){
  						nodePoints = xmlNewNode(NULL,(const xmlChar*)TAG_POINT);
  						nodePoints->type = XML_ELEMENT_NODE;
  						xmlAddChild(nodeQuadril, nodePoints);
  			
  						if (point.isReal()) {
  							xx = point.getReal();
  						}
  					}else{
  						if (point.isReal()) {
  							yy = point.getReal();
  							if (xx!=0){
  								transform(xx, yy, &x, &y, ctmA);
  							}
  							sprintf(temp,"%lg",x);
  							xmlNewProp(nodePoints,(const xmlChar*)ATTR_X,(const xmlChar*)temp);		
  							sprintf(temp,"%lg",y);
  							xmlNewProp(nodePoints,(const xmlChar*)ATTR_Y,(const xmlChar*)temp);	
  							xx=0;		
  						}
  					} 	
  					point.free();			 			  
  				}
  				free(temp); 	
  			}
  			objQuadPoints.free();
  	
			if (dict->lookup("AP", &objAP)->isDict()){
  				Dict *dictStream;
  				dictStream = objAP.getDict();
  				Object objN;
  
   				// Annotation with normal appearance
   				if (dictStream->lookupNF("N",&objN)->isRef()){		
  					objN.free();
  				}
  			}
  			objAP.free();
  		}
  		kid.free();
  	} // end FOR
}

AnnotsXrce::~AnnotsXrce(){
}

void AnnotsXrce::transform(double x1, double y1, double *x2, double *y2, double *c){
	*x2 = c[0] * x1 + c[2] * y1 + c[4];
    *y2 = c[1] * x1 + c[3] * y1 + c[5]; 
}
