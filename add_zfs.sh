#!/bin/bash

#install zfs repo
yum install -y http://download.zfsonlinux.org/epel/zfs-release.el7_8.noarch.rpm
#import gpg key
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux
#install DKMS style packages for correct work ZFS
yum install -y epel-release kernel-devel zfs
#change ZFS repo
yum-config-manager --disable zfs
yum-config-manager --enable zfs-kmod
yum install -y zfs
#Add kernel module zfs
modprobe zfs
#install wget
yum install -y wget

# create 4 pools raid1
zpool create otus1 mirror /dev/sda /dev/sdb
zpool create otus2 mirror /dev/sdc /dev/sdd
zpool create otus3 mirror /dev/sde /dev/sdf
zpool create otus4 mirror /dev/sdg /dev/sdh
# Добавим разные алгоритмы сжатия в каждую файловую систему
zfs set compression=lzjb otus1
zfs set compression=lz4 otus2
zfs set compression=gzip-9 otus3
zfs set compression=zle otus4


