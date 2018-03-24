FROM debian:9
SHELL ["/bin/bash", "-c"]

LABEL description="Samba 3.8 AD Controller"
MAINTAINER Eric Hiller <ehiller@hiller.pro>
ENV DEBIAN_FRONTEND noninteractive



# my .bashrc
COPY .bashrc /root/.bashrc
COPY .vimrc /root/.vimrc
# add authorized_keys
COPY authorized_keys /root/.ssh/authorized_keys
# use bash
RUN rm /bin/sh && ln -s /bin/bash /bin/sh
# mount local VOLUME
VOLUME /etc/samba



# Install all apps
# The third line is for multi-site config (ping is for testing later)
RUN apt-get install -y pkg-config
RUN apt-get install -y attr acl samba smbclient ldap-utils winbind libnss-winbind libpam-winbind krb5-user krb5-kdc supervisor
RUN apt-get install -y inetutils-ping







# for the system
RUN echo "8.8.8.8" > /etc/resolv.conf
RUN echo "8.8.4.4" >> /etc/resolv.conf
RUN echo -e "Eric D Hiller" > /etc/version
RUN echo -e "Samba ADC" > /etc/version
RUN date +%Y-%m-%d >> /etc/version

# RUN echo "deb http://deb.debian.org/debian stable-updates contrib" >> /etc/apt/sources.list.d/backports.list
# RUN echo "deb http://deb.debian.org/debian stable-updates non-free" >> /etc/apt/sources.list.d/backports.list
# RUN echo "deb http://deb.debian.org/debian stable contrib" >> /etc/apt/sources.list.d/backports.list
# RUN echo "deb http://deb.debian.org/debian stable non-free" >> /etc/apt/sources.list.d/backports.list

RUN apt-get update && apt-get install -y --force-yes \
		apt-transport-https \
		ca-certificates \
		curl \
		gcc \
		git \
		libc6-dev \
		make \
		openssh-server \
		pkg-config \
		software-properties-common \
		vim \
		dos2unix \
		dialog \
		unzip \
	&& rm -rf /var/lib/apt/lists/* \
	&& apt-get clean

RUN mkdir -p /var/run/sshd
RUN sed -ri 's/^session\s+required\s+pam_loginuid.so$/session optional pam_loginuid.so/' /etc/pam.d/sshd
RUN sed -ri 's/StrictModes yes/StrictModes no/' /etc/ssh/sshd_config



# Set up script and run
ADD init.sh /init.sh
RUN chmod 755 /init.sh
CMD /init.sh setup