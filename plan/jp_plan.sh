# mx-dbpri02

# mx-dbpri01-9.6 (rep mx-dbpri02)
# mx-dbpri02-9.6 (rep mx-dbpri01-9.6)


create_instance mx-dbpri01-9.6
attach_volume 50 io1 500 mx-dbpri01-9.6-disk01 sdf
attach_volume 50 io1 500 mx-dbpri01-9.6-disk02 sdg
attach_volume 50 io1 500 mx-dbpri01-9.6-disk03 sdh
attach_volume 50 io1 500 mx-dbpri01-9.6-disk04 sdi

sh "sudo bash -c 'echo \"deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main\" >  /etc/apt/sources.list.d/postgresql.list'"
sh "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8"

sh "sudo apt-get update"
sh "sudo apt-get install fio mdadm rsync tmux"

sh "sudo apt-get install postgresql-9.3 postgresql-plperl-9.3 postgresql-9.3-pgq3"
sh "sudo apt-get install postgresql-9.6 postgresql-plperl-9.6 postgresql-9.6-pgq3"

sh "sudo pg_dropcluster 9.3 main --stop"
sh "sudo pg_dropcluster 9.6 main --stop"

sh "sudo mdadm --create /dev/md0 --level=0 --chunk=64 --raid-devices=4 /dev/xvdf /dev/xvdg /dev/xvdh /dev/xvdi"
sh "sudo mkfs.ext4 /dev/md0"

sh "sudo mount /dev/md0 /var/lib/postgresql"

sh "sudo pg_createcluster 9.3 main"
sh "sudo pg_createcluster 9.6 main"

sh "sudo service postgresql stop"

attach_replica_volume upgradetest-mx-dbpri02
sh "sudo mount /dev/xvdz /mnt"

sh "sudo rsync -a --delete /mnt/ /var/lib/postgresql/9.3/main/"

# start and catch up at this point
sh "sudo service postgresql start 9.3"

create_instance() {
    echo "creating instance"
    R=$(aws ec2 run-instances --image-id ami-e0efab88 --count 1 --instance-type c4.8xlarge --key-name cr-dbpri02_clientdb_upgradetest --security-group-ids sg-14146d69 --subnet-id subnet-ccec86bb  --associate-public-ip-address --placement AvailabilityZone=us-east-1a,GroupName=clientdb_upgrade)
    INSTANCEID=$(echo "$R"|grep InstanceId|cut -d'"' -f 4)
    aws ec2 create-tags --resources $INSTANCEID --tags Key=Name,Value=$1
    sleep 20
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