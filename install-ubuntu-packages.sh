#!/bin/sh
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -x

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y software-properties-common
apt-get -y -o Dpkg::Options::='--force-confold' dist-upgrade
apt-get clean
# install oracle java from PPA
add-apt-repository ppa:webupd8team/java -y
apt-get update
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
apt-get -y install oracle-java8-set-default && apt-get clean
update-java-alternatives -s java-8-oracle
echo "export JAVA_HOME=/usr/lib/jvm/java-8-oracle" >> ~/.bashrc
apt-get install -y curl busybox python
apt-get clean

rm -f $0
