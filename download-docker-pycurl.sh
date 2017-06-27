#!/bin/bash

apt update >> /dev/null && apt install -y curl jq mtr tcpdump python3-pip traceroute bind9-host wget python3-dev libssl-dev libcurl4-openssl-dev >> /dev/null
python3 -m pip install -r requirements.txt

echo "internap dns:"
host 068ed04f23.site.internapcdn.net

ATTEMPTS=${1:-10}
echo "Trying $ATTEMPTS core snap download(s) ..."

nohup tcpdump -fnv -w resets.pcap dst port 443 and 'tcp[tcpflags] & (tcp-rst) != 0' \
  > tcpdump.out 2>&1 & echo $! > tcpdump.pid

for i in `seq $ATTEMPTS`;
do echo -e "\n>>>>>>>>>>>>>> Kickoff pycurl run"
    python3 retriever.py urls.txt 1
    ls -l *.dat
    rm *.dat
    echo -e ">>>>>>>>>>>>>>>> RUN $i done <<<<<<<<<<<<<<<<<<<<<"
done

kill `cat tcpdump.pid`

echo -e "=RESETS======================================================"
cat resets.pcap
echo -e "=/RESETS====================================================="
echo -e
