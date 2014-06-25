cassandra-docker
================

Dockerfile &amp; scripts to run Cassandra in Docker

### Building

`sudo docker build -t dsc20 .`

### Running a Single Node

While it is possible to run a node without a volume attached,
this is not recommended. Most COW filesystems used by Docker cannot
provide good performance for database workloads.

`docker run -v /var/lib/cassandra dsc20`

#### With SSH

When the container starts up, cassandra-runner.pl will automatically
start a dropbear ssh daemon. Since it binds by IP you can find the
IP in `ps` output or more accurately by looking at $VOLUME/etc/listen_address.txt

One way to get an authorized_keys file into the container
is with a volume. Using your ~/.ssh/authorized_keys works fine like
this.

The other way is to create an `authorized_keys` file in `$VOLUME/etc/authorized_keys`
before booting and it will get copied to /root/.ssh for you.

```
docker run -v $HOME/.ssh:/root/.ssh:ro -v /var/lib/cassandra dsc20
ssh root@$(cat /var/lib/cassandra/etc/listen_address.txt)
```

### Running a Cluster

The whole point of this config is to make it easy to run clusters on
a single machine for development purposes. The trickiest part is
getting the seed into following nodes. This can be done without
modifying images, as the wrapper script will take care of editing
the configuration for you if you pass in the SEEDS environment variable.

```
mkdir -p /var/lib/{cass1,cass2,cass3}
docker run -v /var/lib/cass1:/var/lib/cassandra dsc20
sleep 5
# get the IP of the new container
IP=$(< /var/lib/cass1/etc/listen_address.txt)
docker run -e SEEDS=$IP -v /var/lib/cass2:/var/lib/cassandra dsc20
docker run -e SEEDS=$IP -v /var/lib/cass3:/var/lib/cassandra dsc20
```

