#!/bin/bash

export LC_ALL=C

sudo apt install net-tools jq

echo 0 | sudo tee /proc/sys/net/ipv4/tcp_sack

echo "======= DOCKER START ======="
./do-docker.sh "./download-docker.sh 2"
echo "======= DOCKER END ======="

echo "======= CHROOT START ======="
./do-chroot.sh "./download-docker.sh 2"
echo "======= CHROOT END ======="

echo "======= netstat -i ======="
netstat -i

echo "======= netstat -s ======="
netstat -s

echo "======= ip l ======="
ip l

echo "======= ip a ======="
ip a

echo "======= ip r ======="
ip r

sysctl -a > sysctl.out
