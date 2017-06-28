#!/bin/bash

export LC_ALL=C

sudo apt install net-tools jq bridge-utils iptables

echo 0 | sudo tee /proc/sys/net/ipv4/tcp_sack
echo 16777216 | sudo tee /proc/sys/net/core/rmem_default
echo 16777216 | sudo tee /proc/sys/net/core/rmem_max
echo "16777216 16777216 16777216" | sudo tee /proc/sys/net/ipv4/tcp_mem
echo "16777216 16777216 16777216" | sudo tee /proc/sys/net/ipv4/tcp_rmem

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

echo "======= brctl show ======="
sudo brctl show

docker network ls

sudo iptables -L -vn
sudo iptables -L -t nat -vn
sudo iptables -L -t mangle -vn

sudo sysctl -a > sysctl.out
