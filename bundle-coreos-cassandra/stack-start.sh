#!/bin/bash

heat stack-create $1 -f bundle-coreos-cassandra.heat.yml
