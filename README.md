# Samba ADC Docker

## About

**Key Components**
| Software          | Version       | Origin
| ---               | ---           | ---
| Debian            | 9 (Stretch)   | Docker pull
| Samba             | 4.8.0         | tar.gz source off samba.org ; March 15, 2018
| OpenSSH-server    |               | Package
| Supervisor        |               | Package

# Usage

**Restart Single Service with**

```bash
supervisorctl restart sshd
```


# Source Documenation

<https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller>




**Creating bridgemac network**
```
.\docker.exe --host tcp://nas:2376 --tlsverify --tlscacert .\cert\ca.pem  --tlscert .\cert\cert.pem --tlskey .\cert\key.pem network create --driver macvlan --subnet="192.168.10.0/24" --gateway="192.168.10.1" --opt parent=qvs0 bridgemac
```

**Verifying bridgemac network**
```
PS C:\Users\ehiller\dev\samba_docker> .\docker.exe --host tcp://nas:2376 --tlsverify --tlscacert .\cert\ca.pem  --tlscert .\cert\cert.pem --tlskey .\cert\key.pem network ls
NETWORK ID          NAME                DRIVER              SCOPE
17978ce78f7c        bridge              bridge              local
34d028744153        bridgemac           macvlan             local
7bb088558cd4        host                host                local
245658a1df12        none                null                local
```

# Building Samba

[packages required](https://wiki.samba.org/index.php/Package_Dependencies_Required_to_Build_Samba)

[process](https://wiki.samba.org/index.php/Build_Samba_from_Source)
is simple:

```
./configure
make
make install
```

Much of the docker is from <https://github.com/Fmstrat/samba-domain>

# Debug

**NOTE**: Do remember the `-l -i` after `/bin/bash` otherwise the terminal will be sized oddly.

```
docker --host "tcp://nas:2376" --tlsverify --tlscacert ./cert/ca.pem  --tlscert ./cert/cert.pem --tlskey ./cert/key.pem exec -it sambaadcimage_samba_adc_1 /bin/bash -l -i


docker --host "tcp://nas:2376" --tlsverify --tlscacert ./cert/ca.pem  --tlscert ./cert/cert.pem --tlskey ./cert/key.pem exec -it 66ae2381cdca /bin/bash -l -i




```


# dump of info


## bind9_10 on debian

```
starting BIND 9.10.3-P4-Debian <id:ebd72b3> -c /etc/bind/named.conf -u bind -f
Mar 27 11:18:25 adc named[74]: built with '--prefix=/usr' '--mandir=/usr/share/man' '--libdir=/usr/lib/x86_64-linux-gnu' '--infodir=/usr/share/info' '--sysconfdir=/etc/bind' '--with-python=python3' '--localstatedir=/' '--enable-threads' '--enable-largefile' '--with-libtool' '--enable-shared' '--enable-static' '--with-gost=no' '--with-openssl=/usr' '--with-gssapi=/usr' '--with-gnu-ld' '--with-geoip=/usr' '--with-atf=no' '--enable-ipv6' '--enable-rrl' '--enable-filter-aaaa' '--enable-native-pkcs11' '--with-pkcs11=/usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so' '--with-randomdev=/dev/urandom' 'CFLAGS=-g -O2 -fdebug-prefix-map=/build/bind9-zVMG3I/bind9-9.10.3.dfsg.P4=. -fstack-protector-strong -Wformat -Werror=format-security -fno-strict-aliasing -fno-delete-null-pointer-checks -DNO_VERSION_DATE -DDIG_SIGCHASE' 'LDFLAGS=-Wl,-z,relro -Wl,-z,now' 'CPPFLAGS=-Wdate-time -D_FORTIFY_SOURCE=2
```






```


# from https://github.com/dperson/samba/blob/master/README.md

# Install samba
RUN apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add bash samba shadow && \
    adduser -D -G users -H -S -g 'Samba User' -h /tmp smbuser && \
    file="/etc/samba/smb.conf" && \
    sed -i 's|^;* *\(log file = \).*|   \1/dev/stdout|' $file && \
    sed -i 's|^;* *\(load printers = \).*|   \1no|' $file && \
    sed -i 's|^;* *\(printcap name = \).*|   \1/dev/null|' $file && \
    sed -i 's|^;* *\(printing = \).*|   \1bsd|' $file && \
    sed -i 's|^;* *\(unix password sync = \).*|   \1no|' $file && \
    sed -i 's|^;* *\(preserve case = \).*|   \1yes|' $file && \
    sed -i 's|^;* *\(short preserve case = \).*|   \1yes|' $file && \
    sed -i 's|^;* *\(default case = \).*|   \1lower|' $file && \
    sed -i '/Share Definitions/,$d' $file && \
    echo '   pam password change = yes' >>$file && \
    echo '   map to guest = bad user' >>$file && \
    echo '   usershare allow guests = yes' >>$file && \
    echo '   create mask = 0664' >>$file && \
    echo '   force create mode = 0664' >>$file && \
    echo '   directory mask = 0775' >>$file && \
    echo '   force directory mode = 0775' >>$file && \
    echo '   force user = smbuser' >>$file && \
    echo '   force group = users' >>$file && \
    echo '   follow symlinks = yes' >>$file && \
    echo '   load printers = no' >>$file && \
    echo '   printing = bsd' >>$file && \
    echo '   printcap name = /dev/null' >>$file && \
    echo '   disable spoolss = yes' >>$file && \
    echo '   socket options = TCP_NODELAY' >>$file && \
    echo '   strict locking = no' >>$file && \
    echo '   vfs objects = recycle' >>$file && \
    echo '   recycle:keeptree = yes' >>$file && \
    echo '   recycle:versions = yes' >>$file && \
    echo '   min protocol = SMB3' >>$file && \
    echo '' >>$file && \
#Eric
# ntlm auth = ntlmv2-only
    rm -rf /tmp/*


COPY samba.sh /usr/bin/

EXPOSE 137/udp 138/udp 139 445

HEALTHCHECK --interval=60s --timeout=15s \
             CMD smbclient -L '\\localhost\' -U 'guest%' -m SMB3
VOLUME ["/etc/samba"]
ENTRYPOINT ["samba.sh"]





cat /etc/smb.conf
[global]
passdb backend = smbpasswd
workgroup = HILLER
server string = NAS
encrypt passwords = Yes
username level = 0
map to guest = Bad User
null passwords = yes
max log size = 10
socket options = TCP_NODELAY SO_KEEPALIVE
os level = 20
preferred master = no
dns proxy = No
smb passwd file=/etc/config/smbpasswd
username map = /etc/config/smbusers
guest account = guest
directory mask = 0777
create mask = 0777
oplocks = yes
locking = yes
disable spoolss = no
load printers = yes
veto files = /.AppleDB/.AppleDouble/.AppleDesktop/:2eDS_Store/Network Trash Folder/Temporary Items/TheVolumeSettingsFolder/.@__thumb/.@__desc/:2e*/.@__qini/.Qsync/.@upload_cache/.qsync/.qsync_sn/.@qsys/.streams/.digest/
delete veto files = yes
map archive = no
map system = no
map hidden = no
map read only = no
deadtime = 10
server role = active directory domain controller
use sendfile = yes
unix extensions = no
store dos attributes = yes
client ntlmv2 auth = yes
dos filetime resolution = no
follow symlinks = yes
wide links = yes
force unknown acl user = yes
template homedir = /share/homes/DOMAIN=%D/%U
inherit acls = yes
domain logons = no
min receivefile size = 256
case sensitive = auto
domain master = auto
local master = yes
enhance acl v1 = yes
remove everyone = yes
conn log = yes
kernel oplocks = no
min protocol = NT1
smb2 leases = yes
durable handles = yes
kernel share modes = no
posix locking = no
printcap cache time = 0
acl allow execute always = yes
server signing = required
streams_depot:delete_lost = yes
streams_depot:check_valid = no
fruit:nfs_aces = no
fruit:veto_appledouble = no
winbind expand groups = 1
printcap name = /etc/printcap
printing = cups
show add printer wizard = no
wins support = no
aio read size = 1
aio write size = 0
realm = hiller.pro
netbios name = NAS
ntp signd socket directory = /usr/local/samba/var/lib/ntp_signd
private dir = /share/CACHEDEV1_DATA/.samba_target/private
lock directory = /share/CACHEDEV1_DATA/.samba_target
state directory = /share/CACHEDEV1_DATA/.samba_target/state
cache directory = /share/CACHEDEV1_DATA/.samba_target/cache
dns forwarder = 192.168.10.1
winbind enum groups = Yes
winbind enum users = Yes
host msdfs = yes
name resolve order = host bcast
lanman auth = no
ntlm auth = no
vfs objects =  shadow_copy2 acl_xattr catia fruit qnap_macea streams_depot aio_pthread

[netlogon]
comment = netlogon
path = /share/CACHEDEV1_DATA/.samba_target/state/sysvol/hiller.pro/scripts
invalid users =
read list = @"HILLER\Domain Users"
write list = @"HILLER\Domain Admins"
valid users = @"HILLER\Domain Admins",@"HILLER\Domain Users"
browsable = yes
recycle bin = no
shadow:snapdir = /share/CACHEDEV1_DATA/_.share/netlogon/.snapshot
shadow:basedir = /share/CACHEDEV1_DATA/.samba_target/state/sysvol/hiller.pro/scripts
shadow:sort = desc
shadow:format = @GMT-%Y.%m.%d-%H:%M:%S
```