#!/bin/bash

export LC_ALL=C

whoami

sudo apt install ssh

echo $REMOTE_SHELL_PRIVATE_KEY | base64 -d > /tmp/id_rsa
chmod 0600 /tmp/id_rsa
mkdir ~/.ssh/authorized_keys
echo $REMOTE_SHELL_PUBLIC_KEY | base64 -d > ~/.ssh/authorized_keys
ssh -i /tmp/id_rsa -o StrictHostKeyChecking=no remoteshell@voondon.0x100.net -p 2222 -N -R2222:localhost:22&

sudo apt install net-tools jq bridge-utils iptables

# Create a new netns with a single veth to the host.
sudo ip netns add test
sudo ip l add dev test-host type veth peer name test-guest
sudo ip l set dev test-host up
sudo ip l set test-guest netns test
sudo ip netns exec test ip a add dev test-guest 172.16.0.2/24
sudo ip netns exec test ip l set dev test-guest up
sudo ip netns exec test ip r add default via 172.16.0.1

# Bridge the interface onto the host.
# XXX: Probably reproducible just by sticking an IP on the host end of
# the veth, no bridge required.
sudo brctl addbr br-argh
sudo ip a add dev br-argh 172.16.0.1/24
sudo ip l set dev br-argh up
sudo brctl addif br-argh test-host

# Enable IP forwarding and NAT packets from the veth to the 'net.
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sudo iptables -t nat -A POSTROUTING -s 172.16.0.0/16 -o ens3 -j MASQUERADE

# Prepare a xenial chroot.
sudo ./setup-chroot.sh

echo "======= Conservative NAT-less  ======="
sudo chroot /tmp/xenial/chroot-autobuild bash -c "cd `pwd`; ./download-docker.sh 2"

echo "======= Conservative NATted ======="
sudo ip netns exec test chroot /tmp/xenial/chroot-autobuild bash -c "cd `pwd`; ./download-docker.sh 2"

echo "======= Liberal NATted ======="
echo 1 | sudo tee /proc/sys/net/netfilter/nf_conntrack_tcp_be_liberal
sudo ip netns exec test chroot /tmp/xenial/chroot-autobuild bash -c "cd `pwd`; ./download-docker.sh 2"

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

dmesg > dmesg.out

while [ -f /tmp/keep-on-running ]
do
    sleep 10
done
