FROM       ubuntu:14.04
MAINTAINER Al Tobey <atobey@datastax.com>

VOLUME ["/var/lib/cassandra"]
ENTRYPOINT ["/bin/cassandra-runner.pl"]

RUN apt-get update
RUN apt-get install -y curl libyaml-perl busybox dropbear net-tools openjdk-7-jre-headless java-common libjna-java
RUN apt-get clean

RUN echo '673d3367a7ef686036b335621c1fc8a963ebb2ad apache-cassandra-2.0.10-bin.tar.gz' > apache-cassandra-2.0.10-bin.tar.gz.sha1
RUN curl -O -s http://apache.osuosl.org/cassandra/2.0.10/apache-cassandra-2.0.10-bin.tar.gz
RUN sha1sum --check apache-cassandra-2.0.10-bin.tar.gz.sha1
RUN tar -xzf apache-cassandra-2.0.10-bin.tar.gz -C /opt
RUN rm -f apache-cassandra-2.0.10-bin.tar.gz

RUN ln -s /opt/apache-cassandra-2.0.10 /opt/cassandra

RUN mkdir -p /root/.ssh /var/lib/cassandra /var/log/cassandra

RUN groupadd -g 1337 cassandra
RUN useradd -u 1337 -g cassandra -s /bin/sh -d /var/lib/cassandra cassandra
RUN chown -R cassandra:cassandra /var/lib/cassandra /var/log/cassandra

COPY cassandra-runner.pl /bin/

# SSH, Storage Port, JMX, Thrift, CQL Native, OpsCenter Agent
# Left out: SSL
EXPOSE 22 7000 7199 9042 9160 61621

