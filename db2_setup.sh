#!/bin/bash

#setup DB2 on RHEL7.4
$USER=rhel
$PASSWD=badpassword
$DB=hr
$db2_url="https://db2setupforazure.file.core.windows.net/db2software/DB2_Svr_11.5_Linux_x86-64.tar.gz"

#pre-reqs
yum update -y
yum install -y gcc gcc-c++ libstdc++*.i686 numactl sg3_utils kernel-devel compat-libstdc++-33.i686 compat-libstdc++-33.x86_64 pam-devel.i686 pam-devel.x86_64

#mdadm
yum -y install mdadm
mdadm --create --verbose /dev/md0 --level=10 --raid-devices=4 /dev/sdc /dev/sdd /dev/sde /dev/sdf
mkdir -p /etc/mdadm
mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
mkfs.ext4 -F /dev/md0
mkdir -p /db2
mount /dev/md0 /db2/
grep -q "\/dev\/md0" /etc/fstab && echo '/dev/md0 /db2 ext4 defaults,nofail,discard 0 0' | sudo tee -a /etc/fstab

#download DB2 11.1 from IBM
wget -nv $db2_url -O DB2_Svr_11.5_Linux_x86-64.tar.gz

tar -zxvf DB2_Svr_11.5_Linux_x86-64.tar.gz -C /tmp/

#install db2 - approx. 10 minutes
/tmp/server_t/db2_install -b /db2/  -y -n -p SERVER

#open port
firewall-offline-cmd --zone=public --add-port=50000/tcp
systemctl enable firewalld
systemctl restart firewalld

#create user 
adduser $USER
echo $PASSWD | sudo passwd $USER --stdin

#create instance
/db2/instance/db2icrt -u $USER $USER

#start instance as user
chmod +x /db2/adm/db2start
su - $USER -c "/db2/adm/db2start"

#create a database - approx 7 minutes
chown -R $USER /db2 
su - $USER -c "mkdir -p /db2/db; source ~/sqllib/db2profile; db2 create database $DB on /db2/db"
