#!/bin/bash

export LC_ALL=C

sudo apt install net-tools jq

echo 0 | sudo tee /proc/sys/net/ipv4/tcp_sack

echo "======= DOCKER START ======="

docker run -v `pwd`:`pwd` -w `pwd` ubuntu:xenial ./download-docker.sh 2

echo "======= DOCKER END ======="


echo "Acquiring Launchpad xenial/amd64 chroot."
XENIAL_CHROOT_URL=`curl -s https://api.launchpad.net/devel/ubuntu/xenial/amd64/chroot_url | jq . -r`
wget -O /tmp/xenial.tar.gz $XENIAL_CHROOT_URL
mkdir /tmp/xenial
pushd /tmp/xenial
sudo tar xf /tmp/xenial.tar.gz
sudo cp /etc/resolv.conf chroot-autobuild/etc/resolv.conf
echo "deb http://archive.ubuntu.com/ubuntu xenial main universe" | sudo tee chroot-autobuild/etc/apt/sources.list
popd

sudo mkdir -p /tmp/xenial/chroot-autobuild/`pwd`
sudo mount --bind `pwd` /tmp/xenial/chroot-autobuild/`pwd`
sudo mount --bind /proc /tmp/xenial/chroot-autobuild/proc
sudo mount --bind /sys /tmp/xenial/chroot-autobuild/sys
sudo mount --bind /dev /tmp/xenial/chroot-autobuild/dev
sudo chroot /tmp/xenial/chroot-autobuild apt update

echo "======= CHROOT START ======"
sudo chroot /tmp/xenial/chroot-autobuild bash -c "cd `pwd`; ./download-docker.sh 2"
echo "======= CHROOT END ======"


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
