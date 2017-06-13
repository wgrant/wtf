#!/bin/bash

apt update >> /dev/null && apt install -y curl jq mtr tcpdump python3-pip traceroute bind9-host wget >> /dev/null
python3 -m pip install -r requirements.txt

echo "internap dns:"
host 068ed04f23.site.internapcdn.net

ATTEMPTS=${1:-10}
echo "Trying $ATTEMPTS core snap download(s) ..."

nohup tcpdump -fnv -w resets.pcap dst port 443 and 'tcp[tcpflags] & (tcp-rst) != 0' \
  > tcpdump.out 2>&1 & echo $! > tcpdump.pid

for i in `seq $ATTEMPTS`;
#do python3 download.py
do echo -e "\n>>>>>>>>>>>>>> Get URL From Store"
   sURL=$(curl -s -H 'X-Ubuntu-Series: 16' https://search.apps.ubuntu.com/api/v1/snaps/details/core | jq '.anon_download_url' -r)
   echo -e "$sURL"
   echo -e "Get redirect to CDN"

   # murder all the kittens
   cURL=$(wget --max-redirect=0 -S -O /dev/null $sURL 2>&1 | grep 'Location:' | grep -v 'following' | cut -c 13-)
   echo -e "\nGot: $cURL"
    echo -e "\n>>>>>>>>>>>>>> CURL it"
    curl -w '%{http_code}: %{url_effective} %{size_download} %{time_total}s\n' -LsS -D - -o /dev/null "$cURL"
    echo -e "\n>>>>>>>>>>>>>> Python Stream it"
    python3 rt_stream.py $cURL
    
    URL_local="$sURL?cdn=local"
    echo -e "\n>>>>>>>>>>>>>> Next try cdn=local $URL_local"
    echo -e "\n>>>>>>>>>>>>>> CURL it"
    curl -w '%{http_code}: %{url_effective} %{size_download} %{time_total}s\n' -LsS -D - -o /dev/null $URL_local
    echo -e "\n>>>>>>>>>>>>>> Python Stream it"
    python3 rt_stream.py $URL_local

    #cURL2=${cURL//068ed04f23/f081088235}
    cURL2="https://f081088235.site.internapcdn.net/download-snap/99T7MUlRhtI3U0QFgl5mXXESAiSwt776_1689.snap?t=2017-09-02T04:15:00Z&h=2F7D1B11A02D6965D2F0352D2EA73F779AE45ECB"
    echo -e "\n>>>>>>>>>>>>>> Now use our other CDN test URL $cURL2"
    echo -e "\n>>>>>>>>>>>>>> CURL IT"
    curl -w '%{http_code}: %{url_effective} %{size_download} %{time_total}s\n' -LsS -D - -o /dev/null $cURL2
    echo -e "\n>>>>>>>>>>>>>> Python Stream it"
    python3 rt_stream.py $cURL2

    #ls -lh core*.snap
    rm *.snap
    #echo -e "sleeping 5"
    #sleep 5
    echo -e ">>>>>>>>>>>>>>>> RUN $i done <<<<<<<<<<<<<<<<<<<<<"
done

kill `cat tcpdump.pid`

echo -e "=RESETS======================================================"
cat resets.pcap
echo -e "=/RESETS====================================================="
echo -e

#echo -e "mtr to internap, ipv4"
#mtr -rbw4 068ed04f23.site.internapcdn.net
#echo -e "mtr to internap, ipv6"
#mtr -rbw6 068ed04f23.site.internapcdn.net

#echo -e "traceroutes to all IPs"
#for i in `host 068ed04f23.site.internapcdn.net | cut -d ' ' -f 4`; do traceroute $i;  done
