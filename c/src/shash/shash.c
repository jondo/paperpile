/*
 * Implementations of M. Charikar's document similarity hash.
 *
 * Public domain
 * 2007 Viliam Holub <holub@dsrg.mff.cuni.cz>
 */

#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <getopt.h>
#include <stdbool.h>
#include <string.h>

#include "simi.h"
#include "simiw.h"

void dec2bin(unsigned long long decimal, char *binary);
char *get_line(FILE *fp); /* reads lines of arbitrary length from fp */
void *xrealloc (void *p, unsigned size);
void *space(unsigned size);


int
main( int argc, char **argv)
{
  /* Print help if there are no parameters */
  if (argc < 2)
    exit(5);
  
  /* Parse input line */
  int opt;

  while (opt = getopt( argc, argv, "dqs:"), opt != -1)
    switch (opt) {
    default:
      exit( 5);
      /* Unreachable */
    }
  
 
  
  
  /* Do the work */
  uint64_t hash1=0, hash2=0;

  FILE * myfile;
  myfile = fopen(argv[ optind],"r");
  
  char    *line;
  while((line=get_line(myfile))) {
    long data_length;
    data_length = strlen(line);
    
    hash1=0;
    hash2=0;
    
    hash2 = hash1;
    hash1 = charikar_hash64( line, data_length);
    
    //printf( "%016llx %s\n", (long long)hash1, line);
    char binary[80];
    dec2bin((unsigned long long)hash1,binary);
    printf("%s %s\n",binary,line);
  }
    
  return 0;
}

void dec2bin(unsigned long long decimal, char *binary)
{
  int  k = 0, n = 0;
  int  remain;
  char temp[80];

  do {
    remain    = decimal % 2;
    decimal   = decimal / 2;
    temp[k++] = remain + '0';
  } while (decimal > 0);

  // reverse the spelling
  for ( int j = k; j < 64; j++ ) binary[n++] = '0';    
  while (k >= 0) binary[n++] = temp[--k];

  binary[n-1] = 0;  
}

char *get_line(FILE *fp) /* reads lines of arbitrary length from fp */
{
  char s[512], *line, *cp;
  int len=0, size=0, l;
  line=NULL;
  do {
    if (fgets(s, 512, fp)==NULL) break;
    cp = strchr(s, '\n');
    if (cp != NULL) *cp = '\0';
    l = len + strlen(s);
    if (l+1>size) {
      size = (l+1)*1.2;
      line = (char *) xrealloc(line, size*sizeof(char));
    }
    strcat(line+len, s);
    len=l;
  } while(cp==NULL);

  return line;
}

void *xrealloc (void *p, unsigned size) {
  if (p == 0)
    return space(size);
  p = (void *) realloc(p, size);
  return p;
}

void *space(unsigned size) {
  void *pointer;

  if ( (pointer = (void *) calloc(1, (size_t) size)) == NULL) {

  }
  return  pointer;
}
