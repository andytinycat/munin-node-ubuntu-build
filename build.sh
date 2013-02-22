#!/bin/bash

# This is ugly. I should write something to do this.

lsb_codename=`lsb_release --codename --short`
version="2.0.11.1"
iteration="1"
buildroot="/tmp/buildroot"

# Get the Munin source
if [ ! -e munin-${version}.tar.gz ]; then
  wget "http://downloads.sourceforge.net/project/munin/stable/2.0.11/munin-${version}.tar.gz"
fi

# Untar it, removing any old copies
if [ -d munin-${version} ]; then
  rm -rf munin-${version}
fi
tar xf munin-${version}.tar.gz
cd munin-${version}

# Custom Makefile.config to put stuff in usual places
cp ../Makefile.config Makefile.config

# Make Munin user
if ! getent passwd munin >/dev/null; then
  adduser --group --system --no-create-home \
  --home /var/lib/munin munin;
fi

# Make sure these packages are installed
apt-get install libnet-server-perl libtime-hires-perl libnet-snmp-perl libdigest-hmac-perl libdigest-sha-perl libcrypt-des-perl libnet-ssleay-perl libhtml-template-perl liblog-log4perl-perl

# Install into buildroot
if [ -d ${buildroot} ]; then
  rm -rf ${buildroot}
fi
mkdir ${buildroot}
DESTDIR=${buildroot} make
DESTDIR=${buildroot} make install-common-prime install-node-prime install-plugins-prime

# Fix up the buildroot paths in some plugins and config files
find ${buildroot} -type f -exec sed -i 's/\/tmp\/buildroot//g' {} \;

# Substitute version into files, cos Makefile doesn't do it on a node-only build
find ${buildroot} -type f -exec sed -i "s|@@VERSION@@|${version}|g" {} \;

# Put the init script into the buildroot
mkdir -p ${buildroot}/etc/init.d
cp ../munin-node.init ${buildroot}/etc/init.d/munin-node
chmod 755 ${buildroot}/etc/init.d/munin-node

# Put a logrotate file into buildroot
mkdir -p ${buildroot}/etc/logrotate.d
cp ../munin-node.logrotate ${buildroot}/etc/logrotate.d/munin-node

# Package up with fpm
rm -rf ../pkg
mkdir ../pkg
fpm -e -t deb -s dir -C /tmp/buildroot \
-p ../pkg/munin-node-VERSION_ARCH.deb \
-n munin-node -v ${version} \
--after-install ../munin-node.postinst \
--after-remove ../munin-node.postrm \
--depends libnet-server-perl \
--depends libtime-hires-perl \
--depends libnet-snmp-perl \
--depends libdigest-hmac-perl \
--depends libdigest-sha-perl \
--depends libcrypt-des-perl \
--depends libnet-ssleay-perl \
--depends liblog-log4perl-perl \
--depends libhtml-template-perl \
--description "Munin node" \
--url "http://muninmonitoring.org" \
--maintainer "<agency-devs@forward.co.uk>" \
--vendor "agency-devs@forward.co.uk" \
--iteration 1 \
.

# Done
