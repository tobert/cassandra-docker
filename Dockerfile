FROM       azul/zulu-openjdk:8
MAINTAINER Al Tobey <atobey@datastax.com>

VOLUME ["/data"]
ENTRYPOINT ["/bin/cassandra-docker"]

COPY install-ubuntu-packages.sh /
RUN /bin/sh /install-ubuntu-packages.sh

# TEMPORARY: while the mirrors are messed up and I'm doing
# dev passes, this will expect a tarball in the root of the repo
# wget http://www.apache.dist/cassandra/2.1.7/apache-cassandra-2.1.7-bin.tar.gz
COPY apache-cassandra-2.1.7-bin.tar.gz /

COPY install-cassandra-tarball.sh /
RUN /bin/sh /install-cassandra-tarball.sh

# create a cassandra user:group & chown
# Note: this UID/GID is hard-coded in main.go
RUN groupadd -g 1337 cassandra && \
    useradd -u 1337 -g cassandra -s /bin/sh -d /data cassandra && \
    chown -R cassandra:cassandra /data

# the source configuration (templates) need to be in /src/conf
# so the entry point can find them
COPY conf /src/conf

# install the entrypoint
# building it is just: go build
COPY cassandra-docker/cassandra-docker /bin/

# create symlinks for common commands (for docker exec)
RUN ln -s /bin/cassandra-docker /bin/cassandra && \
    ln -s /bin/cassandra-docker /bin/cqlsh     && \
    ln -s /bin/cassandra-docker /bin/nodetool  && \
    ln -s /bin/cassandra-docker /bin/cassandra-stress

# Storage Port, JMX, Thrift, CQL Native, OpsCenter Agent
# Left out: SSL
EXPOSE 7000 7199 9042 9160 61621

