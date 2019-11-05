#!/bin/bash

#
# Download and build ModSecurity 3.0.
#
# Building with curl brings in a lot of shared library dependencies.  It seems
# that Graphene has a bug when running the init (i.e., the constructor) for one
# of these libraries; however, I have not been able to isolate the bug just
# yet.
#
# ModSecurity is installed to /usr/local/modsecurity.
#
git clone --depth 1 -b v3/master --single-branch \
    https://github.com/SpiderLabs/ModSecurity


cd ModSecurity
git submodule init
git submodule update
./build.sh
./configure --without-curl
make
sudo make install
