#!/bin/sh

docker --version >&2

# set the dockeronhost group id in the container to the group id from the host
DOCKER_GROUP=$(stat -c '%g' /var/run/docker.sock)
# try to modify an existing group id
groupmod --non-unique --gid ${DOCKER_GROUP} dockeronhost
# if the group doesn't exist yet, create it
if [ $? -eq 4 ]; then groupadd --non-unique --gid ${DOCKER_GROUP} dockeronhost; fi

# compatibility: initial volume setup
chown node:node /app/cache
chown node:node /app/compiles
chown node:node /app/db

# make synctex available for remount in compiles
cp /app/bin/synctex /app/bin/synctex-mount/synctex

exec runuser -u node -- "$@"
