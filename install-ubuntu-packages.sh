#!/bin/sh

set -e
set -x

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y -o Dpkg::Options::='--force-confold' dist-upgrade
apt-get clean
apt-get install -y curl libyaml-perl busybox dropbear net-tools openjdk-7-jre-headless java-common libjna-java
apt-get clean
