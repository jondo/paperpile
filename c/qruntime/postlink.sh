#!/bin/bash
cd ..
rm paperpile.app/Contents/Resources/catalyst
ln -s `pwd`/../../catalyst paperpile.app/Contents/Resources/catalyst
cd src
