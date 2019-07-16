#!/bin/bash

/etc/init.d/tor restart

while :
do

/usr/bin/proxychains /usr/bin/stubby
sleep 0.1
done

