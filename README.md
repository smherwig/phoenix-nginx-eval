Overview
=========

Performance evaluations of NGINX webserver running on the
[Phoenix](https://github.com/smherwig/phoenix) SGX microkernel.


Setup
=====

```
cd ~
git clone https://github.com/smherwig/phoenix-nginx-eval nginx-eval
```


Build NGINX and Modsecurity
---------------------------

Download NGINX and create a patched version of NGINX for Phoenix/Graphene:

```
cd nginx-eval
bin/get_nginx.sh
```

Afterwords, there are two new directories: `nginx-1.14.1`, which is the
vanilla version of NGINX, and `nginx-1.14.1-graphene`, which is the
patched version.  The pathced version side-steps a few bugs in Graphene-SGX and
also foces the use of Phoenix's shared memory implementations.  See
`patch/README` for further details about the patches. 


Download, build, and install `libmodsecurity.so`.  This library may already be
installed to `/usr/local/modsecurity`.  We specifically build the library
without curl support, as Graphene appears to have a bug when handling libcurl's
(or one of libcurl's dependencie's) init function (that is, the library
constructor):

```
bin/get_modsecurity.sh
```

Download the NGINX modsecurity connector plugin:

```
bin/get_modsecurity_connector.sh
```

Next, build a few different versions of NGINX; the options to `./configure`
are different among each version, and some versions build the ModSecurity
connector.

```
make bases-all
```

The different NGINX builds are located under `builds/`.  For instance,
`builds/graphene-cache-nomodsec-release` is a build of the Graphene-patched
version of NGINX, configured as a caching server, without ModSecurity, and in
release mode.


NGINX TLS keys
--------------

For development purposes, self-signed certificate and private key are located
at `config/mounts/nginx/conf/server.crt` and
`config/mounts/nginx/conf/server.key`, respectively.  If desired, inoke
`bin/make_nginx_self_signed_cert.sh` to generate a new
certificate and key and copy into `config/mounts/nginx/conf`.


ApacheBench
-----------

We use the ApacheBench to benchmark the NGINX's request latency and throughput.
macOS should have ApacheBench installed by default (`/usr/sbin/ab`).  On
Ubuntu, ApacheBench is installed with:

```
sudo apt-get install apache2-utils
```

and is located at `/usr/bin/ab`.


For benchmarks, we typically run ApacheBench with the command-line:

```
ab -n 10000 -c 128 <URL>
```

which issues 10,000 requests from 128 concurrent clients.  `URL` is the url
served by NGINX, such as `https://192.168.99.10:8443/1k.txt`.



Connecting two computers directly with an ethernet cable
---------------------------------------------------------

It may be desireable to run ApacheBench on one computer and NGINX on another,
and connect the two computers by Ethernet or via an Ethernet switch.

On the NGINX Ubuntu machine, edit `/etc/network/interfaces` to add
from the `# local hostmachine access interface` comment on down:

```
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback
# local hostmachine access interface
auto eno1
iface eno1 inet static
address 192.168.99.10
netmask 255.255.255.0
```

If ApacheBench is run from another Ubuntu device, edit that system's
`/etc/network/interfaces`, but with an IP address of `192.168.99.20`.

If running ApacheBench on macOS, hookup the Ethernet cable and go to
`System Preferences > Network > Ethernet` and configure as follows:


```
Configure IPv4: Manually
    IP Address: 192.168.99.20
   Subnet Mask: 255.255.255.0
        Router: 192.168.99.1
    DNS Server: <blank>
Search Domains: <blank>
```

I also had to turn WiFi off on my Mac. (It might be the case that Ethernet and
WiFi can co-exist on the Mac, but that that Ethernet needs to be
ordered higher than the Wifi.)


Origin Server
-------------

Package and run an origin webserver.  By "package", we mean copying a build and
overlaying specific configuration form `config/`.  The Makefile targerts handle
packaging:

```
make origin/linux-standalone-nomodsec-release_origin
cd pkg/origin/linux-standalone-nomodsec-release_origin/nginx
./sbin/nginx -p $PWD
```

By default, the origin server runs on `localhost:8081.  For a different bind
address and port, edit
`pkg/origin/linux-standalone-nomodsec-release_origin/nginx/conf/nginx.conf`, or
edit `config/origin/linux-standalone-nomodsec-release_origin/nginx.conf` and
re-package.


<a name="single-tenant"/> Single-Tenant
=======================================

Linux
-----

Package NGINX:

```
cd ~/nginx-eval
make single-tenant/linux-cache-nomodsec-release_nonsm
```

Run NGINX:

```
cd ~/nginx-eval/pkg/single-tenant/linux-cache-nomodsec-release_nonsm/nginx
./sbin/nginx -p $PWD
```


Linux-keyless
-------------

Package keyserver:

```
cd ~/nginx-eval
cp config/mounts/nginx/conf/server.key ~/src/keyserver/server/
cd ~/src/makemanifest
./make_sgx.py -g ~/src/phoenix -k ~/share/phoenix/enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver
```

Run keyserver:

```
cd ~/src/makemanifest/nsmserver
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Package NGINX:

```
cd ~/nginx-eval
make single-tenant/linux-cache-nomodsec-release_nsm
```

Run NGINX:

```
cd ~/nginx-eval/pkg/single-tenant/linux-cache-nomodsec-release_nsm/nginx
./sbin/nginx -p $PWD
```

Graphene-crypt
--------------

Create bd-crypt filesystem image:

```
cd ~/src/fileserver/makefs
mkdir root
./makefs.py -v -s 128M -p encpassword fs.crypt.img root 
cp fs.crypt.xts.img ~/src/fileserver/deploy/fs/srv/
```


Package fileserver:

```
# copy over the key material
cp ~/share/phoenix/root.crt ~/src/fileserver/deploy/fs/srv/
cp ~/share/phoenix/proc.crt ~/src/fileserver/deploy/fs/srv/
cp ~/share/phoenix/proc.key ~/src/fileserver/deploy/fs/srv/

cd ~/src/makemanifest
./make_sgx.py -g ~/src/phoenix -k ~/share/phoenix/enclave-key.pem \
        -p ~/src/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 
```

Run fileserver:

```
cd ~/src/makemanifest/nextfsserver
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdcrypt:encpassword:aes-256-xts /etc/clash /srv/fs.crypt.xts.img
```

Package keyserver:

```
cd ~/nginx-eval
cp config/mounts/nginx/conf/server.key ~/src/keyserver/server/
cd ~/src/makemanifest
./make_sgx.py -g ~/src/phoenix -k ~/share/phoenix/enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver
```

Run keyserver:

```
cd ~/src/makemanifest/nsmserver
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```


Package NGINX:

```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm
```

Run NGINX:

```
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm
./nginx.manifest.sgx -p /nginx
```


Graphene-crypt-exitless
-----------------------



Graphene-vericrypt
-------------------


Create bd-vericrypt filesystem image:

```
# copy over the key material
cp config/root.crt ~/src/fileserver/deploy/fs/srv/
cp config/proc.crt ~/src/fileserver/deploy/fs/srv/
cp config/proc.key ~/src/fileserver/deploy/fs/srv/

cd ~/src/fileserver/makefs
mkdir root
./makefs.py -v -s 128M fs.crypt.img root
cp fs.crypt.img ~/phoenix/fileserver/deploy/fs/srv/

# make the merkle tree file
./makemerkle.py -v -k macpassword fs.crypt.img fs.crypt.mt
cp fs.crypt.mt ~/src/fileserver/deploy/fs/srv
# root hash: 1845a98c4d4022fb080f8e2f33c60a297856bede1cf93c848c2029957b8e47d2
```


Package the fileserver:

```
# package
cd ~/src/makemanifest
./make_sgx.py -g ~/src/phoenix -k ~/share/phoenix/enclave-key.pem \
        -p ~/src/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 
```

Run fileserver

```
cd ~/src/makemanifest/nextfsserver
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdvericrypt:/srv/fs.std.mt:macpassword:1845a98c4d4022fb080f8e2f33c60a297856bede1cf93c848c2029957b8e47d2:encpassword:aes-256-xts \
        /etc/clash /srv/fs.std.img
```


Package the smuf (sm-vericrypt) memory server:

```
# copy key material
cp config/root.crt ~/src/memserver/smuf/
cp config/proc.crt ~/src/memserver/smuf/
cp config/proc.key ~/src/memserver/smuf/

# package
cd ~/src/makemanifest
./make_sgx.py -g ~/src/phoenix -k ~/share/phoenix/enclave-key.pem \
        -p ~/src/memserver/deploy/smufserver.conf \
        -t $PWD -v -o smufserver
```

Run memory server:

```
# TODO: reset memdir
cd ~/src/makemanfiest/smufserver
./smufserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key -r /memfiles0 /etc/ramones
```

Package keyserver:

```
cd ~/nginx-eval
cp config/mounts/nginx/conf/server.key ~/src/keyserver/server/
cd ~/src/makemanifest
./make_sgx.py -g ~/src/phoenix -k ~/share/phoenix/enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver
```

Run keyserver:

```
cd ~/src/makemanifest/nsmserver
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Package NGINX:

```
cd ~/nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nsm
```

Run NGINX:

```
cd ~/nginx-eval/pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nsm/nginx
./nginx.manifest.sgx -p /nginx
```


Multi-tenant
============

For simplicity, we have all replicas use the same origin server, and use the
same webserver certificate and key.



Linux (shared NGINX)
--------------------

```
cd ~/nginx-eval
make multi-tenant/share-nginx/linux-cache-nomodsec-release_nonsm
```


Graphene-crypt (shared NGINX)
-----------------------------

```
cd ~/nginx-eval
make multi-tenant/share-nginx/graphene-cache-nomodsec-debug_nextfs-smc-nsm
```


Graphene-crypt (shared nothing)
-------------------------------

```
cd ~/nginx-eval
make multi-tenant/share-nothing/graphene-cache-nomodsec-release_nextfs-smc-nsm
```


Web Application Firewall
========================


Linux
-----

```
cd ~/nginx-eval
make standalone/linux-standalone-modsec-release_nonsm:
```


Graphene-crypt
--------------

```
cd ~/nginx-eval
make standalone/graphene-standalone-modsec-release_nextfs-smc-nsm:
```
