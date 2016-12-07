#!/bin/bash
# create_instance name ip-id
create_instance() {
    echo "creating instance"
    R=$(aws ec2 run-instances --image-id ami-e0efab88 --count 1 --instance-type c4.8xlarge --key-name cr-dbpri02_clientdb_upgradetest --security-group-ids sg-14146d69 --subnet-id subnet-ccec86bb  --associate-public-ip-address --placement AvailabilityZone=us-east-1a,GroupName=clientdb_upgrade)
    INSTANCEID=$(echo "$R"|grep InstanceId|cut -d'"' -f 4)
    aws ec2 create-tags --resources $INSTANCEID --tags Key=Name,Value=$1
    sleep 20
    aws ec2 associate-address --instance-id $INSTANCEID --allocation-id $2
    echo "ready"
}

attach_volume() {
    ERR=''
    aws ec2 describe-instances --instance-ids $INSTANCEID|grep -q running || ERR=1
    
    if [ "$ERR" == "" ]
    then
        echo "creating volume"
        R=$(aws ec2 create-volume --region us-east-1 --availability-zone us-east-1a --size $1 --volume-type $2 --iops $3)
        VOLUMEID=$(echo "$R"|grep VolumeId|cut -d'"' -f 4)
        sleep 10
        aws ec2 create-tags --resources $VOLUMEID --tags Key=Name,Value=$4
        aws ec2 attach-volume --volume-id $VOLUMEID --instance-id $INSTANCEID --device /dev/$5
    else
        echo "instance $INSTANCEID not ready"
    fi
}

attach_replica_volume() {
    echo "attaching replica volume"
    VOLUMEID=$(aws ec2 describe-volumes --filters "Name=tag:Name,Values=$1"|grep VolumeId|head -n1|cut -d'"' -f 4)
    echo "$VOLUMEID"
    aws ec2 attach-volume --volume-id $VOLUMEID --instance-id $INSTANCEID --device /dev/sdz
    sleep 5
}

detach_replica_volume() {
    echo "attaching replica volume"
    VOLUMEID=$(aws ec2 describe-volumes --filters "Name=tag:Name,Values=$1"|grep VolumeId|head -n1|cut -d'"' -f 4)
    echo "$VOLUMEID"
    aws ec2 detach-volume --volume-id $VOLUMEID
}

sh() {
    IP=$(aws ec2 describe-instances --instance-ids $INSTANCEID|grep PublicIp|head -n1|cut -d'"' -f 4)
    ssh -i ~/.ssh/cr-dbpri02_clientdb_upgradetest.pem admin@$IP $1
}

# scp_config configed_based replicated_from
scp_config() {
    IP=$(aws ec2 describe-instances --instance-ids $INSTANCEID|grep PublicIp|head -n1|cut -d'"' -f 4)

    cat << EOF >> /tmp/$1-recovery.conf
standby_mode = 'on'
recovery_target_timeline='latest'
primary_conninfo = 'application_name=$1-9.6 user=replicator password=Get121thid host=$2 port=5432 sslmode=require sslcompression=1 krbsrvname=postgres'
EOF

    scp -i ~/.ssh/cr-dbpri02_clientdb_upgradetest.pem /home/projects/src/github.com/regentmarkets/chef/cookbooks/binary_wrapper_postgresql_clientdb/templates/production/postgresql.conf.erb admin@$IP:/tmp/  
    scp -i ~/.ssh/cr-dbpri02_clientdb_upgradetest.pem /home/projects/src/github.com/regentmarkets/chef/cookbooks/binary_wrapper_postgresql_clientdb/files/default/custom/$1.conf admin@$IP:/tmp/  
    scp -i ~/.ssh/cr-dbpri02_clientdb_upgradetest.pem /tmp/$1-recovery.conf admin@$IP:/tmp/recovery.conf


    sh "sudo cp /tmp/postgresql.conf.erb /etc/postgresql/9.3/main/postgresql.conf"
    sh "sudo cp /tmp/$1.conf /etc/postgresql/9.3/main/pg_custom.conf"
    sh "sudo cp /tmp/recovery.conf /var/lib/postgresql/9.3/main/recovery.conf"

    sh "sudo bash -c 'echo \"host  replication  replicator  172.0.0.0/8  md5\" >> /etc/postgresql/9.3/main/pg_hba.conf'"

    sh "sudo chown postgres:postgres /etc/postgresql/9.3/main/ -R"
}