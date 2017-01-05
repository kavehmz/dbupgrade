#!/bin/bash
# setup name master_snapshot config master_dns server_ip_id
setup_instance() {
    NAME=$1
    MASTERCONFIG=$2
    MASTERURL=$3

    REGION=$4
    ZONE=$5

    SIZEGB=$6
    TYPE=$7
    IOPS=$8

    create_instance $REGION $ZONE $NAME 
    attach_volume $REGION $ZONE $SIZEGB $TYPE $IOPS $NAME-disk01 sdf

    sh $REGION $NAME 'sudo bash -c "echo 127.0.0.1 `hostname`  >> /etc/hosts"'

    sh $REGION $NAME "sudo bash -c 'echo \"deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main\" >  /etc/apt/sources.list.d/postgresql.list'"
    sh $REGION $NAME "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8"

    sh $REGION $NAME "sudo apt-get update"
    sh $REGION $NAME "sudo apt-get upgrade -y"
    sh $REGION $NAME "sudo DEBIAN_FRONTEND=noninteractive apt-get install -o Dpkg::Options::='--force-confdef' -t wheezy-backports -y fio rsync tmux"

    sh $REGION $NAME "sudo apt-get install -y postgresql-9.3 postgresql-plperl-9.3 postgresql-9.3-pgq3"
    sh $REGION $NAME "sudo apt-get install -y postgresql-9.6 postgresql-plperl-9.6 postgresql-9.6-pgq3"

    sh $REGION $NAME "sudo pg_dropcluster 9.3 main --stop"
    sh $REGION $NAME "sudo pg_dropcluster 9.6 main --stop"

    sh $REGION $NAME "sudo mkfs.ext4 /dev/xvdf"
    sh $REGION $NAME "sudo mount /dev/xvdf /var/lib/postgresql"

    sh $REGION $NAME "sudo pg_createcluster 9.3 main -- --data-checksums"
    sh $REGION $NAME "sudo pg_createcluster 9.6 main -- --data-checksums"

    sh $REGION $NAME "sudo service postgresql stop"

    sh $REGION $NAME "sudo bash -c 'rm -rf /var/lib/postgresql/9.3/main/*'"

    scp_config $REGION $NAME $MASTERCONFIG $MASTERURL

    sh $REGION $NAME "sudo bash -c 'echo \"hostssl replication replicator 0.0.0.0/0 md5\" >> /etc/postgresql/9.3/main/pg_hba.conf'"

    echo "Run the following on $MASTERURL  before basebackup"
    echo "iptables -A allow_env_nodes -s $INSTANCEIP/32 -p tcp -m tcp --dport 5432 -j ACCEPT"
    echo "echo 'hostssl    replication    replicator    $INSTANCEIP/32    md5' >>  /etc/postgresql/9.3/main/pg_hba.conf"
    echo "/etc/init.d/postgresql reload 9.3"
}

setup_basebackup() {
    REGION=$1
    NAME=$2
    MASTERIP=$3
    IP=$(aws --region $REGION ec2 describe-instances --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=running"|grep PublicIpAddress|head -n1|cut -d'"' -f 4)

    echo "starting basebackup and tailing logs. You can ctrl+c the tail of logs"

    sh $REGION $NAME "sudo tmux  new-session -s basebackup -d '/usr/lib/postgresql/9.3/bin/pg_basebackup -D /var/lib/postgresql/9.3/main -w -R -Xs -P -v -h $MASTERIP -p 5432 -U replicator >  /tmp/basebackup.log 2>&1;chown postgres:postgres /var/lib/postgresql/ -R;sudo /etc/init.d/postgresql start 9.3'"
    sh $REGION $NAME "sudo tail -f /tmp/basebackup.log"
}

scp_config() {
    REGION=$1
    NAME=$2
    MASTERCONFIG=$3
    MASTERURL=$4

    # content removed
}
