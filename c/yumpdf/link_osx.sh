cd src
g++  -g -O2   -o yumpdf yumpdf.o viewer.o annotation.o /usr/local/lib/libpoppler.a /usr/local/lib/libpodofo.a /usr/local/lib/libfontconfig.a /usr/local/lib/libfreetype.a /usr/local/lib/libmxml.a -lexpat -lz -liconv /usr/local/lib/libcairo.a /usr/local/lib/libjpeg.a /usr/local/lib/libpng.a /usr/local/lib/libpixman-1.a
cd ..
