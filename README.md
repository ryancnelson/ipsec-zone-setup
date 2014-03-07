ipsec-zone-setup
================

setup scripts for ipsec + L4-in-L4 tunnels between SmartOS zones



example procedure:

- provision 256mb base64 vm in east , b47b5abc-38c6-40d7-892b-f0f7650e837f :
     vpn server
     165.225.137.251    10.112.5.32
     on CN 3038HS1, 10.0.128.80


- provision 256mb base64 vm in ams, fad97b17-d161-413e-81be-d815dd0a1dc6 :
     vpn server
     37.153.104.15      10.224.6.146 
     on CN HJ9H95J , 10.1.0.82


- provision 256mb base64 vm in east, 076d58e6-e890-4c82-8f9f-f58ac2619fbf
     client
     165.225.139.239      10.112.75.248

- provision 256mb base64 vm in ams, b58868be-8e3a-41de-8feb-605c5e558a8d
     client
     37.153.104.5 10.224.6.115 

- add /etc/hosts entries to make working easier:
165.225.137.251 eastvpn
37.153.104.15      amsvpn
165.225.139.239 eastclient
37.153.104.5      amsclient

- enable IP spoofing on eastvpn:
     # log into CN
    sdc-zone-net-attr  b47b5abc-38c6-40d7-892b-f0f7650e837f net0 allow_ip_spoofing 1
    sdc-zone-net-attr  b47b5abc-38c6-40d7-892b-f0f7650e837f net1 allow_ip_spoofing 1
    zoneadm -z b47b5abc-38c6-40d7-892b-f0f7650e837f halt
    zoneadm -z b47b5abc-38c6-40d7-892b-f0f7650e837f boot
     ## test it:
    dladm show-linkprop -z b47b5abc-38c6-40d7-892b-f0f7650e837f -p protection net0
    dladm show-linkprop -z b47b5abc-38c6-40d7-892b-f0f7650e837f -p protection net1

- enable IP spoofing on amsvpn:
     # log into CN
    sdc-zone-net-attr fad97b17-d161-413e-81be-d815dd0a1dc6 net0 allow_ip_spoofing 1
    sdc-zone-net-attr fad97b17-d161-413e-81be-d815dd0a1dc6 net1 allow_ip_spoofing 1
    export TERM=vt100
    zoneadm -z fad97b17-d161-413e-81be-d815dd0a1dc6 halt
    zoneadm -z fad97b17-d161-413e-81be-d815dd0a1dc6 boot
     # test it
    dladm show-linkprop -z fad97b17-d161-413e-81be-d815dd0a1dc6 -p protection net0
   dladm show-linkprop -z fad97b17-d161-413e-81be-d815dd0a1dc6 -p protection net1

- install apache on each vpn host (service to test)
     pkgin install apache
     svcadm enable apache

XXX don't enable ipv4 forwarding yet.

- generate a 40-bit key:
     head /dev/random | od -t x1 | perl -pe 's/.*? // ; s/ //g ; chomp ' | dd bs=40 count=1 2>/dev/null ; echo
     results in  ==>   e1e721333c1c6c19891beb9a03eb509f54644ee0

- on east vpn server:
     export PUBIP=165.225.137.251
     export PRIVIP=10.112.5.32
   \# this is the pub ip of the other vpn server:
       export DSTIP=37.153.104.15   
     export MYKEY=e1e721333c1c6c19891beb9a03eb509f54644ee0


- on ams vpn server:
     export PUBIP=37.153.104.15
     export PRIVIP=10.224.6.146 
   
   \# this is the pub ip of the other vpn server:  
       export DSTIP=165.225.137.251
     export MYKEY=e1e721333c1c6c19891beb9a03eb509f54644ee0


- on each vpn server:
echo "add esp spi 1000 src $PUBIP  dst $DSTIP auth_alg sha1 authkey $MYKEY encr_alg blowfish encrkey $MYKEY" > /etc/inet/secret/ipseckeys

echo "add esp spi 1000 src $DSTIP  dst $PUBIP auth_alg sha1 authkey $MYKEY encr_alg blowfish encrkey $MYKEY" >> /etc/inet/secret/ipseckeys

 -  chmod 600 /etc/inet/secret/ipseckeys 
 -  ipseckey flush
 -  ipseckey -f /etc/inet/secret/ipseckeys


- on each server:

 echo "{ lport 22 dir both } bypass { } " > /etc/inet/ipsecinit.conf
 echo "{ raddr $DSTIP } ipsec { encr_algs blowfish encr_auth_algs sha1 sa shared } " >> /etc/inet/ipsecinit.conf

svcadm enable ipsec/policy
svcadm restart ipsec/policy

### test it:
ipsecconf

### output here:
     #INDEX 4
     { lport 22 dir both } bypass { }

     #INDEX 6
     { raddr 165.225.137.251 } ipsec { encr_algs blowfish encr_auth_algs sha1 sa shared }

- on amsvpn , run snoop:
snoop -v -d net0 not port 22 and not host vrrp.mcast.net and not port 53

- on eastvpn, hit amsvpn with curl:
curl -v -si http://$DSTIP

... that should work, and you should see encrypted traffic on the snoop output:
...
IP:   Destination address = 37.153.104.15, 37.153.104.15
IP:   No options
IP:  
ESP:  ----- Encapsulating Security Payload -----
ESP: 
ESP:  SPI = 0x3e8
ESP:  Replay = 53
ESP:     ....ENCRYPTED DATA....
..

------
now, traffic between the hosts is encrypted.  let's build tunnels:

- on each vpn server:
git clone https://github.com/ryancnelson/ipsec-zone-setup
cd ipsec-zone-setup

- on amsterdam (the east-most server)
./tunnel-east-setup.sh

- on east (the west-most server)
./tunnel-west-setup.sh

- on both servers, run "ifconfig -a" , and see that tunnels are set up 
- on both servers, ping 100.100.44.1 and 100.100.44.2, to confirm you can ping both ends of the tunnel.
- on both servers, confirm traffic is running locally, and across the tunnel by running:
      curl -si -vv http://100.100.44.1
      curl -si -vv http://100.100.44.2



