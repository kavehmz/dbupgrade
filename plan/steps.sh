#!/bin/bash

#### Any change on prodcution server wont be done by this script for safety reasons.
# Make master read-only
# restore_command='/bin/false'
# standby_mode = 'on'

# disable chef

01_setup_master() {
    setup_instance $MASTER_NAME $MASTER_CONFIG $MASTER_REPLICA_MASTER $MASTER_REGION $MASTER_ZONE $EBS_SIZE $EBS_TYPE $EBS_IOPS
}

02_setup_slaves() {
    SLAVE01_REPLICA_MASTER=$(ip $MASTER_REGION $MASTER_NAME)
    setup_instance $SLAVE01_NAME $SLAVE01_CONFIG $SLAVE01_REPLICA_MASTER $SLAVE01_REGION $SLAVE01_ZONE $EBS_SIZE $EBS_TYPE $EBS_IOPS
    add_ip_to_sec_group $SLAVE01_REGION $SLAVE01_NAME $MASTER_REGION
    add_ip_to_sec_group $MASTER_REGION $MASTER_NAME $SLAVE01_REGION
}

03_basebackup_master() {
    setup_basebackup $MASTER_REGION $MASTER_NAME $MASTER_REPLICA_MASTER
}

04_basebackup_slave() {
    SLAVE01_REPLICA_MASTER=$(ip $MASTER_REGION $MASTER_NAME)
    setup_basebackup $SLAVE01_REGION $SLAVE01_NAME $SLAVE01_REPLICA_MASTER
}

05_verify_servers() {
    verify_master $MASTER_REGION $MASTER_NAME
    verify_slave $SLAVE01_REGION $SLAVE01_NAME
}

06_restart_server() {
    restart_93 $MASTER_REGION $MASTER_NAME
    restart_93 $SLAVE01_REGION $SLAVE01_NAME
}

06_stop_servers() {
    stop_93 $MASTER_REGION $MASTER_NAME
    stop_93 $SLAVE01_REGION $SLAVE01_NAME
}

07_verify_checkpoints() {
    verify_checkpoit $MASTER_REGION $MASTER_NAME
    verify_checkpoit $SLAVE01_REGION $SLAVE01_NAME
}

08_migrate_master() {
    migrate_master $MASTER_REGION $MASTER_NAME
}

09_migrate_slaves() {
    migrate_slave $SLAVE01_REGION $SLAVE01_NAME $MASTER_REGION $MASTER_NAME
}

10_verify_servers() {
    verify_master $MASTER_REGION $MASTER_NAME
    verify_slave $SLAVE01_REGION $SLAVE01_NAME
}

11_start_servers() {
    start_96 $SLAVE01_REGION $SLAVE01_NAME
    start_96 $MASTER_REGION $MASTER_NAME
}

12_verify_master() {
    verify_master $MASTER_REGION $MASTER_NAME
}

13_verify_slaves() {
    verify_slave $MASTER_REGION $MASTER_NAME
}

14_detach_ebs() {
    detach_ebs $MASTER_REGION $MASTER_NAME
    detach_ebs $SLAVE01_REGION $SLAVE01_NAME
}

97_ssh_master() {
    sh $MASTER_REGION $MASTER_NAME
}

98_ssh_slave() {
    sh $SLAVE01_REGION $SLAVE01_NAME
}


99_tail_basebackups() {
    tail_log $MASTER_REGION $MASTER_NAME '/tmp/basebackup.log' 20
    tail_log $SLAVE01_REGION $SLAVE01_NAME '/tmp/basebackup.log' 20
}

