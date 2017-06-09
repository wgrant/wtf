#!/bin/bash

apt update >> /dev/null && apt install -y curl jq mtr tcpdump >> /dev/null

ATTEMPTS=${1:-10}
echo "Trying $ATTEMPTS core snap download(s) ..."

nohup tcpdump -fnv -w resets.pcap dst port 443 and 'tcp[tcpflags] & (tcp-rst) != 0' \
  > tcpdump.out 2>&1 & echo $! > tcpdump.pid

for i in `seq $ATTEMPTS`;
do curl -w '%{http_code}: %{url_effective} %{size_download} %{time_total}s\n' -LsS \
  $(curl -s -H 'X-Ubuntu-Series: 16' https://search.apps.ubuntu.com/api/v1/snaps/details/core | jq '.anon_download_url' -r) -o /dev/null;
done

kill `cat tcpdump.pid`

echo "=RESETS======================================================"
cat resets.pcap
echo "=/RESETS====================================================="
echo
echo "mtr to internap, ipv4"
mtr -rbw4 068ed04f23.site.internapcdn.net
#echo "mtr to internap, ipv6"
#mtr -rbw6 068ed04f23.site.internapcdn.net
