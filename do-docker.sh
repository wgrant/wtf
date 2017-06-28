#!/bin/bash

docker run -v `pwd`:`pwd` -w `pwd` ubuntu:xenial $1
