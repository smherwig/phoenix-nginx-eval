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
patched version.  The patched version side-steps a few bugs in Graphene-SGX and
also forces the use of Phoenix's shared memory implementations.  An important
result of the patch is that NGINX only accepts HTTPS requests.
See `patch/README` for further details.


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


<a name="nginx-tls-keys"/> NGINX TLS keys
-----------------------------------------

For development purposes, self-signed certificate and private key are located
at `config/mounts/nginx/conf/server.crt` and
`config/mounts/nginx/conf/server.key`, respectively.  If desired, inoke
`bin/make_nginx_self_signed_cert.sh` to generate a new
certificate and key and copy into `config/mounts/nginx/conf`.


<a name="apache-bench"/> ApacheBench
------------------------------------

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


`curl` is also a useful a tool for ensuring that the server is up and
functional:

```
curl --insecure <URL>
```


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

To kill the origin, enter:

```
cat logs/nignx.pid | xargs kill -TERM
```


<a name="single-tenant"/> Single-Tenant
=======================================

The single-tenant benchmarks evaluate a single caching instance of NGINX,
hosting a single site.  By default, each edge server listens on `*:8443`.

Linux
-----

Benchmark NGINX running on vanilla Linux.


Package NGINX edge server:

```
make single-tenant/linux-cache-nomodsec-release_nonsm
```

Run NGINX edge server:

```
cd pkg/single-tenant/linux-cache-nomodsec-release_nonsm/nginx
./sbin/nginx -p $PWD
```


<a name="single-tenant-linux-keyless"/> Linux-keyless
------------------------------------------------------

Benchmark NGINX running on vanilla Linux using an enclaved keyserver.

Package keyserver:

```
cd ~/nginx-eval
cp config/mounts/nginx/conf/server.key ~/src/keyserver/server/
cd ~/src/makemanifest
./make_sgx.py -g ~/src/phoenix -k ~/share/phoenix/enclave-key.pem \
        -p ~/src/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver
```

Run keyserver:

```
cd ~/src/makemanifest/nsmserver
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Package NGINX edge server:

```
cd ~/nginx-eval
make single-tenant/linux-cache-nomodsec-release_nsm
```

Run NGINX edge server:

```
cd pkg/single-tenant/linux-cache-nomodsec-release_nsm/nginx
./sbin/nginx -p $PWD
```

<a name="single-tenant-graphene-crypt"/> Graphene-crypt
-------------------------------------------------------

Create bd-crypt filesystem image:

```
cd ~/src/fileserver/makefs
mkdir root
# root directory cannot be empty
echo hello > root/hello.txt
./makefs.py -v -s 128M -p encpassword fs.crypt.img root 
cp fs.crypt.img ~/src/fileserver/deploy/fs/srv/
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
        -b bdcrypt:encpassword:aes-256-xts /etc/clash /srv/fs.crypt.img
```

Package keyserver (or just use the same keyserver as for Linux-keyless`):

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

Setup memfile directory for smc (sm-crypt):

```
mkdir-p ~/var/phoenix/memfiles/0
```

Package NGINX edge server:

```
cd ~/nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm
```

Run NGINX edge server:

```
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm
./nginx.manifest.sgx -p /nginx
```


<a name="single-tenant-graphene-crypt-exitless"/> Graphene-crypt-exitless
-------------------------------------------------------------------------

In the following manifests, specify the option `exitless` to the `THREADS`directive:

- `~/nginx-eval/config/single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm/manifest.conf`
- `~/src/fileserver/deploy/manifest.conf`
- `~/src/keyserver/deploy/manifest.conf`

Now, repeat the same steps as for
[Graphene-crypt](#single-tenant-graphene-crypt).



<a name="single-tenant-graphene-vericrypt"/> Graphene-vericrypt
---------------------------------------------------------------

Create bd-vericrypt filesystem image:

```
cd ~/src/fileserver/makefs
mkdir root
# root directory cannot be empty
echo hello > root/hello.txt
./makefs.py -v -s 128M fs.crypt.img root
cp fs.crypt.img ~/phoenix/fileserver/deploy/fs/srv/

# make the merkle tree file
./makemerkle.py -v -k macpassword fs.crypt.img fs.crypt.mt
cp fs.crypt.mt ~/src/fileserver/deploy/fs/srv
# note root hash (may be different):
#   fa0e822edf87f1a54df1298836a2548c8ca72b560e4e0cec01cc08be0ed6e270
```


Package the fileserver (or use the same package as for Graphen-crypt):

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

Run fileserver

```
cd ~/src/makemanifest/nextfsserver
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdvericrypt:/srv/fs.crypt.mt:macpassword:1845a98c4d4022fb080f8e2f33c60a297856bede1cf93c848c2029957b8e47d2:encpassword:aes-256-xts \
        /etc/clash /srv/fs.crypt.img
```


Package the smuf (sm-vericrypt) memory server:

```
# copy key material
cp ~/share/phoenix/root.crt ~/src/memserver/smuf/
cp ~/share/phoenix/proc.crt ~/src/memserver/smuf/
cp ~/share/phoenix/proc.key ~/src/memserver/smuf/

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

Package keyserver (or use the same package as with Linux-keyless):

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

Package NGINX edge server:

```
cd ~/nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nsm
```

Run NGINX edge server:

```
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nsm
./nginx.manifest.sgx -p /nginx
```


<a name="multi-tenant"/> Multi-tenant
=====================================

For simplicity, we have all replicas use the same origin server, and use the
same webserver certificate and key.


<a name="multi-tenant-linux-shared-nginx"/> Linux (shared NGINX)
----------------------------------------------------------------

The edge server multiplexes multiple websites on a single instance of NGINX.


Package the NGINX webserver:

```
cd ~/nginx-eval
make multi-tenant/share-nginx/linux-cache-nomodsec-release_nonsm
```

Go to the package directory:

```
cd pkg/multi-tenant/share-nginx/linux-cache-nomodsec-release_nonsm
ls
0 1 2 3 4 5
```

The directory `0` multiplexes a single website, the directory `1` multiplexes
two websites, and so forth.  All websites use the same
[keys](#nginx-tls-keys), which `make` copies over to each `conf/`
(e.g., `0/nginx/conf`).  Each website contacts the same origin server.  Note,
however, that each website has its own web cache.  The first website
listens on `*:8440`, the second on `*:8441`, and so forth. 

To benchmark, run the desired webserver:

```
cd 4/nginx
./sbin/nginx -p $PWD
```
and simultaneously run [ApacheBench](#apache-bench) against each
website (that is, for four websites, run four instances of ApacheBench).


<a name="multi-tenant-graphene-crypt-shared-nginx"/> Graphene-crypt (shared NGINX)
----------------------------------------------------------------------------------

Package the NGINX webserver:

```
cd ~/nginx-eval
make multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smc-nsm
```

Go to the package directory:

```
cd pkg/multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smc-nsm/
ls
0 1 2 3 4 5
```

The directories `0` - `5` are the same as for
[Linux (shared NGINX)](#multi-tenant-linux-shared-nginx).  Note, however, that
each website will have its own fileserver, keyserver, and directory where sm-crypt
stores the share memory files.

Let's go through the case of NGINX multiplexing two websites.  First create two
file system images, as per, an call one `fs.crypt.img0` and the other
`fs.crypt.img1`.  Copy these images to the fileserver's mount (we'll have
the two fileservers mount the same host directory:

```
cp fs.crypt.img0 ~/src/fileserver/deploy/fs/srv/
cp fs.crypt.img1 ~/src/fileserver/deploy/fs/srv/
```

Run two instances of the fileserver:

```
# Run website 0's fileserver:

cd ~/src/makemanifest/nextfsserver
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdcrypt:encpassword:aes-256-xts /etc/clash0 /srv/fs.crypt.img0

# In a different terminal, run website 1's fileserver:

cd ~/src/makemanifest/nextfsserver
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdcrypt:encpassword:aes-256-xts /etc/clash1 /srv/fs.crypt.img1
```

Next, run a keyserver for each website:


```
#Run website 0's keyserver:

cd ~/src/makemanifest/nsmserver
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000

# In a different terminal, run website 1's keyserver:
cd ~/src/makemanifest/nsmserver
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9001
```

Run NGINX:

```
cd ~/nginx-evalpkg/multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smc-nsm/1
./nginx.manifest.sgx -p /nginx
```


<a name="multi-tenant-graphene-crypt-shared-nothing"/> Graphene-crypt (shared nothing)
--------------------------------------------------------------------------------------

```
cd ~/nginx-eval
make multi-tenant/share-nothing/graphene-cache-nomodsec-release_nextfs-smc-nsm
```


<a name="waf"/> Web Application Firewall
========================================


<a name="waf-linux"/> Linux
---------------------------

```
cd ~/nginx-eval
make standalone/linux-standalone-modsec-release_nonsm:
```


<a name="waf-graphene-crypt"/> Graphene-crypt
---------------------------------------------

```
cd ~/nginx-eval
make standalone/graphene-standalone-modsec-release_nextfs-smc-nsm:
```

<a name="graphene-crashes"/> Graphene Crashes
=============================================

NGINX edge server:

```
shim_init() in init_mount (-2)
Saturation error in exit code -2, getting rounded down to 254
```

This means a kernel server was not setup properly.


```
warn tnt_client_from_config:142 timeserver.rsa_n not in config
nginx: [alert] unlink() "/memserver0/.accept" failed (38: Function not implemented)
nginx: [alert] unlink() "/memserver0/ZONE_ONE" failed (38: Function not implemented)
nginx: [alert] listen() to 0.0.0.0:8443, backlog 511 failed, ignored (22: Invalid argument)
nginx: [alert] unlink() "/memserver0/.accept" failed (38: Function not implemented)
assert failed ipc/shim_ipc_nsimpl.h:834 !qstrempty(&NS_LEADER->uri) (value:0)
Saturation error in exit code -131, getting rounded down to 125
```
