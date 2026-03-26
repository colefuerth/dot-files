#!/usr/bin/env bash

# SatcomDirect Jail

# build a docker container with all the required dependencies

CONTAINER="jail"

docker build \
  --build-arg UID=$(id -u) \
  --build-arg USERNAME=$(whoami) \
  -t $CONTAINER .
