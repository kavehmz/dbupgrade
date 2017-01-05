#!/bin/bash

cd /home/projects/src/github.com/kavehmz/dbupgrade/plan/

. ./common.sh
. ./server.sh
. ./migrate.sh
. ./steps.sh

set -x
EBS_SIZE=1500
EBS_TYPE=gp2
EBS_IOPS=10000

# Setup Master
MASTER_REGION=us-east-1
MASTER_ZONE=us-east-1b
MASTER_NAME=part01-dbpri01-9.6
MASTER_CONFIG=part01-dbpri02
MASTER_REPLICA_MASTER=part01-dbpri01

# Setup US Slave
SLAVE01_REGION=us-east-1
SLAVE01_ZONE=us-east-1a
SLAVE01_NAME=part01-dbpri02-9.6
SLAVE01_CONFIG=part01-dbpri02
SLAVE01_REPLICA_MASTER=UNKNOWN
set +x
