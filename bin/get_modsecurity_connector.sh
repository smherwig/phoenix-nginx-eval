#!/bin/bash

# Download and ModSecurity-Nginx connector.
#
# (The connector is specified in NGINX's configure command and compiled as part
# of the NGINX compilation.)
#
git clone --depth 1 \
    https://github.com/SpiderLabs/ModSecurity-nginx.git
