#!/bin/bash
cd ..
rm qruntime.app/Contents/Resources/catalyst
ln -s `pwd`/../../catalyst qruntime.app/Contents/Resources/catalyst
cd src
