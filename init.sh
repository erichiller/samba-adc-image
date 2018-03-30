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
	DNSFORWARDER=${DNSFORWARDER:-NONE}
	DEBUG_LEVEL=${DEBUG_LEVEL:-2}
	
	LDOMAIN=${DOMAIN,,}
	UDOMAIN=${DOMAIN^^}
	URDOMAIN=${UDOMAIN%%.*}

	HOSTNAME=${HOSTNAME:-ADC}
	# DNS_BACKEND=SAMBA_INTERNAL
	DNS_BACKEND=BIND9_DLZ

	# rebuild samba no matter what?
	FORCE_SAMBA_RECONFIGURE=${FORCE_SAMBA_RECONFIGURE}
	echo -e "!!!\n\nFORCE_SAMBA_RECONFIGURE is ${FORCE_SAMBA_RECONFIGURE}\n\n!!!"
	FORCE_SAMBA_RECONFIGURE=1
	

	SAMBACONFDIR=/usr/local/samba/etc
	SAMBAEXE=/usr/local/samba/sbin/samba

	# Set up samba
	# If the finished file isn't there, this is brand new, we're not just moving to a new container
	if [[ ! -f ${SAMBACONFDIR}/external/smb.conf ]] || [[ ! -z "${FORCE_SAMBA_RECONFIGURE}" ]]; then
		echo "external/smb.conf not found, setting up new domain"
		if [[ -f ${SAMBACONFDIR}/smb.conf ]]; then
			mv ${SAMBACONFDIR}/smb.conf ${SAMBACONFDIR}/smb.conf.orig
		fi
		if [[ ${JOIN,,} == "true" ]]; then
			if [[ ${JOINSITE} == "NONE" ]]; then
				samba-tool domain join ${LDOMAIN} DC -U"${URDOMAIN}\administrator" --password="${DOMAINPASS}" --dns-backend=${DNS_BACKEND}
			else
				samba-tool domain join ${LDOMAIN} DC -U"${URDOMAIN}\administrator" --password="${DOMAINPASS}" --dns-backend=${DNS_BACKEND} --site=${JOINSITE}
			fi
		else
			samba-tool domain provision --use-rfc2307 --domain=${URDOMAIN} --realm=${UDOMAIN} --server-role=dc --dns-backend=${DNS_BACKEND} --adminpass=${DOMAINPASS}
			if [[ ${NOCOMPLEXITY,,} == "true" ]]; then
				samba-tool domain passwordsettings set --complexity=off
				samba-tool domain passwordsettings set --history-length=0
				samba-tool domain passwordsettings set --min-pwd-age=0
				samba-tool domain passwordsettings set --max-pwd-age=0
			fi
		fi
		# template homedir = /share/homes/DOMAIN=%D/%U
		# domain master = auto
		# min protocol = SMB3\\n\
		# winbind enum groups = Yes
		# winbind enum users = Yes
		# host msdfs = yes
		# name resolve order = host bcast
		
		sed -i "/\[global\]/a \
			\\\tidmap_ldb:use rfc2307 = yes\\n\
			wins support = no\\n\
			template shell = /bin/bash\\n\
			winbind nss info = rfc2307\\n\
			\\n\
			client ntlmv2 auth = yes\\n\
			dos filetime resolution = no\\n\
			follow symlinks = yes\\n\
			wide links = yes\\n\
			log level = 2\\n\
			lanman auth = no\\n\
			min protocol = NT1\\n\
			ntlm auth = no\\n\
			server string = ${HOSTNAME}\\n\

			" ${SAMBACONFDIR}/smb.conf
		if [[ $DNSFORWARDER != "NONE" ]]; then
			sed -i "/\[global\]/a \
				\\\tdns forwarder = ${DNSFORWARDER}\
				" ${SAMBACONFDIR}/smb.conf
		fi
		if [[ ${INSECURELDAP,,} == "true" ]]; then
			sed -i "/\[global\]/a \
				\\\tldap server require strong auth = no\
				" ${SAMBACONFDIR}/smb.conf
		fi

		# create kerberos config for sssd
		# samba-tool domain exportkeytab /etc/krb5.keytab --principal ${HOSTNAME}\$
		# sed -i "s/SAMBA_REALM/${UDOMAIN}/" /etc/sssd/sssd.conf
		# kdb5_util create -s -P ${DOMAINPASS}

		# Once we are set up, we'll make a file so that we know to use it if we ever spin this up again
		mkdir -p ${SAMBACONFDIR}/external/
		cp ${SAMBACONFDIR}/smb.conf ${SAMBACONFDIR}/external/smb.conf
	else
		cp ${SAMBACONFDIR}/external/smb.conf ${SAMBACONFDIR}/smb.conf
	fi
        
	# Set up samba supervisor config
	echo "[program:samba]" > /etc/supervisor/conf.d/samba.conf
	echo "command=${SAMBAEXE} -i -d ${DEBUG_LEVEL}" >> /etc/supervisor/conf.d/samba.conf

	cp /usr/local/samba/private/krb5.conf /etc/krb5.conf
	
	appStart
}

appStart () {
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