#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

path=$1
for i in  $(awk '/falcon/{print $1}' $path/host.log)
do
  {
    ssh $i mkdir /mnt/openfalcon
    scp $path/mysql/* $i:/mnt/openfalcon/
    scp $path/openfalcon/* $i:/mnt/openfalcon/
    scp $path/cache/redis.tar.gz $i:/mnt/openfalcon/
    scp $path/cache/bin.tar.gz $i:/mnt/openfalcon/
    ssh $i tar '-xf /mnt/openfalcon/bin.tar.gz -C /etc/init.d/'
    ssh $i tar '-xf /mnt/openfalcon/redis.tar.gz -C /etc/'
    
    ssh $i bash /mnt/openfalcon/bulid_falcon.sh 0
    if [ $? -ne 0 ]; then
        echo openfalcon is error
        exit 1
    fi
  }
done
