#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

path=$1
cd $path

for i in  $(awk '{print $1}' $path/host.log)
do
    scp $path/cache/* $i:/mnt
    ssh $i 'tar -xf /mnt/bin.tar.gz -C /etc/init.d/'
    ssh $i 'tar -xf /mnt/redis.tar.gz -C /etc/'
    ssh $i 'rm -f /etc/redis/status/redis_6379.pid '
done
