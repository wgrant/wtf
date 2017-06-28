#!/bin/bash

sudo apt install net-tools

echo 0 | sudo tee /proc/sys/net/ipv4/tcp_sack

echo "======= DOCKER START ======="

docker run -v `pwd`:`pwd` -w `pwd` ubuntu:xenial ./download-docker.sh 2

echo "======= DOCKER END ======="

echo "======= netstat -i ======="
netstat -i

echo "======= netstat -s ======="
netstat -s
