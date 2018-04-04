# escape=` (backtick)

FROM debian:9
SHELL ["/bin/bash", "-c"]

# https://github.com/myrjola/docker-samba-ad-dc/blob/master/Dockerfile

LABEL description="Samba 4.8 AD Controller"
LABEL maintainer="Eric Hiller <ehiller@hiller.pro>"
ENV DEBIAN_FRONTEND noninteractive

# use bash
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# for the system
RUN echo -e "Eric D Hiller" > /etc/version
RUN echo -e "Samba ADC" > /etc/version
RUN date +%Y-%m-%d >> /etc/version

RUN mkdir -p /usr/local/samba/var/lib/ntp_signd/

RUN apt-get update && apt-get upgrade -y && apt-get install -y --force-yes `
		wget `
		supervisor `
		acl attr autoconf bind9utils bison build-essential `
		debhelper dnsutils docbook-xml docbook-xsl flex gdb libjansson-dev `
		krb5-user `
		libacl1-dev libaio-dev libarchive-dev libattr1-dev libblkid-dev libbsd-dev `
		libcap-dev libcups2-dev libgnutls28-dev libgpgme11-dev libjson-perl `
		libldap2-dev libncurses5-dev libpam0g-dev libparse-yapp-perl `
		libpopt-dev libreadline-dev nettle-dev perl perl-modules-5.24 pkg-config `
		python-all-dev python-crypto python-dbg python-dev python-dnspython `
		python3-dnspython python-gpgme python3-gpgme python-markdown python3-markdown `
		python3-dev xsltproc zlib1g-dev `
		bind9 vim openssh-server `
		ntp `
		inetutils-ping `
	&& rm -rf /var/lib/apt/lists/* `
	&& apt-get clean `
	&& chown -R root:bind /etc/bind `
	&& chown -R root:ntp /var/lib/ntp `
	&& chmod g=rwx /var/lib/ntp `
	&& chown -R root:ntp /usr/local/samba/var/lib/ntp_signd/ `
	&& chmod g=rwx /usr/local/samba/var/lib/ntp_signd/

# Compile Samba newest
WORKDIR /root
RUN wget https://download.samba.org/pub/samba/stable/samba-4.8.0.tar.gz
RUN tar -zxvf samba-4.8.0.tar.gz
WORKDIR /root/samba-4.8.0
ARG SAMBA_DATA_DIR
RUN mkdir -p $SAMBA_DATA_DIR
RUN ./configure --with-configdir=$SAMBA_DATA_DIR/config --with-logfilebase=$SAMBA_DATA_DIR/log --with-bind-dns-dir=$SAMBA_DATA_DIR/dns --with-privatedir=$SAMBA_DATA_DIR/private --with-statedir=$SAMBA_DATA_DIR/state --disable-cups --mandir=/usr/share/man --sbindir=/sbin --bindir=/bin
RUN make
RUN make install
RUN mkdir /var/log/samba
# ENV PATH "/usr/local/samba/bin/:/usr/local/samba/sbin/:$PATH"

# leave the working dir in somewhere useful
WORKDIR /root

# my .bashrc
COPY .bashrc /root/.bashrc
COPY .vimrc /root/.vimrc
# remove ^M from .vimrc -- they always seem to get in there!
RUN sed -ie "s/\^M//" /root/.vimrc
RUN mkdir -p /root/.ssh
COPY authorized_keys /root/.ssh/authorized_keys

# sshd
RUN mkdir -p /var/run/sshd
RUN sed -ri 's/^#PermitRootLogin .*$/PermitRootLogin Yes/g' /etc/ssh/sshd_config

# Create run directory for bind9
RUN mkdir -p /run/named
RUN chown root:bind /run/named
RUN chmod g=rwx /run/named
RUN chown root:bind /usr/local/samba/lib/bind9/dlz_bind9_10.so
COPY named.conf.options /etc/bind/named.conf.options
# update ROOT nameservers
RUN wget -q -O /etc/bind/db.root http://www.internic.net/zones/named.root
RUN chown --from=root:root root:bind /etc/bind/*

# supervisor
RUN mkdir -p /var/log/supervisor
RUN mkdir -p /etc/supervisor/conf.d
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod 640 /etc/supervisor/conf.d/supervisord.conf

RUN echo "alias sup='supervisorctl'" >> /root/.bashrc

# ntpd
COPY ntp.conf /etc/ntp.conf

# permissions
RUN mkdir -p  /data/state/winbindd_privileged
RUN chmod 0750 /data/state/winbindd_privileged
RUN chmod 0750 /usr/local/samba/var/lib/ntp_signd

ARG FORCE_SAMBA_RECONFIGURE
ENV FORCE_SAMBA_RECONFIGURE $FORCE_SAMBA_RECONFIGURE
COPY init.sh /root/init.sh
RUN chmod 755 /root/init.sh
CMD /root/init.sh setup