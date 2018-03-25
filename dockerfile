FROM debian:9
SHELL ["/bin/bash", "-c"]

LABEL description="Samba 3.8 AD Controller"
MAINTAINER Eric Hiller <ehiller@hiller.pro>
ENV DEBIAN_FRONTEND noninteractive

# my .bashrc
COPY .bashrc /root/.bashrc
COPY .vimrc /root/.vimrc
# use bash
RUN rm /bin/sh && ln -s /bin/bash /bin/sh


# for the system
RUN echo "8.8.8.8" > /etc/resolv.conf
RUN echo "8.8.4.4" >> /etc/resolv.conf
RUN echo -e "Eric D Hiller" > /etc/version
RUN echo -e "Samba ADC" > /etc/version
RUN date +%Y-%m-%d >> /etc/version

RUN apt-get update && apt-get install -y --force-yes \
		wget \
		supervisor \
		acl attr autoconf bind9utils bison build-essential \
		debhelper dnsutils docbook-xml docbook-xsl flex gdb libjansson-dev krb5-user \
		libacl1-dev libaio-dev libarchive-dev libattr1-dev libblkid-dev libbsd-dev \
		libcap-dev libcups2-dev libgnutls28-dev libgpgme11-dev libjson-perl \
		libldap2-dev libncurses5-dev libpam0g-dev libparse-yapp-perl \
		libpopt-dev libreadline-dev nettle-dev perl perl-modules pkg-config \
		python-all-dev python-crypto python-dbg python-dev python-dnspython \
		python3-dnspython python-gpgme python3-gpgme python-markdown python3-markdown \
		python3-dev xsltproc zlib1g-dev \
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

COPY init.sh /root/init.sh
RUN chmod +x /root/init.sh
CMD /root/init.sh setup