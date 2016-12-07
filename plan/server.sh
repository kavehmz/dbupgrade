# setup name master_snapshot master
# setup jp-dbpri01-9.6 upgradetest-jp-dbpri02 jp-dbpri02 jp-dbpri02.regentmarkets.com
setup() {
    DBAME=$1
    MASTERSNAPSHOT=$2
    MASTERCONFIG=$3
    MASTERURL=$4
    create_instance $DBAME eipalloc-0a44ae34
    attach_volume 400 io1 20000 $DBAME-disk01 sdf
    attach_volume 400 io1 20000 $DBAME-disk02 sdg
    attach_volume 400 io1 20000 $DBAME-disk03 sdh
    attach_volume 400 io1 20000 $DBAME-disk04 sdi

    sh "sudo bash -c 'echo \"deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main\" >  /etc/apt/sources.list.d/postgresql.list'"
    sh "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8"

    sh "sudo apt-get update"
    sh "sudo apt-get upgrade -y"
    sh "sudo apt-get install -y fio mdadm rsync tmux"

    sh "sudo apt-get install -y postgresql-9.3 postgresql-plperl-9.3 postgresql-9.3-pgq3"
    sh "sudo apt-get install -y postgresql-9.6 postgresql-plperl-9.6 postgresql-9.6-pgq3"

    sh "sudo pg_dropcluster 9.3 main --stop"
    sh "sudo pg_dropcluster 9.6 main --stop"

    sh "sudo mdadm --create /dev/md0 --level=0 --chunk=64 --raid-devices=4 /dev/xvdf /dev/xvdg /dev/xvdh /dev/xvdi"
    sh "sudo mkfs.ext4 /dev/md0"

    sh "sudo mount /dev/md0 /var/lib/postgresql"

    sh "sudo pg_createcluster 9.3 main"
    sh "sudo pg_createcluster 9.6 main"

    sh "sudo service postgresql stop"

    attach_replica_volume $MASTERSNAPSHOT
    sh "sudo mount /dev/xvdz /mnt"

    sh "sudo rsync -a --delete /mnt/ /var/lib/postgresql/9.3/main/"
    sh "sudo chown postgres:postgres /var/lib/postgresql/ -R"

    scp_config $MASTERCONFIG $MASTERURL

    sh "sudo service postgresql restart 9.3"


}
