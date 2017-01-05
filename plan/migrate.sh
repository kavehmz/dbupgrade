#!/bin/bash
migrate_master() {
    REGION=$1
    NAME=$2

    echo "Stopping all clusters"
    sh $REGION $NAME 'sudo service postgresql stop'
    sh $REGION $NAME 'sudo rm -rf /var/lib/postgresql/9.3/main/recovery.conf'
    sh $REGION $NAME 'sudo  pg_lsclusters'
    sleep 10

    sh $REGION $NAME "sudo mkdir -p /var/lib/postgresql/upgrade_9.3_to_9.6"
    sh $REGION $NAME "sudo chown postgres:postgres /var/lib/postgresql/upgrade_9.3_to_9.6"
    sh $REGION $NAME "cd /var/lib/postgresql/upgrade_9.3_to_9.6;time sudo -H -u postgres /usr/lib/postgresql/9.6/bin/pg_upgrade \
        -b /usr/lib/postgresql/9.3/bin \
        -B /usr/lib/postgresql/9.6/bin \
        -d /var/lib/postgresql/9.3/main \
        -D /var/lib/postgresql/9.6/main \
        -o ' -c config_file=/etc/postgresql/9.3/main/postgresql.conf' \
        -O ' -c config_file=/etc/postgresql/9.6/main/postgresql.conf' \
        --jobs 64 --link --retain"

    sh $REGION $NAME 'sudo sed -i -e "s/5433/5432/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo sed -i -e "s/#listen_addresses = '\'localhost\''/listen_addresses = '\'*\''/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo sed -i -e "s/#max_wal_senders = 0/max_wal_senders = 20/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo sed -i -e "s/#wal_level = minimal/wal_level = replica/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo sed -i -e "s/#hot_standby = off/hot_standby = on/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo cp /etc/postgresql/9.3/main/pg_hba.conf /etc/postgresql/9.6/main/pg_hba.conf'

    sh $REGION $NAME 'sudo mkdir -p /var/lib/postgresql/upgrade_9.3_to_9.6/backup/'
    sh $REGION $NAME 'sudo mv /etc/postgresql/9.3/main /var/lib/postgresql/upgrade_9.3_to_9.6/backup/9.3_etc'
    sh $REGION $NAME 'sudo service postgresql start 9.6'
    sh $REGION $NAME 'sudo service postgresql stop 9.6 -m fast'
    sh $REGION $NAME 'sudo service postgresql stop 9.6'
}

migrate_slave() {
    REGION=$1
    NAME=$2
    MASTER_RESION=$3
    MASTER_NAME=$4

    sh $REGION $NAME 'sudo service postgresql stop'
    sh $REGION $NAME 'sudo  pg_lsclusters'

    IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=running"|grep PublicIpAddress|head -n1|cut -d'"' -f 4)

    sh $REGION $NAME "sudo cp /var/lib/postgresql/9.3/main/recovery.conf /tmp/"

    sh $REGION $NAME "sudo bash -c 'rm -rf /var/lib/postgresql/9.6/main/*'"
    sh $REGION $NAME "sudo ls -l  /var/lib/postgresql/9.6/main/"

    sh $REGION $NAME 'sudo sed -i -e "s/5433/5432/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo sed -i -e "s/#listen_addresses = '\'localhost\''/listen_addresses = '\'*\''/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo sed -i -e "s/#max_wal_senders = 0/max_wal_senders = 20/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo sed -i -e "s/#wal_level = minimal/wal_level = replica/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo sed -i -e "s/#hot_standby = off/hot_standby = on/" /etc/postgresql/9.6/main/postgresql.conf'
    sh $REGION $NAME 'sudo cp /etc/postgresql/9.3/main/pg_hba.conf /etc/postgresql/9.6/main/pg_hba.conf'

    echo "Rsync from master to slave"
    sh $MASTER_RESION $MASTER_NAME "sudo rsync -e 'ssh -i /home/admin/.ssh/clientdb_9.6.pem -o StrictHostKeyChecking=no' --rsync-path='sudo rsync' --progress -v  --size-only --archive --delete --hard-links /var/lib/postgresql/9.3 /var/lib/postgresql/9.6 admin@$IP:/var/lib/postgresql/"
    echo "Rsync done"

    sh $REGION $NAME 'sudo mkdir -p /var/lib/postgresql/upgrade_9.3_to_9.6/backup/'
    sh $REGION $NAME 'sudo mv /etc/postgresql/9.3/main /var/lib/postgresql/upgrade_9.3_to_9.6/backup/9.3_etc'

    sh $REGION $NAME "sudo cp /tmp/recovery.conf /var/lib/postgresql/9.6/main/"
}

verify_checkpoit() {
    REGION=$1
    NAME=$2
    echo "CHECKPOINTS IN MASTER AND SLAVE MUST MATCH"
    sh $REGION $NAME "sudo /usr/lib/postgresql/9.3/bin/pg_controldata /var/lib/postgresql/9.3/main|grep 'Latest checkpoint location'"

}

verify_cluster() {
    REGION=$1
    NAME=$2
    DUMPCHECK=$3

    echo "checking cluster version"
    sh $REGION $NAME "sudo -su postgres psql -p 5432 clientdb -c 'SELECT version()'"

    echo "DB Time"
    sh $REGION $NAME "sudo -su postgres psql -p 5432 clientdb -c 'select now()'"

    echo "last transaction on db"
    sh $REGION $NAME "sudo -su postgres psql -p 5432 clientdb -c 'select  transaction_time from transaction.transaction order by transaction_time desc limit 1;'"

    if [ "$DUMPCHECK" != "" ]
    then
        echo "Doing a dump check. There should be no error. long operation";
        sh $REGION $NAME "sudo -su postgres /usr/bin/pg_dumpall -p 5432 >/dev/null"
        echo "Dump done";
    fi
}

stop_93() {
    REGION=$1
    NAME=$2
    sh $REGION $NAME "sudo /usr/bin/pg_lsclusters"
    sh $REGION $NAME "sudo /usr/bin/pg_ctlcluster 9.3 main stop"
    sh $REGION $NAME "sudo /usr/bin/pg_lsclusters"
}

restart_93() {
    REGION=$1
    NAME=$2
    sh $REGION $NAME "sudo /usr/bin/pg_lsclusters"
    sh $REGION $NAME "sudo /usr/bin/pg_ctlcluster 9.3 main restart"
    sh $REGION $NAME "sudo /usr/bin/pg_lsclusters"
}


start_96() {
    REGION=$1
    NAME=$2
    sh $REGION $NAME "sudo /usr/bin/pg_lsclusters"
    sh $REGION $NAME "sudo /usr/bin/pg_ctlcluster 9.6 main start"
    sh $REGION $NAME "sudo /usr/bin/pg_lsclusters"
}

verify_master() {
    REGION=$1
    NAME=$2
    DUMPCHECK=$3

    verify_cluster $REGION $NAME $DUMPCHECK

    sh $REGION $NAME "sudo -su postgres psql -p 5432 clientdb -c 'select pg_is_in_recovery() as \"THIS MUST BE FALSE IN MASTER\"'"

    echo "checl replications status"
    sh $REGION $NAME "sudo -su postgres psql -p 5432 clientdb -c 'select application_name,client_addr, state, sent_location, write_location, flush_location, replay_location, sync_priority, sync_state from pg_stat_replication'"
}

verify_slave() {
    REGION=$1
    NAME=$2
    DUMPCHECK=$3

    verify_cluster $REGION $NAME $DUMPCHECK

    sh $REGION $NAME "sudo -su postgres psql -p 5432 clientdb -c 'select pg_is_in_recovery() as \"THIS MUST BE TRUE IN SLAVE\"'"

    echo "checking pg_last_xact_replay_timestamp diff between master and slave. Because of last database create it must be low."
    sh $REGION $NAME "sudo -su postgres psql -p 5432 postgres -c 'select now()-pg_last_xact_replay_timestamp()'"
}

detach_ebs() {
    REGION=$1
    NAME=$2

    sh $REGION $NAME "sudo -su postgres /var/lib/postgresql/upgrade_9.3_to_9.6/analyze_new_cluster.sh"
}

