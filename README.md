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

### Running a Cluster

When starting nodes for the first time, the cluster name will need to be set. This
can be accomplished by pre-pushing a cassandra.yaml to $VOLUME/conf/cassandra.yaml
or by passing the -name "NAME" option to the container on startup.

```
docker run -d tobert/cassandra cassandra -name "Test Cluster"

# same thing, less typing
docker run -d tobert/cassandra -name "Test Cluster"
```

Adding nodes to the cluster simply requires setting the seeds. Again, this can be
done via cassandra.yaml or using a CLI argument to the container.

```
docker run -d tobert/cassandra \
  -name "Test Cluster" \
  -seeds $IP_OF_SEED_NODE_OR_NODES
```

### Accessing Tools

The usual Cassandra tooling is available via both the entrypoint and docker exec.

```sh
docker run -it --rm tobert/cassandra cqlsh $HOST
docker run -it --rm tobert/cassandra nodetool -h $HOST status
docker run -it --rm tobert/cassandra cassandra-stress ...

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
