#!/bin/bash

set -e
set -x


# rebuild samba no matter what?
FORCE_SAMBA_RECONFIGURE=${FORCE_SAMBA_RECONFIGURE}

# Set variables
DOMAIN=${DOMAIN:-SAMDOM.LOCAL}
# lowercase FQDN
LDOMAIN=${DOMAIN,,}
# uppercase FQDN
UDOMAIN=${DOMAIN^^}
# uppercase REALM (lowest hierarchy domain)
URDOMAIN=${UDOMAIN%%.*}

ADDR_V4=${ADDR_V4}
ADDR_V6=${ADDR_V6}


	

HOSTNAME=${HOSTNAME:-ADC}
# DNS_BACKEND=SAMBA_INTERNAL
DNS_BACKEND=BIND9_DLZ
DOMAINPASS=${DOMAINPASS:-youshouldsetapassword}
JOIN=${JOIN:-false}
JOINSITE=${JOINSITE:-NONE}
NOCOMPLEXITY=${NOCOMPLEXITY:-false}
INSECURELDAP=${INSECURELDAP:-false}
DEBUG_LEVEL=${DEBUG_LEVEL:-2}
BINDCONFDIR=${BINDCONFDIR:-/etc/bind/}
SAMBA_DATA_DIR=${SAMBA_DATA_DIR}
SAMBACONFDIR=${SAMBA_DATA_DIR}/config
SAMBAEXE=/sbin/samba
SMBCONTROL=/bin/smbcontrol

appSetup () {

	# Set up samba
	if [[ -f ${SAMBACONFDIR}/smb.conf ]]; then
		mv ${SAMBACONFDIR}/smb.conf ${SAMBACONFDIR}/smb.conf.orig
	fi
	# domain is short, like HILLER , realm is FQDN , such as HILLER.PRO
	samba-tool domain provision --use-rfc2307 --domain=${URDOMAIN} --realm=${UDOMAIN} --server-role=dc --dns-backend=${DNS_BACKEND} --adminpass=${DOMAINPASS}
	if [[ ${NOCOMPLEXITY,,} == "true" ]]; then
		samba-tool domain passwordsettings set --complexity=off
		samba-tool domain passwordsettings set --history-length=0
		samba-tool domain passwordsettings set --min-pwd-age=0
		samba-tool domain passwordsettings set --max-pwd-age=0
	fi
	# template homedir = /share/homes/DOMAIN=%D/%U
	# domain master = auto
	# min protocol = SMB3\\n\
	# winbind enum groups = Yes
	# winbind enum users = Yes
	# host msdfs = yes
	# name resolve order = host bcast
	
	# see log levels
	# https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#LOGLEVEL
	sed -i "/\[global\]/a \
		\\\tidmap_ldb:use rfc2307 = yes\\n\
		wins support = no\\n\
		template shell = /bin/bash\\n\
		winbind nss info = rfc2307\\n\
		load printers = no\\n\
		printing = bsd\\n\
		printcap name = /dev/null\\n\
		disable spoolss = yes\\n\
		\\n\
		client ntlmv2 auth = yes\\n\
		dos filetime resolution = no\\n\
		unix extensions = yes\\n\
		lanman auth = no\\n\
		min protocol = NT1\\n\
		ntlm auth = no\\n\
		server string = ${HOSTNAME}\\n\
		rpc server dynamic port range = 49152-65535 \\n\

		" ${SAMBACONFDIR}/smb.conf
	if [[ ${INSECURELDAP,,} == "true" ]]; then
		sed -i "/\[global\]/a \
			\\\tldap server require strong auth = no\
			" ${SAMBACONFDIR}/smb.conf
	fi

	# create internal configs for the BIND backend
	samba_upgradedns --dns-backend=BIND9_DLZ

	mkdir -p ${SAMBACONFDIR}/external
	cp ${SAMBACONFDIR}/smb.conf ${SAMBACONFDIR}/external/smb.conf
	
	appStart
}

appStart () {
	echo -e "domain ${LDOMAIN}\nnameserver ${ADDR_V4}\nnameserver ::1" > /etc/resolv.conf

	cp ${SAMBACONFDIR}/external/smb.conf ${SAMBACONFDIR}/smb.conf
	cp ${SAMBA_DATA_DIR}/private/krb5.conf /etc/krb5.conf

	/usr/bin/supervisord
}

case "$1" in
	start)
		if [ -f ${SAMBACONFDIR}/external/smb.conf ]; then
			appStart
			# set debug
			# ${SMBCONTROL} --debuglevel=${DEBUG_LEVEL}
		else
			echo "Config file is missing."
		fi
		;;
	setup)
		# If the supervisor conf isn't there, we're spinning up a new container
		
		if [ "${FORCE_SAMBA_RECONFIGURE}" == 1 ]; then
			appSetup
		elif [[ -f ${SAMBACONFDIR}/external/smb.conf ]]; then
			appStart
		else
			appSetup
		fi
		;;
esac

exit 0