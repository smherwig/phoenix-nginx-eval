Overview
=========

Performance evaluations of NGINX webserver running on the
[Phoenix](https://github.com/smherwig/phoenix) SGX microkernel.


Setup
=====


Build NGINX
-----------

Download NGINX and create a patched version of NGINX for Phoenix/Graphene:


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

NGINX TLS keys
--------------
The NGINX TLS cert and private key are `config/mounts/nginx/conf/server.crt`
and `config/mounts/nginx/conf/server.key`, respectively.



Connecting two computers directly with an ethernet cable
---------------------------------------------------------
This is based on
https://superuser.com/questions/842924/directly-connect-macbook-to-linux-desktop-via-ethernet-for-fast-ssh

On the Ubuntu machine (the SGX machine), edit `/etc/network/interfaces` to add
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

Reboot the machine.  After reboot, the `eno1` physical port will have IP adress
`192.168.99.10`.

On you Mac, hookup the Ethernet cable and go to
`System Preferences > Network > Ethernet` and configure as follows:


```
Configure IPv4: Manually
    IP Address: 192.168.99.20
   Subnet Mask: 255.255.255.0
        Router: 192.168.99.1
    DNS Server: <blank>
Search Domains: <blank>
```

I also had to turn WiFi off on my Mac. (It might be the case
that Ethernet and WiFi can co-exist on the Mac, but that that
Ethernet needs to be ordered higher than the Wifi.)


ApacheBench
-----------

Macs should have ApacheBench installed by default (`/usr/sbin/ab`).
We configure NGINX to run a single worker process, and run the following

```
ab -n 1000 -c 8 https://192.168.99.10:8443/1k.txt
```

This makes 1000 total requests from 8 concurrent clients (that is `ab` will
issue 8 requests at the same time).


Origin Server
-------------

```
make origin/linux-standalone-nomodsec-release_origin
cd pkg/origin/linux-standalone-nomodsec-release_origin/nginx
./sbin/nginx -p $PWD
```


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
