#!/bin/bash

docker run --name xenial -v `pwd`:`pwd` -w `pwd` ubuntu:xenial $1
docker start -a xenial
