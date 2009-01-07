# We currently use a simple makefile and have installed podofo in
# /usr/local tree. We have also currently built everything with shared
# library dependencies. Don't forget to run /sbin/ldconfig after
# installing the library

CC=g++
CFLAGS=-c -Wall
LINKFLAGS=-lpodofo -lfreetype -lfontconfig -ljpeg -lz

all: annotate

annotate: annotate.o
	$(CC) $(LINKFLAGS) annotate.o -o annotate

annotate.o: annotate.cpp
	$(CC) $(CFLAGS) annotate.cpp

clean:
	rm -rf *o annotate
