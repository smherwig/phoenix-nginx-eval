#!/bin/bash

set -e


##############################################
# GLOBALS
##############################################

TOP=$PWD
NGINX=nginx-1.14.1
NGINX_GRAPHENE=nginx-1.14.1-graphene
NGINX_TARBALL=${NGINX}.tar.gz
NGINX_URL=http://nginx.org/download/$NGINX_TARBALL
MODSEC_REPO=https://github.com/SpiderLabs/ModSecurity
CONNECTOR_REPO=https://github.com/SpiderLabs/ModSecurity-nginx.git


##############################################
# FUNCTIONS
##############################################

apply_graphene_patches () {
    printf "[+] applying patches to NGINX_GRAPHENE\n"
    cd $NGINX_GRAPHENE
    patch -p1 --dry-run < ../patch/nginx-1.14.1-no-msg_peek-tls-only.patch
    patch -p1 --verbose < ../patch/nginx-1.14.1-no-msg_peek-tls-only.patch

    patch -p1 --dry-run < ../patch/nginx-1.14.1-no-atomics.patch
    patch -p1 --verbose < ../patch/nginx-1.14.1-no-atomics.patch

    patch -p1 --dry-run < ../patch/nginx-1.14.1-memserver.patch
    patch -p1 --verbose < ../patch/nginx-1.14.1-memserver.patch

    patch -p1 --dry-run < ../patch/nginx-1.14.1-memserver-http-cache.patch
    patch -p1 --verbose < ../patch/nginx-1.14.1-memserver-http-cache.patch

    patch -p1 --dry-run < ../patch/nginx-1.14.1-memserver-ssl-session-cache.patch
    patch -p1 --verbose < ../patch/nginx-1.14.1-memserver-ssl-session-cache.patch
    cd ..
}

##############################################
# MAIN
##############################################

# Download and unpack nginx:
#---------------------------------------------
if [ ! -d $NGINX ]; then
    printf "[+] downloading $NGINX_URL\n"
    wget $NGINX_URL
    tar zxvf $NGINX_TARBALL
fi


# copy original nginx and apply graphene patch
#---------------------------------------------
if [ ! -d $NGINX_GRAPHENE ]; then
    printf "[+] copying $NGINX to $NGINX_GRAPHENE\n"
    cp -R $NGINX $NGINX_GRAPHENE
    apply_graphene_patches
fi


## Download and build ModSecurity 3.0
#---------------------------------------------
#git clone --depth 1 -b v3/master --single-branch $MODSEC_REPO
#cd ModSecurity
#git submodule init
#git submodule update
#./build.sh
#./configure --without-curl
#make
#sudo make install
#cd $TOP
#
## Download the ModSecurity-Nginx connector:
#git clone --depth 1 $CONNECTOR_REPO 
