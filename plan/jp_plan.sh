#!/bin/bash
# jp-dbpri02

# jp-dbpri01-9.6 (rep jp-dbpri02) 34.194.23.132
# jp-dbpri02-9.6 (rep jp-dbpri01-9.6)

# 34.194.23.132 eipalloc-0a44ae34
# 34.193.219.201 eipalloc-705bb14e

create_instance jp-dbpri01-9.6 eipalloc-0a44ae34
attach_volume 400 io1 20000 jp-dbpri01-9.6-disk01 sdf
attach_volume 400 io1 20000 jp-dbpri01-9.6-disk02 sdg
attach_volume 400 io1 20000 jp-dbpri01-9.6-disk03 sdh
attach_volume 400 io1 20000 jp-dbpri01-9.6-disk04 sdi

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

attach_replica_volume upgradetest-jp-dbpri02
sh "sudo mount /dev/xvdz /mnt"

sh "sudo rsync -a --delete /mnt/ /var/lib/postgresql/9.3/main/"
sh "sudo chown postgres:postgres /var/lib/postgresql/ -R"

scp_config jp-dbpri02 jp-dbpri02.regentmarkets.com

sh "sudo service postgresql restart 9.3"

