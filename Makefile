# LOCATIONS
#---------------------------------------------------------
TOP=$(PWD)
NGINX= nginx-1.14.1
NGINX_GRAPHENE= nginx-1.14.1-graphene
NGINX_TLS_ONLY= nginx-1.14.1-tls-only
GRAPHENE=$(HOME)/src/phoenix
MAKEMANIFEST=$(HOME)/src/makemanifest


# TOOLS
#---------------------------------------------------------
MAKE_SGX=$(MAKEMANIFEST)/make_sgx.py


# KEYS
#---------------------------------------------------------
ENCLAVE_KEY=$(HOME)/share/phoenix/enclave-key.pem


# NGINX configure options
#---------------------------------------------------------
COMMON_CFG_OPTS= \
	--with-http_ssl_module \
    --without-http_upstream_hash_module \
    --without-http_upstream_ip_hash_module \
    --without-http_upstream_least_conn_module \
    --without-http_upstream_keepalive_module \
    --without-http_upstream_zone_module \
	--without-stream_upstream_hash_module \
	--without-stream_upstream_least_conn_module \
	--without-stream_upstream_zone_module 

STANDALONE_CFG_OPTS= --without-http-cache

MODSEC_CFG_OPTS= \
	--with-compat \
	--add-dynamic-module=../ModSecurity-nginx

DEBUG_CFG_OPTS= --with-debug


# Collections of build targets
#---------------------------------------------------------
LINUX_BASES = \
	linux-standalone-nomodsec-debug \
	linux-standalone-nomodsec-release \
	linux-cache-nomodsec-debug \
	linux-cache-nomodsec-release \
	linux-standalone-modsec-release

GRAPHENE_BASES = \
	graphene-standalone-nomodsec-debug \
	graphene-standalone-nomodsec-release \
	graphene-cache-nomodsec-debug \
	graphene-cache-nomodsec-release \
	graphene-standalone-modsec-release


# Base builds
#----------------------------------------------------------
bases-linux: $(LINUX_BASES)
bases-graphene: $(GRAPHENE_BASES)
bases-all: $(LINUX_BASES) $(GRAPHENE_BASES)

graphene-standalone-nomodsec-tls-only-release:
	(\
		set -e; \
		cd nginx-1.14.1-tls-only; \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(STANDALONE_CFG_OPTS); \
		make; \
		make install; \
	)


graphene-standalone-modsec-tls-only-release:
	(\
		set -e; \
		cd nginx-1.14.1-tls-only; \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(STANDALONE_CFG_OPTS) \
			$(MODSEC_CFG_OPTS); \
		make; \
		make install; \
	)


# Base Linux builds of NGINX
#----------------------------------------------------------
linux-standalone-nomodsec-debug:
	(\
		set -e; \
		cd $(NGINX); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(STANDALONE_CFG_OPTS) \
			$(DEBUG_CFG_OPTS); \
		make; \
		make install; \
	)

linux-standalone-nomodsec-release:
	(\
		set -e; \
		cd $(NGINX); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(STANDALONE_CFG_OPTS); \
		make; \
		make install; \
	)

linux-cache-nomodsec-debug:
	(\
		set -e; \
		cd $(NGINX); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(DEBUG_CFG_OPTS); \
		make; \
		make install; \
	)

linux-cache-nomodsec-release:
	(\
		set -e; \
		cd $(NGINX); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS); \
		make; \
		make install; \
	)

linux-standalone-modsec-release:
	(\
		set -e; \
		cd $(NGINX); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(STANDALONE_CFG_OPTS) \
			$(MODSEC_CFG_OPTS); \
		make; \
		make install; \
	)


# Base Graphene builds of NGINX
#----------------------------------------------------------
graphene-standalone-nomodsec-debug:
	(\
		set -e; \
		cd $(NGINX_GRAPHENE); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(STANDALONE_CFG_OPTS) \
			$(DEBUG_CFG_OPTS); \
		$(TOP)/patch/patch-ngx_auto_config.py objs/ngx_auto_config.h; \
		make; \
		make install; \
	)


graphene-standalone-nomodsec-release:
	(\
		set -e; \
		cd $(NGINX_GRAPHENE); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(STANDALONE_CFG_OPTS); \
		$(TOP)/patch/patch-ngx_auto_config.py objs/ngx_auto_config.h; \
		make; \
		make install; \
	)

graphene-cache-nomodsec-debug:
	(\
		set -e; \
		cd $(NGINX_GRAPHENE); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(DEBUG_CFG_OPTS); \
		$(TOP)/patch/patch-ngx_auto_config.py objs/ngx_auto_config.h; \
		make; \
		make install; \
	)

graphene-cache-nomodsec-release:
	(\
		set -e; \
		cd $(NGINX_GRAPHENE); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS); \
		$(TOP)/patch/patch-ngx_auto_config.py objs/ngx_auto_config.h; \
		make; \
		make install; \
	)

graphene-standalone-modsec-debug:
	(\
		set -e; \
		cd $(NGINX_GRAPHENE); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(STANDALONE_CFG_OPTS) \
			$(DEBUG_CFG_OPTS) \
			$(MODSEC_CFG_OPTS); \
		$(TOP)/patch/patch-ngx_auto_config.py objs/ngx_auto_config.h; \
		make; \
		make install; \
	)

graphene-standalone-modsec-release:
	(\
		set -e; \
		cd $(NGINX_GRAPHENE); \
		./configure \
			--prefix=$(TOP)/builds/$@ \
			$(COMMON_CFG_OPTS) \
			$(STANDALONE_CFG_OPTS) \
			$(MODSEC_CFG_OPTS); \
		$(TOP)/patch/patch-ngx_auto_config.py objs/ngx_auto_config.h; \
		make; \
		make install; \
	)


# Origin server packaged deployments (used for all deployments)
#----------------------------------------------------------
origin/linux-standalone-nomodsec-release_origin:
	mkdir -p pkg/$@
	cp -R config/mounts/nginx pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf
	cp builds/linux-standalone-nomodsec-release/sbin/nginx pkg/$@/nginx/sbin/



# Single-Tenant, Linux, caching-server packaged deployments
#----------------------------------------------------------
single-tenant/linux-cache-nomodsec-debug_nonsm \
single-tenant/linux-cache-nomodsec-debug_nsm:
	mkdir -p pkg/$@
	cp -R config/mounts/nginx pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf/
	cp builds/linux-cache-nomodsec-debug/sbin/nginx pkg/$@/nginx/sbin/

single-tenant/linux-cache-nomodsec-release_nonsm \
single-tenant/linux-cache-nomodsec-release_nsm:
	mkdir -p pkg/$@
	cp -R config/mounts/nginx pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf/
	cp builds/linux-cache-nomodsec-release/sbin/nginx pkg/$@/nginx/sbin/


# Single-Tenant, Graphene, caching-server packaged deployments
#----------------------------------------------------------
single-tenant/graphene-cache-nomodsec-debug_nextfs-smc-nonsm \
single-tenant/graphene-cache-nomodsec-debug_nextfs-smc-nsm \
single-tenant/graphene-cache-nomodsec-debug_nextfs-smdish-nonsm  \
single-tenant/graphene-cache-nomodsec-debug_nextfs-smdish-nsm \
single-tenant/graphene-cache-nomodsec-debug_nextfs-smuf-nonsm \
single-tenant/graphene-cache-nomodsec-debug_nextfs-smuf-nsm \
single-tenant/graphene-cache-nomodsec-debug_nonextfs-smc-nonsm \
single-tenant/graphene-cache-nomodsec-debug_nonextfs-smc-nsm \
single-tenant/graphene-cache-nomodsec-debug_nonextfs-smdish-nonsm \
single-tenant/graphene-cache-nomodsec-debug_nonextfs-smdish-nsm \
single-tenant/graphene-cache-nomodsec-debug_nonextfs-smuf-nonsm \
single-tenant/graphene-cache-nomodsec-debug_nonextfs-smuf-nsm \
single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nonsm \
single-tenant/graphene-cache-nomodsec-release_nextfs-smc-nsm \
single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nonsm \
single-tenant/graphene-cache-nomodsec-release_nextfs-smdish-nsm \
single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nonsm \
single-tenant/graphene-cache-nomodsec-release_nextfs-smuf-nsm \
single-tenant/graphene-cache-nomodsec-release_nonextfs-smc-nonsm \
single-tenant/graphene-cache-nomodsec-release_nonextfs-smc-nsm \
single-tenant/graphene-cache-nomodsec-release_nonextfs-smdish-nonsm \
single-tenant/graphene-cache-nomodsec-release_nonextfs-smdish-nsm \
single-tenant/graphene-cache-nomodsec-release_nonextfs-smuf-nonsm \
single-tenant/graphene-cache-nomodsec-release_nonextfs-smuf-nsm:
	mkdir -p pkg/$@
	cp -R config/mounts/* pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf
	$(MAKE_SGX) -t $(MAKEMANIFEST) -g $(GRAPHENE) -k $(ENCLAVE_KEY) \
		-p config/$@/manifest.conf -o pkg/$@ 
	mv pkg/$@/graphene-*manifest.sgx pkg/$@/nginx.manifest.sgx


# Multi-Tenant, Linux, "sharing-NGINX", caching-server packaged
# deployments
#
# The tenants are multiplexed on a single NGINX instance.
#---------------------------------------------------------------------------
multi-tenant/share-nginx/linux-cache-nomodsec-release_nonsm:
	mkdir -p pkg/$@
	(\
		set -e; \
		for i in 0 1 2 3 4 5; do \
			mkdir -p pkg/$@/$$i; \
			cp -R config/mounts/nginx pkg/$@/$$i; \
			cp config/$@/$$i/nginx.conf pkg/$@/$$i/nginx/conf/; \
			cp builds/linux-cache-nomodsec-release/sbin/nginx pkg/$@/$$i/nginx/sbin/; \
		done; \
	) 


# Multi-Tenant, Graphene, "sharing-NGINX", caching-server packaged
# deployments
#
# The tenants are multiplexed on a single NGINX instance.
#---------------------------------------------------------------------------
multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smdish-nsm \
multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smuf-nsm \
multi-tenant/share-nginx/graphene-cache-nomodsec-debug_nextfs-smc-nsm \
multi-tenant/share-nginx/graphene-cache-nomodsec-release_nextfs-smc-nsm:
	mkdir -p pkg/$@
	(\
		set -e; \
		for i in 0 1 2 3 4 5; do \
			mkdir -p pkg/$@/$$i; \
			cp -R config/mounts/* pkg/$@/$$i; \
			cp config/$@/$$i/nginx.conf pkg/$@/$$i/nginx/conf/; \
			$(MAKE_SGX) -t $(MAKEMANIFEST) -g $(GRAPHENE) -k $(ENCLAVE_KEY) \
				-p config/$@/$$i/manifest.conf -o pkg/$@/$$i; \
			mv pkg/$@/$$i/$$i.manifest.sgx pkg/$@/$$i/nginx.manifest.sgx; \
		done; \
	) 


# Multi-Tenant, Graphene, "sharing-nothing", caching-server packaged
# deployments
#
# Each tenant has their own NGINX instance.
#---------------------------------------------------------------------------
multi-tenant/share-nothing/graphene-cache-nomodsec-release_nextfs-smdish-nsm \
multi-tenant/share-nothing/graphene-cache-nomodsec-release_nextfs-smuf-nsm \
multi-tenant/share-nothing/graphene-cache-nomodsec-release_nextfs-smc-nsm:
	mkdir -p pkg/$@
	(\
		set -e; \
		for i in 0 1 2 3 4 5; do \
			mkdir -p pkg/$@/$$i; \
			cp -R config/mounts/* pkg/$@/$$i; \
			cp config/$@/$$i/nginx.conf pkg/$@/$$i/nginx/conf/; \
			$(MAKE_SGX) -t $(MAKEMANIFEST) -g $(GRAPHENE) -k $(ENCLAVE_KEY) \
				-p config/$@/$$i/manifest.conf -o pkg/$@/$$i; \
			mv pkg/$@/$$i/$$i.manifest.sgx pkg/$@/$$i/nginx.manifest.sgx; \
		done; \
	)


# WAF: Standalone Linux packaged deployment
#--------------------------------------------------------------------
standalone/linux-standalone-modsec-release_nonsm:
	mkdir -p pkg/$@
	cp -R config/mounts/nginx pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf/
	cp builds/linux-standalone-modsec-release/sbin/nginx pkg/$@/nginx/sbin/
	cp builds/linux-standalone-modsec-release/modules/ngx_http_modsecurity_module.so \
		pkg/$@/nginx/modules/



# WAF: Standalone Graphene packaged deployments
#--------------------------------------------------------------------
standalone/graphene-standalone-modsec-release_nextfs-smc-nonsm \
standalone/graphene-standalone-modsec-release_nextfs-smc-nsm:
	mkdir -p pkg/$@
	cp -R config/mounts/* pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf/
	cp builds/graphene-standalone-modsec-release/modules/ngx_http_modsecurity_module.so \
		pkg/$@/nginx/modules/
	$(MAKE_SGX) -t $(MAKEMANIFEST) -g $(GRAPHENE) -k $(ENCLAVE_KEY) \
		-p config/$@/manifest.conf -o pkg/$@ 
	mv pkg/$@/graphene-*manifest.sgx pkg/$@/nginx.manifest.sgx





standalone/graphene-standalone-modsec-debug_nextfs-smc-nonsm:
	mkdir -p pkg/$@
	cp -R config/mounts/* pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf/
	cp builds/graphene-standalone-modsec-debug/modules/ngx_http_modsecurity_module.so \
		pkg/$@/nginx/modules/
	$(MAKE_SGX) -t $(MAKEMANIFEST) -g $(GRAPHENE) -k $(ENCLAVE_KEY) \
		-p config/$@/manifest.conf -o pkg/$@ 

standalone/graphene-standalone-modsec-tls-only-release_nonextfs-nosm-nonsm:
	mkdir -p pkg/$@
	cp -R config/mounts/* pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf/
	cp builds/graphene-standalone-modsec-tls-only-release/modules/ngx_http_modsecurity_module.so \
		pkg/$@/nginx/modules/
	$(MAKE_SGX) -t $(MAKEMANIFEST) -g $(GRAPHENE) -k $(ENCLAVE_KEY) \
		-p config/$@/manifest.conf -o pkg/$@ 


# Single-Tenant NGINX server packaged deployments
#----------------------------------------------------------
standalone/graphene-standalone-nomodsec-release_nextfs-nsm:
	mkdir -p pkg/$@
	cp -R config/mounts/* pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf
	$(MAKE_SGX) -t $(MAKEMANIFEST) -g $(GRAPHENE) -k $(ENCLAVE_KEY) \
		-p config/$@/manifest.conf -o pkg/$@ 


