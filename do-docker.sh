#!/bin/bash

docker run -d --name xenial -v `pwd`:`pwd` -ti ubuntu:xenial bash
docker exec xenial bash -c "cd `pwd`; $1"
