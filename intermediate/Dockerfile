FROM       raring_base
MAINTAINER Al Tobey <atobey@datastax.com>

ENV http_proxy http://192.168.10.4:3128

RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get install -y libyaml-perl busybox dropbear net-tools openjdk-7-jre-headless libjna-java
RUN apt-get clean

