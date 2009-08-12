unset PERL5LIB
if [ ! -d "$HOME/.paperpile" ]; then
    mkdir $HOME/.paperpile
fi

$1./catalyst/perl5/linux32/bin/perl \
$1./catalyst/script/paperpile_server.pl -fork -pidfile $HOME/.paperpile/server.pid -background 2> /dev/null
