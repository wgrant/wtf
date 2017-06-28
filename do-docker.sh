#!/bin/bash

docker create --name xenial -v `pwd`:`pwd` ubuntu:xenial
docker start xenial
docker exec -t xenial -w `pwd` $1
