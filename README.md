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
```
cp config/root.crt ~/phoenix/memserver/smdish/

cp config/server.crt ~/phoenix/memserver/smdish/
cp config/server.key ~/phoenix/memserver/smdish/

cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smdishserver.conf \
        -t $PWD -v -o smdishserver
cd smdishserver
mv manifest.sgx smdishserver.manifest.sgx
./smdishserver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key /etc/ramones
```

```
cd ~/phoenix/phoenix-nginx-eval
make single-tenant/graphene-cache-nomodsec-release_nonextfs-smdish-nonsm
cd pkg/single-tenant/graphene-cache-nomodsec-release_nonextfs-smdish-nonsm
mv manifest.sgx nginx.manifest.sgx
./nginx.manifest.sgx -p /nginx -c /nginx/conf/nginx.conf
```

### graphene-chrootfs-smuf-nonsm

```
cp config/root.crt ~/phoenix/memserver/smdish/

cp config/server.crt ~/phoenix/memserver/smdish/
cp config/server.key ~/phoenix/memserver/smdish/

cd ~/phoenix/makemanifest
./make_sgx.py -g ~/ws/phoenix -k enclave-key.pem \
        -p ~/phoenix/memserver/deploy/smufserver.conf \
        -t $PWD -v -o smufserver
cd smufserver
mv manifest.sgx smufserver.manifest.sgx
./smuferver.manifest.sgx -Z /srv/root.crt /srv/proc.crt /srv/proc.key -r /memfiles0 /etc/ramones
```



# BUGS

## Changing `manifest.conf` name
The need to change the name of the manifest, as in

```
mv manifest.sgx nginx.manifest.sgx
```

## Absoluate vs Relative paths in `manifest.conf`
`makemanifest` inserts absolute paths for the exeuctable and read-only chroot
mounts, but relative paths for the read-write chroot mounts.



