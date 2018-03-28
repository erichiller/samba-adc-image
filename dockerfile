FROM debian:9
SHELL ["/bin/bash", "-c"]

# https://github.com/myrjola/docker-samba-ad-dc/blob/master/Dockerfile

LABEL description="Samba 3.8 AD Controller"
MAINTAINER Eric Hiller <ehiller@hiller.pro>
ENV DEBIAN_FRONTEND noninteractive

# my .bashrc
COPY .bashrc /root/.bashrc
COPY .vimrc /root/.vimrc
RUN mkdir -p /etc/ssh
COPY authorized_keys /etc/ssh/authorized_keys
# use bash
RUN rm /bin/sh && ln -s /bin/bash /bin/sh


# for the system
RUN echo -e "Eric D Hiller" > /etc/version
RUN echo -e "Samba ADC" > /etc/version
RUN date +%Y-%m-%d >> /etc/version

RUN apt-get update && apt-get upgrade -y && apt-get install -y --force-yes \
		wget \
		supervisor \
		acl attr autoconf bind9utils bison build-essential \
		debhelper dnsutils docbook-xml docbook-xsl flex gdb libjansson-dev krb5-user \
		libacl1-dev libaio-dev libarchive-dev libattr1-dev libblkid-dev libbsd-dev \
		libcap-dev libcups2-dev libgnutls28-dev libgpgme11-dev libjson-perl \
		libldap2-dev libncurses5-dev libpam0g-dev libparse-yapp-perl \
		libpopt-dev libreadline-dev nettle-dev perl perl-modules-5.24 pkg-config \
		python-all-dev python-crypto python-dbg python-dev python-dnspython \
		python3-dnspython python-gpgme python3-gpgme python-markdown python3-markdown \
		python3-dev xsltproc zlib1g-dev \
		bind9 libkrb5-dev krb5-kdc vim openssh-server expect rsyslog sssd sssd-tools \
		inetutils-ping \
	&& rm -rf /var/lib/apt/lists/* \
	&& apt-get clean



WORKDIR /root
RUN wget https://download.samba.org/pub/samba/stable/samba-4.8.0.tar.gz
RUN tar -zxvf samba-4.8.0.tar.gz
WORKDIR /root/samba-4.8.0
RUN ./configure
RUN make
RUN make install
ENV PATH "/usr/local/samba/bin/:/usr/local/samba/sbin/:$PATH"

# leave the working dir in somewhere useful
WORKDIR /usr/local/samba/

# sshd
RUN mkdir -p /var/run/sshd
RUN sed -ri 's/PermitRootLogin without-password/PermitRootLogin Yes/g' /etc/ssh/sshd_config

# Create run directory for bind9
RUN mkdir -p /run/named
# RUN chown -R bind:bind /run/named
# RUN chown -R root:bind /etc/bind
COPY named.conf.options /etc/bind/named.conf.options
# RUN chmod 640 /etc/bind/named.conf.options
# RUN chmod -R 640 /etc/bind
# update ROOT nameservers
RUN wget -q -O /etc/bind/db.root http://www.internic.net/zones/named.root
# RUN chown root:bind /etc/bind/db.root
# RUN chmod 640 /etc/bind/db.root

# Install sssd for UNIX logins to AD
# --chown is only 17.09+
# https://github.com/moby/moby/issues/35731
# RUN lsattr /etc/sssd
# RUN lsattr /etc/sssd/sssd.conf
# RUN chown -RLv sssd:root /etc/sssd
COPY sssd.conf /etc/sssd/conf.d/sssd.conf
# RUN chmod 0600 /etc/sssd/sssd.conf

# supervisor
RUN mkdir -p /var/log/supervisor
RUN mkdir -p /etc/supervisor/conf.d
COPY aux_supervisord.conf /etc/supervisor/conf.d/aux_supervisord.conf
RUN chmod 640 /etc/supervisor/conf.d/aux_supervisord.conf


COPY init.sh /root/init.sh
RUN chmod 755 /root/init.sh
CMD /root/init.sh setup