FROM       ubuntu:14.04
MAINTAINER Al Tobey <atobey@datastax.com>

VOLUME ["/var/lib/cassandra"]
ENTRYPOINT ["/bin/cassandra-runner.pl"]

COPY install-ubuntu-packages.sh /
RUN /bin/sh /install-ubuntu-packages.sh

COPY install-cassandra-tarball.sh /
RUN /bin/sh /install-cassandra-tarball.sh

RUN rm -f /install-ubuntu-packages.sh /install-cassandra-tarball.sh

RUN mkdir -p /root/.ssh /var/lib/cassandra /var/log/cassandra

# create a cassandra user:group & chown
RUN groupadd -g 1337 cassandra
RUN useradd -u 1337 -g cassandra -s /bin/sh -d /var/lib/cassandra cassandra
RUN chown -R cassandra:cassandra /var/lib/cassandra /var/log/cassandra

COPY cassandra-runner.pl /bin/

# SSH, Storage Port, JMX, Thrift, CQL Native, OpsCenter Agent
# Left out: SSL
EXPOSE 22 7000 7199 9042 9160 61621

