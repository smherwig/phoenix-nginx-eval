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

Afterwords, there are two new new directories: `nginx-1.14.1`, which is the
vanilla version of NGINX, and `nginx-1.14.1-graphene`, which is the patched
version.  The patched version side-steps a few bugs in Graphene-SGX and also
forces the use of Phoenix's shared memory implementations.  An important result
of the patch is that NGINX only accepts HTTPS requests.  See `patch/README` for
further details.


Download, build, and install `libmodsecurity.so`.  This library may already be
installed to `/usr/local/modsecurity`.  We specifically build the library
without curl support, as Graphene appears to have a bug when handling libcurl's
library constructor (or the library constructor of one of libcurl's
dependencies).

```
bin/get_modsecurity.sh
```

Download the NGINX modsecurity connector plugin:

```
bin/get_modsecurity_connector.sh
```

Next, build several versions of NGINX; the options to `./configure`
differ among the versions, and some versions build the ModSecurity
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

For development purposes, a self-signed certificate and private key are located
at `config/mounts/nginx/conf/server.crt` and
`config/mounts/nginx/conf/server.key`, respectively.  If desired, invoke
`bin/make_nginx_self_signed_cert.sh` to generate a new
certificate and key, and then copy these into `config/mounts/nginx/conf`.


<a name="web-content" /> Web Content
------------------------------------

The NGINX servers are configured to serve the following files:

- `1k.txt`: a 1024-byte ASCII text file
- `10k.txt`: a 10240-byte ASCII text file
- `100k.txt`: a 102400-byte ASCII text file
- `1m.txt`: a 1048576-byte ASCII text file


<a name="apache-bench"/> ApacheBench
------------------------------------

We use ApacheBench to benchmark NGINX's request latency and throughput.
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
served by NGINX, such as `https://192.168.99.10:8443/1k.txt`, or
`https://127.0.0.1:8443/1k.txt`.


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

If ApacheBench is run from another Ubuntu device, then likewise edit that
system's `/etc/network/interfaces`, but with an IP address of `192.168.99.20`.

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

I also had to turn off WiFi on my Mac. (It might be the case that Ethernet and
WiFi can co-exist on the Mac, but that Ethernet needs to be ordered
higher than the Wifi.)


<a name="graphene-bugs"/> Graphene Bugs
==========================================

CTRL-C
------

Graphene is often unresponsive to `CTRL-C`, especially when the Graphene
application is multi-process.  In order to kill all instances of Graphene,
enter:


Racy Conditions
---------------

For some shared resources, such as POSIX semaphores, NGINX implements a leader
election algorithm.  The implementation of this algorithm is very buggy and
often causes a crash the first time an process forks.  This is only an issue
with multiprocess applications (e.g., NGINX, not the kernel servers), and  will
appear as the standard error log line:

```
assert failed ipc/shim_ipc_nsimpl.h:834 !qstrempty(&NS_LEADER->uri) (value:0)
```


`MOUNT` Configuration Errors
----------------------------

A message to stderr of:

```
shim_init() in init_mount (-2)
```

usually indicates that the `MOUNT` directive in `manifest.conf` for a kernel
server was not properly specified.


<a name="origin-server"/> Origin Server
---------------------------------------

Package and run an origin webserver.  By "package", we mean copying a build and
overlaying specific configuration form `config/`.  The Makefile targets handle
packaging:

```
make origin/linux-standalone-nomodsec-release_origin
cd pkg/origin/linux-standalone-nomodsec-release_origin/nginx
./sbin/nginx -p $PWD
```

By default, the origin server runs on `localhost:8081`.  For a different bind
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
hosting a single site and communicating to the backend [origin
server](#origin-server).  By default, the NGINX instance listens on
`*:8443`.  

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

Goto the package directory:

```
cd pkg/single-tenant/linux-cache-nomodsec-release_nsm/nginx
```

Ensure that `conf/nginx.conf`'s `ssl_engine` directive points to the user's
installation of `nsm-engine.so`.

```
# change "smherwig" to correct user
ssl_engine /home/smherwig/lib/nsm-engine.so;
```

Run NGINX edge server:

```
./sbin/nginx -p $PWD
```

<a name="single-tenant-graphene-crypt"/> Graphene-crypt
-------------------------------------------------------

Benchmark NGINX runnning on Graphene with a bd-crypt backed filesystem, the
sm-crypt shared memory implementation, and an enclaved keyserver.

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

Package keyserver (or just use the same keyserver as for
[Linux-keyless](#single-tenant-linux-keyless).

```
cp ~/nginx-eval/config/mounts/nginx/conf/server.key ~/src/keyserver/server/
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
reset_phoenix_memfiles.sh
```

Package NGINX edge server:

```
cd ~/nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm
```

Go to the package directory:

```
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm
```

Ensure that `conf/nginx.conf`'s `ssl_engine` directive points to the user's
installation of `nsm-engine.so`.

```
# change "smherwig" to correct user
ssl_engine /home/smherwig/lib/nsm-engine.so;
```

Run NGINX edge server:

```
./nginx.manifest.sgx -p /nginx
```


<a name="single-tenant-graphene-crypt-exitless"/> Graphene-crypt-exitless
-------------------------------------------------------------------------

Benchmark NGINX runnning on Graphene with a bd-crypt backed filesystem, the
sm-crypt shared memory implementation, and an enclaved keyserver.  All enclaved
processes use exitless system calls.

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
./makefs.py -v -s 128M -p encpassword fs.crypt.img root
cp fs.crypt.img ~/src/fileserver/deploy/fs/srv/

# make the merkle tree file
./makemerkle.py -v -k macpassword fs.crypt.img fs.crypt.mt
cp fs.crypt.mt ~/src/fileserver/deploy/fs/srv
# note root hash (may be different):
#   fa0e822edf87f1a54df1298836a2548c8ca72b560e4e0cec01cc08be0ed6e270
```


Package the fileserver (or use the same package as for
[Graphene-crypt](#single-tenant-graphene-crypt)).

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
reset_phoenix_memfiles.sh
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

Go to the package directory:

```
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nsm
```

Ensure that `conf/nginx.conf`'s `ssl_engine` directive points to the user's
installation of `nsm-engine.so`.

```
# change "smherwig" to correct user
ssl_engine /home/smherwig/lib/nsm-engine.so;
```

Run NGINX edge server:

```
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
stores the shared memory files.

Let's go through the case of NGINX multiplexing two websites.  First create two
file system images, as per [Graphene-crypt](#single-tenant-graphene-crypt), and
call one `fs.crypt.img0` and the other `fs.crypt.img1`.  Copy these images to
the fileserver's mount (we'll have the two fileservers mount the same host
        directory:

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
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdcrypt:encpassword:aes-256-xts /etc/clash1 /srv/fs.crypt.img1
```

Next, run a keyserver for each website:


```
#Run website 0's keyserver:
cd ~/src/makemanifest/nsmserver
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000

# In a different terminal, run website 1's keyserver:
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9001
```

Prepare the sm-crypt shared memory directories:

```
reset_phoenix_memfiles.sh
```

Go to the package directory:

```
cd ~/nginx-evalpkg/multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smc-nsm/1
```

Ensure that `conf/nginx.conf`'s `ssl_engine` directive points to the user's
installation of `nsm-engine.so`.

```
# change "smherwig" to correct user
ssl_engine /home/smherwig/lib/nsm-engine.so;
```

Run NGINX:

```
./nginx.manifest.sgx -p /nginx
```


<a name="multi-tenant-graphene-crypt-shared-nothing"/> Graphene-crypt (shared nothing)
--------------------------------------------------------------------------------------

Each website has its own instance of NGINX and own fileserver and keyserver:

```
cd ~/nginx-eval
make multi-tenant/share-nothing/graphene-cache-nomodsec-release_nextfs-smc-nsm
```

```
cd pkg/multi-tenant/share-nothing/graphene-cache-nomodsec-release_nextfs-smc-nsm/
ls
0 1 2 3 4 5
``` 

Each directory `0` - `5` represents a different website.


Let's go through the case of running two websites.  First create two
file system images, as per [Graphene-crypt](#single-tenant-graphene-crypt), and
call one `fs.crypt.img0` and the other `fs.crypt.img1`.  Copy these images to
the fileserver's mount (we'll have the two fileservers mount the same host
        directory:

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

Prepare the sm-crypt shared memory directories:

```
reset_phoenix_memfiles.sh
```

Go to the NGINX package directory:

```
cd ~/nginx-eval/pkg/multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smc-nsm
```

Ensure that `0/nginx/conf/nginx.conf`'s and `1/nginx/conf/nginx.conf`'s
`ssl_engine` directive points to the user's installation of `nsm-engine.so`.

```
# change "smherwig" to correct user
ssl_engine /home/smherwig/lib/nsm-engine.so;
```

Run two instances of NGINX:

```
# Run website 0's NGINX:
cd ~/nginx-eval/pkg/multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smc-nsm/0
./nginx.manifest.sgx -p /nginx

# Run website 1's NGINX:
cd ~/nginx-eval/pkg/multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smc-nsm/1
./nginx.manifest.sgx -p /nginx
```


<a name="waf"/> Web Application Firewall
========================================

These benchmarks evaluate the performance of a standlone instance of NGINX
(that is a non-caching version) running the ModSecurity Web Application
Firewall.  An origin server is not needed.


<a name="waf-linux"/> Linux
---------------------------

Benchmark NGINX running on vanilla Linux with ModSecurity.

Package NGINX:

```
cd ~/nginx-eval
make standalone/linux-standalone-modsec-release_nonsm:
```

Go to the package directory:

```
cd pkg/standalone/linux-standalone-modsec-release_nonsm/nginx
```

Adjust the number of modsec rules in `conf/nginx.conf`:

```
modsecurity_rules_file modsec/main-1rule.conf;
```

This represents a WAF with 1 rules.  Change this line
to point to any file in `modsec/` (e.g., `modsec/man-10rule.conf`
has ten rules).

Each rule simply examines a `testparam` argument in the HTTP request's query
string for a blacklisted substring:

```
cat modsec/main-1rule.conf
Include "modsec/modsecurity.conf"
SecRule ARGS:testparam "@contains hGnYKu" "id:1,deny,status:403"
```

Run NGINX:

```
./sbin/nginx -p $PWD
```

To test that the `main-1rule.conf` is active, ensure that a query with a
blacklisted substring returns `403 Forbidden`:

```
curl --insecure https://127.0.0.1:8443/1k.txt?testparam=hGnYKu
<html>
<head><title>403 Forbidden</title></head>
<body bgcolor="white">
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx/1.14.1</center>
</body>
</html>
smherwig@smherwig-sgx:~$ 
```

and that a query for non-blacklisted substring returns valid content:

```
curl --insecure https://127.0.0.1:8443/1k.txt
abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghij
```

If, for comparison, you wish to run NGINx without ModSecurity,
comment out the following lines in `conf/nginx.conf`:

```
load_module modules/ngx_http_modsecurity_module.so

modsecurity on;
modsecurity_rules_file modsec/main-1rule.conf
```


<a name="waf-graphene-crypt"/> Graphene-crypt
---------------------------------------------

Benchmark NGINX with ModSecurity enabled running on Graphene with a bd-crypt
backed filesystem, sm-crypt shared memory, and an enclaved keyserver.

Package NGINX:

```
cd ~/nginx-eval
make standalone/graphene-standalone-modsec-release_nextfs-smc-nsm:
```

Go to the package directory:

```
cd pkg/standalone/graphene-standalone-modsec-release_nextfs-smc-nsm/
```

In the `nginx/modsec/main-*rule.conf` files, change the line:

```
Include "modsec/modsecurity.conf"
```

to

```
Include "/fsserver0/modsec/modsecurity.conf"
```

Create the filesystem image:

```
cd ~/src/fileserver/makefs 
mkdir root-modsec

cd root-modsec
cp -R ~/nginx-eval/pkg/standalone/graphene-standalone-modsec-release_nextfs-smc-nsm/nginx/html .

cp -R ~/nginx-eval/pkg/standalone/graphene-standalone-modsec-release_nextfs-smc-nsm/nginx/modsec .

cd ..

./makefs.py -v -s 128M -p encpassword fs.modsec.crypt.img root-modsec
cp fs.modsec.crypt.img ~/src/fileserver/deploy/fs/srv/
```


Run the fileserver:

```
cd ~/src/makemanifest/nextfsserver
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdcrypt:encpassword:aes-256-xts /etc/clash /srv/fs.modsec.crypt.img
```

Prepare the sm-crypt directory:

```
reset_phoenix_memfiles.sh
```

Run the keyserver:

```
cd ~/src/makemanifest/nsmserver
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Goto the NGINX package directory:

```
cd ~/nginx-eval/pkg/standalone/graphene-standalone-modsec-release_nextfs-smc-nsm
```

Ensure that `nginx/conf/nginx.conf`'s 
`ssl_engine` directive points to the user's installation of `nsm-engine.so`.

```
# change "smherwig" to correct user
ssl_engine /home/smherwig/lib/nsm-engine.so;
```

Run NGINX:

```
./nginx.manifest.sgx -p /nginx
``` 
