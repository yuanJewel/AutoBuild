#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

path=$1
for i in  $(awk '/mysql/{print $1}' $path/host.log)
do
  {
    ssh $i mkdir /mnt/mysql
    scp $path/mysql/* $i:/mnt/mysql/
    ssh $i bash /mnt/mysql/bulid_mysql.sh 0
    if [ $? -ne 0 ]; then
        echo mysql is error
        exit 1
    fi
  } &
done
wait

# determines whether master-slave synchronization needs to be configured
if [ $(sed -n '/mysql/p' $path/host.log | wc -l) -lt 2 ];then
    sed -i '/startMasterslave/cstartMasterslave = 0' $path/main.conf
    echo your mysql number cannot enough to do master_and_slave
    exit 2
fi

if [ $(awk -F= '/startMasterslave/{print $2}' $path/main.conf | sed 's/ //g') -ne 0 ];then
    master_ip=$(awk '$3==1' $path/host.log | awk '/mysql/{print $1}')

    # Configure the main library 
    ssh $master_ip bash /mnt/mysql/bulid_mysql.sh 1
    if [ $? -ne 0 ]; then
        echo mysql master is error
        exit 3
    fi

    # Configure the slave library 
    for i in $( awk '$3>1' $path/host.log | awk '/mysql/{print $1}')
    do
        ssh $i bash /mnt/mysql/bulid_mysql.sh 2 $master_ip
        if [ $? -ne 0 ]; then
            echo mysql slave is error
            exit 4
        fi
    done
fi

