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

sudo chroot /tmp/xenial/chroot-autobuild bash -c "cd `pwd`; $1"
