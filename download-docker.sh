#!/bin/bash

apt update >> /dev/null && apt install -y curl jq mtr tcpdump python3-pip traceroute bind9-host wget python3-dev libssl-dev libcurl4-openssl-dev net-tools >> /dev/null
python3 -m pip install -r requirements.txt

echo "internap dns:"
host 068ed04f23.site.internapcdn.net

ATTEMPTS=${1:-3}
echo "Trying $ATTEMPTS core snap download(s) ..."

nohup tcpdump -fnv -w tcpdump-resets.pcap src port 443 and 'tcp[tcpflags] & (tcp-rst) != 0' \
  > tcpdump-resets.out 2>&1 & echo $! > tcpdump-resets.pid

nohup tcpdump -w tcpdump-all.pcap -s 1024 port 443 \
  > tcpdump-all.out 2>&1 & echo $! > tcpdump-all.pid

for i in `seq $ATTEMPTS`;
#do python3 download.py
do echo -e "\n>>>>>>>>>>>>>> Get URL From Store"
   sURL=$(curl -s -H 'X-Ubuntu-Series: 16' https://search.apps.ubuntu.com/api/v1/snaps/details/core | jq '.anon_download_url' -r)
   echo -e "$sURL"
   echo -e "Get redirect to CDN"

   # murder all the kittens
   cURL=$(wget --max-redirect=0 -S -O /dev/null $sURL 2>&1 | grep 'Location:' | grep -v 'following' | cut -c 13-)
   echo -e "\nGot: $cURL"
    #echo -e "\n>>>>>>>>>>>>>> CURL it"
    #curl -vA "wtf" -w '%{http_code}: %{url_effective} %{size_download} %{time_total}s\n' -LsS -D - -o /dev/null "$cURL"
    echo -e "\n>>>>>>>>>>>>>> Python Stream it"
    python3 rt_stream.py $cURL
    rm *.snap

    sURL_local="$sURL?cdn=local"
    echo -e "\n>>>>>>>>>>>>>> Next try cdn=local $sURL_local"
    URL_local=$(wget --max-redirect=0 -S -O /dev/null $sURL_local 2>&1 | grep 'Location:' | grep -v 'following' | cut -c 13-)
    echo -e "\nGot: $URL_local"
    #echo -e "\n>>>>>>>>>>>>>> CURL it"
    #curl -vA "wtf" -w '%{http_code}: %{url_effective} %{size_download} %{time_total}s\n' -LsS -D - -o /dev/null $URL_local
    echo -e "\n>>>>>>>>>>>>>> Python Stream it"
    python3 rt_stream.py $URL_local
    rm *.snap

    cURL2="https://f081088235.site.internapcdn.net/download-snap/99T7MUlRhtI3U0QFgl5mXXESAiSwt776_1689.snap?t=2017-09-02T04:15:00Z&h=2F7D1B11A0#2D6965D2F0352D2EA73F779AE45ECB"
    #cURL2="http://f081088235.site.internapcdn.net/download-snap/99T7MUlRhtI3U0QFgl5mXXESAiSwt776_1689.snap?t=2017-09-02T04:00:00Z&h=CB4A03C5B64242CDC442B50069CB0421F491F7A1"
    echo -e "\n>>>>>>>>>>>>>> Now use our other CDN test URL $cURL2"
    #echo -e "\n>>>>>>>>>>>>>> CURL IT"
    #curl -vA "wtf" -w '%{http_code}: %{url_effective} %{size_download} %{time_total}s\n' -LsS -D - -o /dev/null $cURL2
    echo -e "\n>>>>>>>>>>>>>> Python Stream it"
    python3 rt_stream.py $cURL2
    rm *.snap
    
    cURL3="https://f081088235.site.internapcdn.net/abr/core.snap"
    echo -e "\n>>>>>>>>>>>>>> Now CDN to ABR test URL $cURL3"
    echo -e "\n>>>>>>>>>>>>>> Python Stream it"
    python3 rt_stream.py $cURL3
    rm *.snap
    
    cURL4="https://abitrandom.net/core.snap"
    echo -e "\n>>>>>>>>>>>>>> Now direct to ABR test URL $cURL4"
    echo -e "\n>>>>>>>>>>>>>> Python Stream it"
    python3 rt_stream.py $cURL4
    
    #ls -lh core*.snap
    rm *.snap
    #echo -e "sleeping 5"
    #sleep 5
    echo -e ">>>>>>>>>>>>>>>> RUN $i done <<<<<<<<<<<<<<<<<<<<<"
done

kill `cat tcpdump-resets.pid`
kill `cat tcpdump-all.pid`

echo -e "=RESETS======================================================"
cat tcpdump-resets.pcap
echo -e "=/RESETS====================================================="
echo -e

netstat -s

#echo -e "mtr to internap, ipv4"
#mtr -rbw4 068ed04f23.site.internapcdn.net
#echo -e "mtr to internap, ipv6"
#mtr -rbw6 068ed04f23.site.internapcdn.net

#echo -e "traceroutes to all IPs"
#for i in `host 068ed04f23.site.internapcdn.net | cut -d ' ' -f 4`; do traceroute $i;  done
