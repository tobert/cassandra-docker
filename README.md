cassandra-docker
================

Cassandra in Docker

### Running

This Docker image places all of the important Cassandra data, including
data, commitlog, and configuration in the /data directory inside the container.
For any data you might care about, /data *must* be mapped as a volume when
you `docker run`. For situations where the data is disposable (e.g. tests),
the volume may be omitted.

```
docker pull tobert/cassandra
mkdir /srv/cassandra
docker run -d -v /srv/cassandra:/data tobert/cassandra
```

The above commands will run Cassandra in the default Docker networking with
the standard ports mapped. If you don't care about the data (e.g. for testing)
the -v/--volume may be ommitted.

### Clustering: one host

Running a cluster on a single host using the standard Docker networking is straightforward.

When starting nodes for the first time, the cluster name will need to be set. This
can be accomplished by pre-pushing a cassandra.yaml to $VOLUME/conf/cassandra.yaml
or by passing the -name "NAME" option to the container on startup.

Caveat: some clients will not work from remote hosts when connecting to the mapped ports
since they will not be able to connect to the private IPs assigned to the containers.

```
# start the cassandra container and capture its ID for later use
ID=$(docker run -d tobert/cassandra -name "Test Cluster")
```

Adding nodes to the cluster simply requires setting the seeds. Again, this can be
done via cassandra.yaml or using a CLI argument to the container.

```
IP=$(docker inspect -f '{{ .NetworkSettings.IPAddress }}' $ID)
docker run -d tobert/cassandra \
  -name "Test Cluster" \
  -seeds $IP
```

### Clustering: multiple hosts

The easiest way to run across multiple Docker hosts is with `--net=host`. This tells
Docker to leave the container's networking in the host's namespace.

```
docker run -d --net=host tobert/cassandra -name "My Cluster"
```

Once the first (seed) node is up, you can start adding peers. In the example below,
$IP is the IP of the first node started.

```
docker run -d --net=host tobert/cassandra -name "My Cluster" -seeds $IP
```

### Accessing Tools

The usual Cassandra tooling is available via both the entrypoint and docker exec.

```sh
docker run -it --rm tobert/cassandra cqlsh $HOST
docker run -it --rm tobert/cassandra nodetool -h $HOST status
docker run -it --rm tobert/cassandra cassandra-stress ...
# or
docker exec -it $ID cqlsh
docker exec -it $ID nodetool status
docker exec -it $ID cassandra-stress ...
```

### Memory Settings

You may set memory limits on the container using the -m switch, but this
will cause problems if -m is smaller than the heap size configured in
$VOL/conf/sproks/cassandra.yaml. All of the JVM arguments for Cassandra
are stored there for this Docker image.

### Building

It's a simple process. Build the entrypoint then build the image.

```sh
# get sprok and goyaml
go get -u github.com/tobert/sprok
go get -u gopkg.in/yaml.v2
# build the entrypoint binary
go build
# build the Docker image
sudo docker build .
```
