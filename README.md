# phoenix-nginx-eval
Performance evaluations of NGINX webserver running on the Phoenix-SGX microkernel

# Overview
You first need to download NGINX and create a patched version of NGINX
for Phoenix/Graphene.  This is accomplished by running

```
bin/get_nginx.sh
```

Afterwords, you will have two directories: `nginx-1.14.1`, which is the
vanilla version of NGINX, and `nginx-1.14.1-graphene`, which is the
patched version.

You then need to create the different base builds.  By base build, we
mean a different set of options to `./configure`.

```
make graphene_bases
```

# The config directory


## `mounts/nginx/`
The directory `config/nginx` is simply a the default NGINX configuration with
the `sbin` directory removed.  That is, I did

```
cd nginx-1.14.1
./configure --prefix=$PWD/out
make
make install
cp -R out ../config/nginx
rm -rf ../config/nginx/sbin
```

I then added some files of specific sizes to `config/nginx/html`,
as well as a self-signed TLS key and certificate to `config/nginx/conf`.

TODO: move the modsec configuration to mounts/nginx (even if
a bench doesn't end up using those files).


## `mounts/etc/`
This is a minimal UNIX `etc` directory that has a few files that
applications typically expect to exist.
