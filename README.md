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


# Keys

## NGINX TLS keys
The NGINX TLS cert and private key are `config/mounts/nginx/conf/server.crt`
and `config/mounts/nginx/conf/server.key`, respectively.

## Phoenix TLS keys
The keying material that the Phoenix kernel servers (e.g., nextfs, smdish) use are
`config/root.crt` as the CA cert, `config/proc.crt` as the TLS certificate for
a key server, and `config/proc.key`, as the private key.  For this benchmark,
all kernel servers use the same certs and keys.


# Connecting two computers directly with an ethernet cable
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

# Running ApacheBench

## Single-Tenant
Macs should have ApacheBench installed by default (`/usr/sbin/ab`).
We configure NGINX to run a single worker process, and run the following

```
ab -n 1000 -c 8 https://192.168.99.10:8443/1k.txt
```

This makes 1000 total requests from 8 concurrent clients (that is `ab` will
issue 8 requests at the same time).

## Origin

```
make origin/linux-standalone-nomodsec-release_origin
cd pkg/origin/linux-standalone-nomodsec-release_origin/nginx
./sbin/nginx -p $PWD -c conf/nginx.conf
```

# Single-Tenant Benchmarks

## Linux

### `linux-cache-nomodsec-debug_nonsm`

```
make single-tenant/linux-cache-nomodsec-debug_nonsm/nginx
cd pkg/single-tenant/linux-cache-nomodsec-debug_nonsm/nginx
./sbin/nginx -p $PWD -c conf/nginx.conf
```

### `linux-cache-nomodsec-debug_nsm`

```
cp config/mounts/nginx/conf/server.key ~/phoenix/keyserver/server/
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver
cd nsmserver
mv manifest.sgx nsmserver.manifest.sgx
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:900
```

```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/linux-cache-nomodsec-debug_nsm/nginx
cd pkg/single-tenant/linux-cache-nomodsec-debug_nonsm/nginx
./sbin/nginx -p $PWD -c conf/nginx.conf
```

## Graphene

### graphene-chrootfs-smdish-nonsm
First, package the memory server:

```
cp config/root.crt ~/phoenix/memserver/smdish/
cp config/proc.crt ~/phoenix/memserver/smdish/
cp config/proc.key ~/phoenix/memserver/smdish/

cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smdishserver.conf \
        -t $PWD -v -o smdishserver
cd smdishserver
mv manifest.sgx smdishserver.manifest.sgx
./smdishserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key /etc/ramones
```

Next, package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nonextfs-smdish-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nonextfs-smdish-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-chrootfs-smdish-nsm
Package the memory server:
```
cp config/root.crt ~/phoenix/memserver/smdish/
cp config/proc.crt ~/phoenix/memserver/smdish/
cp config/proc.key ~/phoenix/memserver/smdish/

cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smdishserver.conf \
        -t $PWD -v -o smdishserver
cd smdishserver
mv manifest.sgx smdishserver.manifest.sgx
./smdishserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key /etc/ramones
```

Package the key server:
```
cp config/mounts/nginx/conf/server.key ~/phoenix/keyserver/server/
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver 
cd nsmserver
mv manifest.sgx nsmserver.manifest.sgx
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nonextfs-smdish-nsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nonextfs-smdish-nsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-chrootfs-smuf-nonsm

Package the smuf memory server:
```
# copy key material
cp config/root.crt ~/phoenix/memserver/smuf/
cp config/proc.crt ~/phoenix/memserver/smuf/
cp config/proc.key ~/phoenix/memserver/smuf/

# reset the memfile dir
rm -rf ~/phoenix/memfiles/0
mkdir ~/phoenix/memfiles/0

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smufserver.conf \
        -t $PWD -v -o smufserver
cd smufserver
mv manifest.sgx smufserver.manifest.sgx

# run
./smufserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key -r /memfiles0 /etc/ramones
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nonextfs-smuf-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nonextfs-smuf-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-chrootfs-smuf-nsm

Package the smuf memory server:
```
# copy key material
cp config/root.crt ~/phoenix/memserver/smuf/
cp config/proc.crt ~/phoenix/memserver/smuf/
cp config/proc.key ~/phoenix/memserver/smuf/

# reset the memfile dir
rm -rf ~/phoenix/memfiles/0
mkdir ~/phoenix/memfiles/0

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smufserver.conf \
        -t $PWD -v -o smufserver
cd smufserver
mv manifest.sgx smufserver.manifest.sgx

# run
./smufserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key -r /memfiles0 /etc/ramones
```

Package the key server:
```
# copy the NGINX SSL private key
cp config/mounts/nginx/conf/server.key ~/phoenix/keyserver/server/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver 
cd nsmserver
mv manifest.sgx nsmserver.manifest.sgx

# run
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nonextfs-smuf-nsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nonextfs-smuf-nsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-chrootfs-smc-nonsm

Prepare the chroot mount used for smc's shared memory:
```
# reset the memfile dir
rm -rf ~/phoenix/memfiles/0
mkdir ~/phoenix/memfiles/0
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nonextfs-smc-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nonextfs-smc-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-chrootfs-smc-nsm

Prepare the chroot mount used for smc's shared memory:
```
# reset the memfile dir
rm -rf ~/phoenix/memfiles/0
mkdir ~/phoenix/memfiles/0
```

Package the key server:
```
# copy the NGINX SSL private key
cp config/mounts/nginx/conf/server.key ~/phoenix/keyserver/server/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver 
cd nsmserver
mv manifest.sgx nsmserver.manifest.sgx

# run
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nonextfs-smc-nsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nonextfs-smc-nsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-bdstd-smdish-nonsm

Package the nextfs file server with bdstd block device:
```
# copy over the key material
cp config/root.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.key ~/phoenix/fileserver/deploy/fs/srv/

# create filesystem
cd ~/phoenix/fileserver/makefs
mkdir root
# the -t 2 and -b 1024 are superfluous, as those are the defaults
./makefs.py -v -t 2 -s 128M -l $HOME/bin/lwext4-mkfs \
        -b 1024 fs.std.img root
cp fs.std.img ~/phoenix/fileserver/deploy/fs/srv/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 

# run
mv manifest.sgx nextfsserver.manifest.sgx
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdstd /etc/clash /srv/fs.std.img
```


Package the smdish shared memory server:
```
# copy over the key material
cp config/root.crt ~/phoenix/memserver/smdish/
cp config/proc.crt ~/phoenix/memserver/smdish/
cp config/proc.key ~/phoenix/memserver/smdish/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smdishserver.conf \
        -t $PWD -v -o smdishserver

# run
cd smdishserver
mv manifest.sgx smdishserver.manifest.sgx
./smdishserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key /etc/ramones
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-bdstd-smdish-nsm

Package the nextfs file server with bdstd block device:
```
# copy over the key material
cp config/root.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.key ~/phoenix/fileserver/deploy/fs/srv/

# create filesystem
cd ~/phoenix/fileserver/makefs
mkdir root
# the -t 2 and -b 1024 are superfluous, as those are the defaults
./makefs.py -v -t 2 -s 128M -l $HOME/bin/lwext4-mkfs \
        -b 1024 fs.std.img root
cp fs.std.img ~/phoenix/fileserver/deploy/fs/srv/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 

# run
mv manifest.sgx nextfsserver.manifest.sgx
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdstd /etc/clash /srv/fs.std.img
```


Package the smdish shared memory server:
```
# copy over the key material
cp config/root.crt ~/phoenix/memserver/smdish/
cp config/proc.crt ~/phoenix/memserver/smdish/
cp config/proc.key ~/phoenix/memserver/smdish/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smdishserver.conf \
        -t $PWD -v -o smdishserver

# run
cd smdishserver
mv manifest.sgx smdishserver.manifest.sgx
./smdishserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key /etc/ramones
```

Package the key server:
```
# copy the NGINX SSL private key
cp config/mounts/nginx/conf/server.key ~/phoenix/keyserver/server/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver 
cd nsmserver
mv manifest.sgx nsmserver.manifest.sgx

# run
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-bdstd-smuf-nonsm

Package the nextfs file server with bdstd block device:
```
# copy over the key material
cp config/root.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.key ~/phoenix/fileserver/deploy/fs/srv/

# create filesystem
cd ~/phoenix/fileserver/makefs
mkdir root
# the -t 2 and -b 1024 are superfluous, as those are the defaults
./makefs.py -v -t 2 -s 128M -l $HOME/bin/lwext4-mkfs \
        -b 1024 fs.std.img root
cp fs.std.img ~/phoenix/fileserver/deploy/fs/srv/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 

# run
mv manifest.sgx nextfsserver.manifest.sgx
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdstd /etc/clash /srv/fs.std.img
```

Package the smuf memory server:
```
# copy key material
cp config/root.crt ~/phoenix/memserver/smuf/
cp config/proc.crt ~/phoenix/memserver/smuf/
cp config/proc.key ~/phoenix/memserver/smuf/

# reset the memfile dir
rm -rf ~/phoenix/memfiles/0
mkdir ~/phoenix/memfiles/0

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smufserver.conf \
        -t $PWD -v -o smufserver
cd smufserver
mv manifest.sgx smufserver.manifest.sgx

# run
./smufserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key -r /memfiles0 /etc/ramones
```


Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-bdstd-smuf-nsm

Package the nextfs file server with bdstd block device:
```
# copy over the key material
cp config/root.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.key ~/phoenix/fileserver/deploy/fs/srv/

# create filesystem
cd ~/phoenix/fileserver/makefs
mkdir root
# the -t 2 and -b 1024 are superfluous, as those are the defaults
./makefs.py -v -t 2 -s 128M -l $HOME/bin/lwext4-mkfs \
        -b 1024 fs.std.img root
cp fs.std.img ~/phoenix/fileserver/deploy/fs/srv/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 

# run
mv manifest.sgx nextfsserver.manifest.sgx
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdstd /etc/clash /srv/fs.std.img
```

Package the smuf memory server:
```
# copy key material
cp config/root.crt ~/phoenix/memserver/smuf/
cp config/proc.crt ~/phoenix/memserver/smuf/
cp config/proc.key ~/phoenix/memserver/smuf/

# reset the memfile dir
rm -rf ~/phoenix/memfiles/0
mkdir ~/phoenix/memfiles/0

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smufserver.conf \
        -t $PWD -v -o smufserver
cd smufserver
mv manifest.sgx smufserver.manifest.sgx

# run
./smufserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key -r /memfiles0 /etc/ramones
```

Package the key server:
```
# copy the NGINX SSL private key
cp config/mounts/nginx/conf/server.key ~/phoenix/keyserver/server/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver 
cd nsmserver
mv manifest.sgx nsmserver.manifest.sgx

# run
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-bdstd-smc-nonsm

Package the nextfs file server with bdstd block device:
```
# copy over the key material
cp config/root.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.key ~/phoenix/fileserver/deploy/fs/srv/

# create filesystem
cd ~/phoenix/fileserver/makefs
mkdir root
# the -t 2 and -b 1024 are superfluous, as those are the defaults
./makefs.py -v -t 2 -s 128M -l $HOME/bin/lwext4-mkfs \
        -b 1024 fs.std.img root
cp fs.std.img ~/phoenix/fileserver/deploy/fs/srv/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 

# run
mv manifest.sgx nextfsserver.manifest.sgx
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdstd /etc/clash /srv/fs.std.img
```

Prepare the chroot mount used for smc's shared memory:
```
# reset the memfile dir
rm -rf ~/phoenix/memfiles/0
mkdir ~/phoenix/memfiles/0
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-bdstd-smc-nsm

Package the nextfs file server with bdstd block device:
```
# copy over the key material
cp config/root.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.key ~/phoenix/fileserver/deploy/fs/srv/

# create filesystem
cd ~/phoenix/fileserver/makefs
mkdir root
# the -t 2 and -b 1024 are superfluous, as those are the defaults
./makefs.py -v -t 2 -s 128M -l $HOME/bin/lwext4-mkfs \
        -b 1024 fs.std.img root
cp fs.std.img ~/phoenix/fileserver/deploy/fs/srv/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 

# run
mv manifest.sgx nextfsserver.manifest.sgx
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdstd /etc/clash /srv/fs.std.img
```

Prepare the chroot mount used for smc's shared memory:
```
# reset the memfile dir
rm -rf ~/phoenix/memfiles/0
mkdir ~/phoenix/memfiles/0
```

Package the key server:
```
# copy the NGINX SSL private key
cp config/mounts/nginx/conf/server.key ~/phoenix/keyserver/server/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/keyserver/deploy/manifest.conf \
        -t $PWD -v -o nsmserver 
cd nsmserver
mv manifest.sgx nsmserver.manifest.sgx

# run
./nsmserver.manifest.sgx -r /srv tcp://127.0.0.1:9000
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

### graphene-bdcrypt-smdish-nonsm

Package the nextfs file server with bdstd block device:
```
# copy over the key material
cp config/root.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.key ~/phoenix/fileserver/deploy/fs/srv/

# create filesystem
cd ~/phoenix/fileserver/makefs
mkdir root
# the -t, -b, and -c flags are superfluous, as those are the defaults
./makefs.py -v -t 2 -s 128M -l $HOME/bin/lwext4-mkfs \
        -b 1024 -c aes-256-xts -p encpassword fs.crypt.xts.img root
cp fs.crypt.xts.img ~/phoenix/fileserver/deploy/fs/srv/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 

# run
mv manifest.sgx nextfsserver.manifest.sgx
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdcrypt:encpassword:aes-256-cbc /etc/clash /srv/fs.crypt.xts.img
```


Package the smdish shared memory server:
```
# copy over the key material
cp config/root.crt ~/phoenix/memserver/smdish/
cp config/proc.crt ~/phoenix/memserver/smdish/
cp config/proc.key ~/phoenix/memserver/smdish/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smdishserver.conf \
        -t $PWD -v -o smdishserver

# run
cd smdishserver
mv manifest.sgx smdishserver.manifest.sgx
./smdishserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key /etc/ramones
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

yada yada yada

### graphene-bdverity-smdish-nonsm

Package the nextfs file server with bdstd block device:
```
# copy over the key material
cp config/root.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.key ~/phoenix/fileserver/deploy/fs/srv/

# create filesystem
cd ~/phoenix/fileserver/makefs
mkdir root
# (the -t and -b flags are superfluous, as those are the defaults)
./makefs.py -v -t 2 -s 128M -l $HOME/bin/lwext4-mkfs \
        -b 1024 fs.std.img root
cp fs.std.img ~/phoenix/fileserver/deploy/fs/srv/

# make the merkle tree file
# (the -a and -b flags are superfluous, as those are the defaults)
./makemerkle.py -v -a sha256 -b 1024 -k macpassword fs.std.img fs.std.mt
cp fs.std.mt ~/phoenix/fileserver/deploy/fs/srv
# root hash: 1845a98c4d4022fb080f8e2f33c60a297856bede1cf93c848c2029957b8e47d2

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 

# run
mv manifest.sgx nextfsserver.manifest.sgx
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdverity:/srv/fs.std.mt:macpassword:1845a98c4d4022fb080f8e2f33c60a297856bede1cf93c848c2029957b8e47d2 \
        /etc/clash /srv/fs.std.img
```


Package the smdish shared memory server:
```
# copy over the key material
cp config/root.crt ~/phoenix/memserver/smdish/
cp config/proc.crt ~/phoenix/memserver/smdish/
cp config/proc.key ~/phoenix/memserver/smdish/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smdishserver.conf \
        -t $PWD -v -o smdishserver

# run
cd smdishserver
mv manifest.sgx smdishserver.manifest.sgx
./smdishserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key /etc/ramones
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```


## Changing `manifest.conf` name
The need to change the name of the manifest, as in

```
mv manifest.sgx nginx.manifest.sgx
```

## Absolute vs Relative paths in `manifest.conf`
`makemanifest` inserts absolute paths for the exeuctable and read-only chroot
mounts, but relative paths for the read-write chroot mounts.

## nextfs
One of the nginx processes (not the worker) fails with

```
assert failed fs/nextfs/fs.c:209 fs != ((void *)0) (value:0)
```

yada yada yada

### graphene-bdvericrypt-smdish-nonsm

Package the nextfs file server with bdstd block device:
```
# copy over the key material
cp config/root.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.crt ~/phoenix/fileserver/deploy/fs/srv/
cp config/proc.key ~/phoenix/fileserver/deploy/fs/srv/

# create filesystem
# the -t, -b, and -c flags are superfluous, as those are the defaults
./makefs.py -v -t 2 -s 128M -l $HOME/bin/lwext4-mkfs \
        -b 1024 -c aes-256-xts -p encpassword fs.crypt.xts.img root
cp fs.crypt.xts.img ~/phoenix/fileserver/deploy/fs/srv/

# make the merkle tree file
# (the -a and -b flags are superfluous, as those are the defaults)
./makemerkle.py -v -a sha256 -b 1024 -k macpassword fs.crypt.xts.img fs.crypt.xts.mt
cp fs.crypt.xts.mt ~/phoenix/fileserver/deploy/fs/srv
# root hash: 404438898db76e9afb60f52f2a9107ffaf991833bcba554f085a429a102775a5

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/fileserver/deploy/manifest.conf \
        -t $PWD -v -o nextfsserver 

# run
mv manifest.sgx nextfsserver.manifest.sgx
./nextfsserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key \
        -b bdvericrypt:/srv/fs.crypt.xts.mt:macpassword:404438898db76e9afb60f52f2a9107ffaf991833bcba554f085a429a102775a5:encpassword:aes-256-xts \
        /etc/clash /srv/fs.crypt.xts.img
```


Package the smdish shared memory server:
```
# copy over the key material
cp config/root.crt ~/phoenix/memserver/smdish/
cp config/proc.crt ~/phoenix/memserver/smdish/
cp config/proc.key ~/phoenix/memserver/smdish/

# package
cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smdishserver.conf \
        -t $PWD -v -o smdishserver

# run
cd smdishserver
mv manifest.sgx smdishserver.manifest.sgx
./smdishserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key /etc/ramones
```

Package NGINX:
```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx
```

# Multi-Tenant Benchmarks


## Share nothing
For simplicity, we have all replicas use the same origin server, and use
the same cert/key.

Naming schemes for pipes:
replico0:
    MOUNT pipe:2201945198 /fsserver  nextfs     (/etc/clash0)
    MOUNT pipe:267486944 /memserver mdish       (/etc/ramones0)
    listen on 8440
    keyserver listen on on 9000

replica1:
    MOUNT pipe:2202006382 /fsserver  nextfs     (/etc/clash1)
    MOUNT pipe:921798368 /memserver mdish       (/etc/ramones1)
    listen on 8441
    keyserver listen on on 9001

replica2:
    MOUNT pipe:2202004078 /fsserver  nextfs     (/etc/clash2)
    MOUNT pipe:569476832 /memserver mdish       (/etc/ramones2)
    listen on 8442
    keyserver listen on on 9002

replica3:
    MOUNT pipe:2202001774 /fsserver  nextfs     (/etc/clash3)
    MOUNT pipe:686917344 /memserver mdish       (/etc/ramones3)
    listen on 8443
    keyserver listen on on 9003



### 



# BUGS

## rpc
Once in a blue moon, the enclaved NGINX application reports the error:

```
warn rapc_agent_request:414 rpc returned an error: 11: Unknown error
```

I think this is just contention on the lock, as 11 is `EAGAIN`.

```
There are  no TCS pages ...
```
