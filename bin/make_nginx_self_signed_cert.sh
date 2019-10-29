#!/bin/bash

# I typically use 'localhost' as the CN.
# I don't provide an e-mail address.

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout server.key -out server.crt -days 365
