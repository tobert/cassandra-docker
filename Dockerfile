FROM       azul/zulu-openjdk-centos:7
MAINTAINER Al Tobey <atobey@datastax.com>

VOLUME ["/data"]
ENTRYPOINT ["/bin/cassandra-docker"]

COPY install-cassandra-tarball.sh /
RUN /bin/sh /install-cassandra-tarball.sh

# create a cassandra user:group & chown
# Note: this UID/GID is hard-coded in main.go
RUN groupadd -g 1337 cassandra
RUN useradd -u 1337 -g cassandra -s /bin/sh -d /data cassandra
RUN chown -R cassandra:cassandra /data

COPY cassandra-docker /bin/

# SSH, Storage Port, JMX, Thrift, CQL Native, OpsCenter Agent
# Left out: SSL
EXPOSE 22 7000 7199 9042 9160 61621

