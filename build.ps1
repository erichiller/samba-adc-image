

# get authorized keys
( & (Join-Path (Split-Path (Split-Path (where.exe git) -Parent) -Parent) "usr\bin\ssh-add.exe") -L ) | Set-Content authorized_keys

$bashrc = "https://gist.githubusercontent.com/erichiller/ac3be5b4a562a61b255b0baccb3f2da8/raw/.bashrc"
$vimrc  = "https://gist.githubusercontent.com/erichiller/ac3be5b4a562a61b255b0baccb3f2da8/raw/.vimrc"

(Invoke-WebRequest -UseBasicParsing $bashrc).Content | Set-Content .bashrc

(Invoke-WebRequest -UseBasicParsing $vimrc).Content | Set-Content .vimrc


. .\secrets.ps1


[System.Net.Dns]::GetHostAddresses($DockerHost) | Select-Object IPAddressToString | ForEach-Object {
	$_
}


& docker -H "tcp://$($DockerHost):2376" `
	--tlsverify --tlscacert=.\cert\ca.pem --tlscert=.\cert\cert.pem --tlskey=.\cert\key.pem `
	run `
	-e "DOMAIN=$($Domain.toupper())" `
	-e "DOMAINPASS=$AdminPassword" `
	-e "DNSFORWARDER=$DNSForwarder" `
	-p ${ip}:53:53 `
	-p ${ip}:53:53/udp `
	-p ${ip}:88:88 `
	-p ${ip}:88:88/udp `
	-p ${ip}:135:135 `
	-p ${ip}:137-138:137-138/udp `
	-p ${ip}:139:139 `
	-p ${ip}:389:389 `
	-p ${ip}:389:389/udp `
	-p ${ip}:445:445 `
	-p ${ip}:464:464 `
	-p ${ip}:464:464/udp `
	-p ${ip}:636:636 `
	-p ${ip}:1024-1044:1024-1044 `
	-p ${ip}:3268-3269:3268-3269 `
	-v /etc/localtime:/etc/localtime:ro `
	-v /data/docker/containers/samba/data/:/var/lib/samba `
	-v /data/docker/containers/samba/config/samba:/etc/samba/external `
	--dns-search $Domain.ToLower() `
	--dns $DNSForwarder `
	--dns $ip `
	--add-host "$($Hostname).$($domain.tolower()):$ip" `
	--hostname $Hostname.tolower() `
	--env-file env.sh `
	--tty --interactive `
    --privileged `
    --mac-addr "00:0c:02:7c:9a:44" `
    --network "bridgemac" `
	--name=samba-adc erichiller/samba-adc-image


function Remove-DockerEverything {
    docker rm -f $(docker ps -a -q)
    docker rmi -f $(docker images -q)

}