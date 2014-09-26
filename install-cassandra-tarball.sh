#!/bin/sh

VERSION="2.0.10"
SHA1="673d3367a7ef686036b335621c1fc8a963ebb2ad"
TARBALL="apache-cassandra-${VERSION}-bin.tar.gz"
URL="http://apache.osuosl.org/cassandra/${VERSION}/${TARBALL}"

set -e
set -x

# download the tarball from an Apache mirror
# verify the checksum
# untar in /opt, cleanup, symlink to /opt/cassandra

echo "${SHA1} ${TARBALL}" > ${TARBALL}.sha1

curl -O -s ${URL}

sha1sum --check ${TARBALL}.sha1

tar -xzf ${TARBALL} -C /opt

rm -f ${TARBALL} ${TARBALL}.sha1

ln -s /opt/apache-cassandra-$VERSION /opt/cassandra
