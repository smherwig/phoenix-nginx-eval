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

