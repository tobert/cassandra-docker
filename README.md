cassandra-docker
================

Dockerfile &amp; scripts to run Cassandra in Docker

### Running

A Docker image with Datastax Community Edition / Cassandra 2.0.8 is published
to tobert/cassandra. It expects a volume to be assigned. This volume will be
written to!

```
docker pull tobert/cassandra
mkdir /srv/cassandra
docker run -d -v /srv/cassandra:/var/lib/cassandra tobert/cassandra
```

### Building

`sudo docker build -t cassandra .`

### Running a Single Node

While it is possible to run a node without a volume attached,
this is not recommended. Most COW filesystems used by Docker
will not perform well under database workloads.

`docker run -v /var/lib/cassandra tobert/cassandra`

#### With SSH

_Note: the ssh support will probably go away soon (to be replaced by nsenter)._

When the container starts up, cassandra-runner.pl will automatically
start a dropbear ssh daemon. Since it binds by IP you can find the
IP in `ps` output or more accurately by looking at $VOLUME/etc/listen_address.txt

One way to get an authorized_keys file into the container
is with a volume. Using your ~/.ssh/authorized_keys works fine like
this.

The other way is to create an `authorized_keys` file in `$VOLUME/etc/authorized_keys`
before booting and it will get copied to /root/.ssh for you.

```
docker run -v $HOME/.ssh:/root/.ssh:ro -v /var/lib/cassandra tobert/cassandra
ssh root@$(cat /var/lib/cassandra/etc/listen_address.txt)
```

### Running a Cluster

The whole point of this config is to make it easy to run clusters on
a single machine for development purposes. The trickiest part is
getting the seed into following nodes. This can be done without
modifying images, as the wrapper script will take care of editing
the configuration for you if you pass in the SEEDS environment variable.

Setting a memory limit is also important for clusters since Cassandra
will happily eat up 50% of RAM for each instance unless you limit it.

```
mkdir -p /var/lib/{cass1,cass2,cass3}
docker run -d -m 1500m -v /var/lib/cass1:/var/lib/cassandra tobert/cassandra
sleep 5
# get the IP of the new container
IP=$(< /var/lib/cass1/etc/listen_address.txt)
docker run -d -m 1500m -e SEEDS=$IP -v /var/lib/cass2:/var/lib/cassandra tobert/cassandra
docker run -d -m 1500m -e SEEDS=$IP -v /var/lib/cass3:/var/lib/cassandra tobert/cassandra
nodetool -h $IP status
```

### Advanced Configuration

There are a few ways to get more control over the Cassandra instance without
messing with the Docker image.

#### Setting JVM Memory Usage

Option A: set the `MAX_HEAP_SIZE` and `HEAP_NEWSIZE` environment variables. These
must be acceptable values for -Xmx and -Xmn respectively. They will be persisted
in the volume under etc/env.sh automatically, so these flags are only required
the first time.

```
docker run -m 2g -e MAX_HEAP_SIZE=1G -e HEAP_NEWSIZE=200M -v /var/lib/cass1:/var/lib/cassandra tobert/cassandra
```

Option B: create a env.sh file in the state dir, which is the `etc` directory
under your volume.

```
cat > /var/lib/cass1/etc/env.sh <<EOF
MAX_HEAP_SIZE=1500M
HEAP_NEWSIZE=256M
EOF
docker run -d -m 2g -v /var/lib/cass1:/var/lib/cassandra tobert/cassandra
```
