killall lighttpd
../../lighttpd/sbin/lighttpd -m ../../lighttpd/lib -f ../../lighttpd/lighttpd.conf
../paperpile_fastcgi.pl -l localhost:55900 -e