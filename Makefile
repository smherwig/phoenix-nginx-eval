# LOCATIONS
#---------------------------------------------------------
TOP=$(PWD)
NGINX= nginx-1.14.1
NGINX_GRAPHENE= nginx-1.14.1-graphene
GRAPHENE=/home/smherwig/ws/phoenix


# TOOLS
#---------------------------------------------------------
MAKE_SGX=/home/smherwig/phoenix/makemanifest/make_sgx.py


# NGINX configure options
#---------------------------------------------------------
COMMON_CFG_OPTS= \
	--with-http_ssl_module \
    --without-http_upstream_hash_module \
    --without-http_upstream_ip_hash_module \
    --without-http_upstream_least_conn_module \
    --without-http_upstream_keepalive_module \
    --without-http_upstream_zone_module

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
	linux-cache-nomodsec-release

GRAPHENE_BASES = \
	graphene-standalone-nomodsec-debug \
	graphene-standalone-nomodsec-release \
	graphene-cache-nomodsec-debug \
	graphene-cache-nomodsec-release


# Base builds
#----------------------------------------------------------
bases-linux: $(LINUX_BASES)
bases-graphene: $(GRAPHENE_BASES)
bases-all: $(LINUX_BASES) $(GRAPHENE_BASES)

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


# Origin server packaged deployments (used for all deployments)
#----------------------------------------------------------
origin/linux-standalone-nomodsec-release_origin:
	mkdir -p pkg/$@
	cp -R config/mounts/nginx pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf
	cp builds/linux-standalone-nomodsec-release/sbin/nginx pkg/$@/nginx/sbin/


# Single-Tenant Linux caching-server packaged deployments
#----------------------------------------------------------
single-tenant/linux-cache-nomodsec-debug_nonsm \
single-tenant/linux-cache-nomodsec-debug_nsm:
	mkdir -p pkg/$@
	cp -R config/mounts/nginx pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf
	cp builds/linux-cache-nomodsec-debug/sbin/nginx pkg/$@/nginx/sbin/

single-tenant/linux-cache-nomodsec-release_nonsm \
single-tenant/linux-cache-nomodsec-release_nsm:
	mkdir -p pkg/$@
	cp -R config/mounts/nginx pkg/$@
	cp config/$@/nginx.conf pkg/$@/nginx/conf
	cp builds/linux-cache-nomodsec-release/sbin/nginx pkg/$@/nginx/sbin/


# Single-Tenant NGINX caching-server packaged deployments
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
	$(MAKE_SGX) -t /home/smherwig/phoenix/makemanifest -g $(GRAPHENE) \
		-k config/enclave_signing.key \
		-p config/$@/manifest.conf -o pkg/$@ 
