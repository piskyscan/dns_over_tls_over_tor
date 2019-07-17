#!/bin/bash

/etc/init.d/tor start

while :
do

/usr/bin/proxychains /usr/bin/stubby
sleep 0.1
done

