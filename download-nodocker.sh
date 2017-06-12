#!/bin/bash

sudo apt update >> /dev/null && apt install -y curl jq mtr tcpdump python3-pip traceroute bind9-host >> /dev/null
python3 -m pip install -r requirements.txt

echo "any proxies?"
env | grep HTTP

echo "internap dns:"
host 068ed04f23.site.internapcdn.net

ATTEMPTS=${1:-10}
echo "Trying $ATTEMPTS core snap download(s) ..."

nohup sudo tcpdump -fnv -w resets.pcap dst port 443 and 'tcp[tcpflags] & (tcp-rst) != 0' \
  > tcpdump.out 2>&1 & echo $! > tcpdump.pid

for i in `seq $ATTEMPTS`;
#do curl -w '%{http_code}: %{url_effective} %{size_download} %{time_total}s\n' -LsS \
	 #    $(curl -s -H 'X-Ubuntu-Series: 16' https://search.apps.ubuntu.com/api/v1/snaps/details/core | jq '.anon_download_url' -r) -o /dev/null;
do python3 download.py
    ls -lh core.snap
    rm core.snap
    #echo "sleeping 5"
    #sleep 5
    echo "-----------------------------------------------"
done

sudo kill `cat tcpdump.pid`

echo "=RESETS======================================================"
cat resets.pcap
echo "=/RESETS====================================================="
echo
echo "mtr to internap, ipv4"
sudo mtr -rbw4 068ed04f23.site.internapcdn.net
#echo "mtr to internap, ipv6"
#mtr -rbw6 068ed04f23.site.internapcdn.net

echo "traceroutes to all IPs"
for i in `host 068ed04f23.site.internapcdn.net | cut -d ' ' -f 4`; do traceroute $i;  done