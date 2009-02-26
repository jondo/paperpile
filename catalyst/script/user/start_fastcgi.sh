killall lighttpd
../../bin/lighttpd -m ../../bin -f ../../lighttpd.conf
../paperpile_fastcgi.pl -l localhost:55900 -e
