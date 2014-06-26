FROM       ubuntu:raring
MAINTAINER Al Tobey <atobey@datastax.com>

VOLUME ["/var/lib/cassandra"]
ENTRYPOINT ["/bin/cassandra-runner.pl"]

ENV http_proxy http://192.168.10.4:3128

COPY datastax-repo_key /root/
COPY datastax-community.sources.list /etc/apt/sources.list.d/
COPY cassandra-runner.pl /bin/
RUN apt-key add /root/datastax-repo_key
RUN rm -f /root/datastax-repo_key
RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get install -y libyaml-perl busybox dropbear net-tools openjdk-7-jre-headless libjna-java dsc20
RUN apt-get clean
RUN mkdir -p /root/.ssh

# storage port, JMX, Thrift, CQL Native
EXPOSE 7000 7199 9160 9042

