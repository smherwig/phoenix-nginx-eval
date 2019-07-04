# LOCATIONS
#---------------------------------------------------------
TOP=$(PWD)
NGINX= nginx-1.14.1
NGINX_GRAPHENE= nginx-1.14.1-graphene

# builds/   deploy/

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
GRAPHENE_BASES = \
	graphene-standalone-nomodsec-debug \
	graphene-standalone-nomodsec-release \
	graphene-cache-nomodsec-debug \
	graphene-cache-nomodsec-release


# Base Graphene builds of NGINX
#----------------------------------------------------------
graphene_bases: $(GRAPHENE_BASES)

graphene-standalone-nomodsec-debug:
	(\
		set -e; \
		cd $(NGINX_GRAPHENE); \
		./configure \
			--prefix=$(TOP)/builds/$@/nginx \
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
			--prefix=$(TOP)/builds/$@/nginx \
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
			--prefix=$(TOP)/builds/$@/nginx \
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
			--prefix=$(TOP)/builds/$@/nginx \
			$(COMMON_CFG_OPTS); \
		$(TOP)/patch/patch-ngx_auto_config.py objs/ngx_auto_config.h; \
		make; \
		make install; \
	)


# Base vanilla deploys of NGINX
#----------------------------------------------------------
#linux-origin-debug:
#	(\
#		set -e; \
#		cd $(NGINX); \
#		./configure \
#			--prefix=$(TOP)/builds/$@/nginx \
#			$(COMMON_CFG_OPTS) \
#			$(STANDALONE_CFG_OPTS) \
#			$(DEBUG_CFG_OPTS); \
#		make; \
#		make install; \
#	)
#	cp etc/$@/nginx.conf builds/$@/nginx/conf
#	cp -R etc/html/* builds/$@/nginx/html
#
#
#linux-standalone-nomodsec-debug:
#	(\
#		set -e; \
#		cd $(NGINX); \
#		./configure \
#			--prefix=$(TOP)/builds/$@/nginx \
#			$(COMMON_CFG_OPTS) \
#			$(STANDALONE_CFG_OPTS) \
#			$(DEBUG_CFG_OPTS); \
#		make; \
#		make install; \
#	)
#	cp etc/$@/nginx.conf builds/$@/nginx/conf
#	cp etc/common/server.key builds/$@/nginx/conf
#	cp etc/common/server.crt builds/$@/nginx/conf
#	cp -R etc/html/* builds/$@/nginx/html
#
#
#linux-standalone-nomodsec-release:
#	(\
#		set -e; \
#		cd $(NGINX); \
#		./configure \
#			--prefix=$(TOP)/builds/$@/nginx \
#			$(COMMON_CFG_OPTS) \
#			$(STANDALONE_CFG_OPTS) \
#		make; \
#		make install; \
#	)
#	cp etc/$@/nginx.conf builds/$@/nginx/conf
#	cp etc/common/server.key builds/$@/nginx/conf
#	cp etc/common/server.crt builds/$@/nginx/conf
#	cp -R etc/html/* builds/$@/nginx/html
#

#graphene-cache-nomodsec-release-bdverity-smdish


