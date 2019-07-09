#!/bin/bash

# Throughput is the mean throughput, measured in requests per seconds
# Latency is the mean latency, measure in milliseconds

REQUESTS=1000
CONCURRENCY=8

URL=$1
RESULT=$2
OUTPUT= tmp.$RESULT

rm -f $OUTPUT

echo "ab -n $REQUESTS -c $CONCURRENCY $URL"
ab -n $REQUESTS -c $CONCURRENCY $URL >> $OUTPUT
THROUGHPUT=$(grep -m1 "Requests per second:" $OUTPUT | awk '{ print $4 }')
LATENCY=$(grep -m1 "Time per request:" $OUTPUT | awk '{ print $4 }')
printf "$THROUGHPUT $LATENCY\n" >> $RESULT

rm -f $OUTPUT
