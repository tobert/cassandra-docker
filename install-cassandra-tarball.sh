#!/bin/sh

VERSION="2.0.11"
SHA1="f31d71797e1ffeeacb3c71ad35e900d11580bfc3"
TARBALL="apache-cassandra-${VERSION}-bin.tar.gz"
URL="http://www.apache.dist/cassandra/${VERSION}/${TARBALL}"

cd /

set -e
set -x

# download the tarball from an Apache mirror
# verify the checksum
# untar in /opt, cleanup, symlink to /opt/cassandra

echo "${SHA1} ${TARBALL}" > ${TARBALL}.sha1

ls -l

# copy in from the Dockerfile for now to save downloads
#curl -O -s ${URL}

sha1sum --check ${TARBALL}.sha1

tar -xzf ${TARBALL} -C /opt

rm -f ${TARBALL} ${TARBALL}.sha1

ln -s /opt/apache-cassandra-$VERSION /opt/cassandra

rm -f $0
