#!/bin/bash

set -e
set -x

appSetup () {

	# Set variables
	DOMAIN=${DOMAIN:-SAMDOM.LOCAL}
	DOMAINPASS=${DOMAINPASS:-youshouldsetapassword}
	JOIN=${JOIN:-false}
	JOINSITE=${JOINSITE:-NONE}
	NOCOMPLEXITY=${NOCOMPLEXITY:-false}
	INSECURELDAP=${INSECURELDAP:-false}
	DEBUG_LEVEL=${DEBUG_LEVEL:-2}
	BINDCONFDIR=${BINDCONFDIR:-/etc/bind/}
	ADDR_V4=${ADDR_V4}
	ADDR_V6=${ADDR_V6}
	
	# lowercase FQDN
	LDOMAIN=${DOMAIN,,}
	# uppercase FQDN
	UDOMAIN=${DOMAIN^^}
	# uppercase REALM (lowest hierarchy domain)
	URDOMAIN=${UDOMAIN%%.*}

	HOSTNAME=${HOSTNAME:-ADC}
	# DNS_BACKEND=SAMBA_INTERNAL
	DNS_BACKEND=BIND9_DLZ

	# rebuild samba no matter what?
	FORCE_SAMBA_RECONFIGURE=${FORCE_SAMBA_RECONFIGURE}

	SAMBA_DATA_DIR=${SAMBA_DATA_DIR}


	SAMBACONFDIR=${SAMBA_DATA_DIR}/config
	SAMBAEXE=/sbin/samba

	# Set up samba
	# If the finished file isn't there, this is brand new, we're not just moving to a new container
	if [[ ! -f ${SAMBACONFDIR}/external/smb.conf ]] || [[ ! -z "${FORCE_SAMBA_RECONFIGURE}" ]]; then
		echo "external/smb.conf not found, setting up new domain"
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
			\\n\
			client ntlmv2 auth = yes\\n\
			dos filetime resolution = no\\n\
			unix extensions = yes\\n\
			follow symlinks = yes\\n\
			wide links = yes\\n\
			log file = /var/log/samba/%m.log\\n\
			log level = 4 auth_audit:5 ldb:4 dns:5 auth:3 tdb:3\\n\
			lanman auth = no\\n\
			min protocol = NT1\\n\
			ntlm auth = no\\n\
			server string = ${HOSTNAME}\\n\

			" ${SAMBACONFDIR}/smb.conf
		# DNSFORWARDER is useless with BIND
		# if [[ $DNSFORWARDER != "NONE" ]]; then
		# 	sed -i "/\[global\]/a \
		# 		\\\tdns forwarder = ${DNSFORWARDER}\
		# 		" ${SAMBACONFDIR}/smb.conf
		# fi
		if [[ ${INSECURELDAP,,} == "true" ]]; then
			sed -i "/\[global\]/a \
				\\\tldap server require strong auth = no\
				" ${SAMBACONFDIR}/smb.conf
		fi

		# put in proper keytab location
		sed -i "/\/\/ DNS dynamic updates via Kerberos/a \
				\\\ttkey-gssapi-keytab \"\/${SAMBA_DATA_DIR}\/private\/dns\.keytab\";\
				" ${BINDCONFDIR}/named.conf.options

		# Once we are set up, we'll make a file so that we know to use it if we ever spin this up again
		mkdir -p ${SAMBACONFDIR}/external/
		cp ${SAMBACONFDIR}/smb.conf ${SAMBACONFDIR}/external/smb.conf
	else
		cp ${SAMBACONFDIR}/external/smb.conf ${SAMBACONFDIR}/smb.conf
	fi
        
	# Set up samba supervisor config
	echo "[program:samba]" > /etc/supervisor/conf.d/samba.conf
	echo "command=${SAMBAEXE} -i -d ${DEBUG_LEVEL}" >> /etc/supervisor/conf.d/samba.conf

	# create internal configs for the BIND backend
	samba_upgradedns --dns-backend=BIND9_DLZ

	cp ${SAMBA_DATA_DIR}/private/krb5.conf /etc/krb5.conf
	
	appStart
}

appStart () {
	echo -e "domain ${LDOMAIN}\nnameserver ${ADDR_V4}\n${ADDR_V6}" > /etc/resolv.conf
	/usr/bin/supervisord
}

case "$1" in
	start)
		if [[ -f ${SAMBACONFDIR}/external/smb.conf ]]; then
			cp ${SAMBACONFDIR}/external/smb.conf ${SAMBACONFDIR}/smb.conf
			appStart
		else
			echo "Config file is missing."
		fi
		;;
	setup)
		# If the supervisor conf isn't there, we're spinning up a new container
		if [[ -f /etc/supervisor/conf.d/samba.conf ]]; then
			appStart
		else
			appSetup
		fi
		;;
esac

exit 0