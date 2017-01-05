#!/bin/bash

create_instance() {
    REGION=$1
    ZONE=$2
    NAME=$3

    echo "creating instance"
    SECURITYID=$(aws --region=$REGION ec2 describe-security-groups --filters "Name=group-name,Values=clientdb_9.6"|grep GroupId|head -n1|cut -d'"' -f 4)
    IMAGEID=$(aws --region=$REGION ec2 describe-images --filters "Name=description,Values=Debian wheezy amd64" "Name=virtualization-type,Values=hvm" "Name=owner-id,Values=379101102735"|grep ImageId|head -n1|cut -d'"' -f 4)
    VPCID=$(aws --region=$REGION ec2 describe-vpcs --filter "Name=tag:Name,Values=binary_production"|grep VpcId|head -n1|cut -d'"' -f 4)
    SUBNETID=$(aws --region=$REGION ec2 describe-subnets --filters "Name=vpc-id,Values=$VPCID" "Name=availabilityZone,Values=$ZONE" "Name=tag:Name,Values=$ZONE-public"|grep SubnetId|head -n1|cut -d'"' -f 4)

    R=$(aws --region $REGION ec2 run-instances --image-id $IMAGEID --count 1 --instance-type c4.8xlarge --key-name clientdb_9.6 --security-group-ids $SECURITYID  --subnet-id $SUBNETID --associate-public-ip-address --placement "AvailabilityZone=$ZONE")
    INSTANCEID=$(echo "$R"|grep InstanceId|cut -d'"' -f 4)
    INSTANCEIPPRIV=$(echo "$R"|grep PrivateIpAddress|tail -n1|cut -d'"' -f 4)

    aws --region $REGION ec2 wait  instance-running  --instance-ids $INSTANCEID
    echo "instance $NAME [$INSTANCEID] running."
    aws --region $REGION ec2 create-tags --resources $INSTANCEID --tags Key=Name,Value=$NAME

    INSTANCEIP=$(aws --region $REGION ec2 describe-instances --instance-ids $INSTANCEID|grep PublicIp|head -n1|cut -d'"' -f 4)

    echo "Instance IP for $NAME: $INSTANCEIP, $INSTANCEIPPRIV"

    until sh $REGION $NAME exit
    do
        echo "connection not ready yet"
    done

    echo "IP Attached"
}

add_ip_to_sec_group() {
    SRV_REGION=$1
    SRV_NAME=$2
    GROUP_REGION=$3

    IP=$(ip $SRV_REGION $SRV_NAME)
    SECURITYID=$(aws --region=$GROUP_REGION ec2 describe-security-groups --filters "Name=group-name,Values=clientdb_9.6"|grep GroupId|head -n1|cut -d'"' -f 4)

    aws --region $GROUP_REGION ec2 authorize-security-group-ingress --group-id $SECURITYID --protocol tcp --port 5432 --cidr $IP/32
    aws --region $GROUP_REGION ec2 authorize-security-group-ingress --group-id $SECURITYID --protocol tcp --port 22 --cidr $IP/32
}

attach_volume() {
    REGION=$1
    ZONE=$2
    SIZEGB=$3
    TYPE=$4
    IOPS=$5
    DISKNAME=$6
    ATTACHPOINT=$7

    echo "creating volume"
    if [ "$TYPE" == 'io1' ]
    then
        R=$(aws ec2 create-volume --region $REGION --availability-zone $ZONE --size $SIZEGB --volume-type $TYPE --iops $IOPS)
    else
        R=$(aws ec2 create-volume --region $REGION --availability-zone $ZONE --size $SIZEGB --volume-type $TYPE)
    fi
    VOLUMEID=$(echo "$R"|grep VolumeId|cut -d'"' -f 4)

    aws  --region $REGION ec2 wait  volume-available --volume-ids $VOLUMEID
    echo "volume $DISKNAME [$VOLUMEID] ready"

    aws  --region $REGION ec2 create-tags --resources $VOLUMEID --tags Key=Name,Value=$DISKNAME
    aws  --region $REGION ec2 attach-volume --volume-id $VOLUMEID --instance-id $INSTANCEID --device /dev/$ATTACHPOINT
}

sh() {
    REG=$1
    NM=$2
    CMD=$3

    IP=$(aws --region $REG ec2 describe-instances --filters "Name=tag:Name,Values=$NM" "Name=instance-state-name,Values=running"|grep PublicIpAddress|head -n1|cut -d'"' -f 4)

    echo "Running $CMD"

    ssh -i ~/.ssh/clientdb_9.6.pem admin@$IP $CMD
}


ip() {
    REGION=$1
    NAME=$2
    IP=$(aws --region $REGION ec2 describe-instances --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=running"|grep PublicIpAddress|head -n1|cut -d'"' -f 4)
    echo -n $IP
}

tail_log() {
    REGION=$1
    NAME=$2
    FILE=$3
    SIZE=$4
    sh $REGION $NAME 'dd if=/tmp/basebackup.log of=/dev/stdout bs=1 count=60 skip=$(( $(stat --printf="%s" /tmp/basebackup.log) - 10 ))'
}
