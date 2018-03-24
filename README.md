PS C:\Users\ehiller\dev\samba_docker> .\docker.exe --host tcp://nas:2376 --tlsverify --tlscacert .\cert\ca.pem  --tlscert .\cert\cert.pem --tlskey .\cert\key.pem network ls
NETWORK ID          NAME                DRIVER              SCOPE
17978ce78f7c        bridge              bridge              local
34d028744153        bridgemac           macvlan             local
7bb088558cd4        host                host                local
245658a1df12        none                null                local



.\docker.exe --host tcp://nas:2376 --tlsverify --tlscacert .\cert\ca.pem  --tlscert .\cert\cert.pem --tlskey .\cert\key.pem run -e`"DOMAIN=$($Domain.toupper())" -e "DOMAINPASS=$AdminPassword" -e "DNSFORWARDER=$DNSForwarder" -p  53:53 -p  53:53/udp -p  88:88 -p  88:88/udp -p  135:135 -p  137-138:137-138/udp -p  139:139 -p  389:389 -p  389:389/udp -p  445:445 -p  464:464 -p  464:464/udp -p  636:636 -p  1024-1044:1024-1044 -p  3268-3269:3268-3269 -v /etc/localtime:/etc/localtime:ro -v /data/docker/containers/samba/data/:/var/lib/samba -v /data/docker/containers/samba/config/samba:/etc/samba/external --dns-search $Domain.ToLower() --dns $DNSForwarder --hostname $Hostname.tolower() --env-file env.sh --tty --interactive --privileged --mac-addr "00:0c:02:7c:9a:44" --network "bridgemac" --name=samba-adc erichiller/samba-adc-image