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

	SAMBACONFDIR=/usr/local/samba/etc
	SAMBAEXE=/usr/local/samba/sbin/samba

	# Set up samba
	mv /etc/krb5.conf /etc/krb5.conf.orig
	echo "[libdefaults]" > /etc/krb5.conf
	echo "    dns_lookup_realm = false" >> /etc/krb5.conf
	echo "    dns_lookup_kdc = true" >> /etc/krb5.conf
	echo "    default_realm = ${UDOMAIN}" >> /etc/krb5.conf
	###   | A Kerberos configuration suitable for Samba AD has been generated at /usr/local/samba/private/krb5.conf
	
	# If the finished file isn't there, this is brand new, we're not just moving to a new container
	if [[ ! -f ${SAMBACONFDIR}/external/smb.conf ]]; then
		if [[ -f ${SAMBACONFDIR}/smb.conf ]]; then
			mv ${SAMBACONFDIR}/smb.conf ${SAMBACONFDIR}/smb.conf.orig
		fi
		if [[ ${JOIN,,} == "true" ]]; then
			if [[ ${JOINSITE} == "NONE" ]]; then
				samba-tool domain join ${LDOMAIN} DC -U"${URDOMAIN}\administrator" --password="${DOMAINPASS}" --dns-backend=SAMBA_INTERNAL
			else
				samba-tool domain join ${LDOMAIN} DC -U"${URDOMAIN}\administrator" --password="${DOMAINPASS}" --dns-backend=SAMBA_INTERNAL --site=${JOINSITE}
			fi
		else
			samba-tool domain provision --use-rfc2307 --domain=${URDOMAIN} --realm=${UDOMAIN} --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass=${DOMAINPASS}
			if [[ ${NOCOMPLEXITY,,} == "true" ]]; then
				samba-tool domain passwordsettings set --complexity=off
				samba-tool domain passwordsettings set --history-length=0
				samba-tool domain passwordsettings set --min-pwd-age=0
				samba-tool domain passwordsettings set --max-pwd-age=0
			fi
		fi
		sed -i "/\[global\]/a \
			\\\tidmap_ldb:use rfc2307 = yes\\n\
			wins support = yes\\n\
			template shell = /bin/bash\\n\
			winbind nss info = rfc2307\\n\
			idmap config ${URDOMAIN}: range = 10000-20000\\n\
			idmap config ${URDOMAIN}: backend = ad\
			\n\
			client ntlmv2 auth = yes\n\
			dos filetime resolution = no\n\
			follow symlinks = yes\n\
			wide links = yes\n\
			log level = 4\n\
			lanman auth = no\n\
			ntlm auth = no\n\
			min protocol = SMB3\n\

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
		# Once we are set up, we'll make a file so that we know to use it if we ever spin this up again
		mkdir -p ${SAMBACONFDIR}/external/
		cp ${SAMBACONFDIR}/smb.conf ${SAMBACONFDIR}/external/smb.conf
	else
		cp ${SAMBACONFDIR}/external/smb.conf ${SAMBACONFDIR}/smb.conf
	fi
        
	# Set up supervisor
	echo "[supervisord]" > /etc/supervisor/conf.d/supervisord.conf
	echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf
	echo "stdout_logfile=/dev/fd/1" >> /etc/supervisor/conf.d/supervisord.conf
	echo "stdout_logfile_maxbytes=0" >> /etc/supervisor/conf.d/supervisord.conf
	echo "" >> /etc/supervisor/conf.d/supervisord.conf
	echo "[program:samba]" >> /etc/supervisor/conf.d/supervisord.conf
	echo "command=${SAMBAEXE} -i -d ${DEBUG_LEVEL}" >> /etc/supervisor/conf.d/supervisord.conf
	
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
		if [[ -f /etc/supervisor/conf.d/supervisord.conf ]]; then
			appStart
		else
			appSetup
		fi
		;;
esac

exit 0