This is an intermediate dockerfile that I use to build up an
image with all the time-consuming bits done. I renamed my ubuntu
image to raring_base and tag the output of building this as raring
so I don't have to worry about accidentally committing a broken dockerfile.

docker tag 463ff6be4238 raring_base
docker rmi ubuntu:raring

This also means I can keep my proxy settings here without causing
problems for others wanting to mess with this.

sudo docker build -t raring .
