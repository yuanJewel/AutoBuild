#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

path=$1
sed -i '/^cpu/ccpu='$(awk -F= '/cpunum/{print $2}' $path/main.conf | sed 's/ //g') $path/nginx/nginx_start

for i in  $(awk '/nginx/{print $1}' $path/host.log)
do
    ssh $i mkdir /nginx
    scp $path/nginx/* $i:/nginx

    # synchronous compilation and installation of nginx
    ssh $i source /nginx/nginx_start &
done
wait

# determine if need to synchronize
if [ $(sed -n '/nginx/p' $path/host.log | wc -l) -lt 2 ];then
    echo your nginx number is not enough to rsync
    sed -i '/startRsync/cstartRsync = 0' $path/main.conf
fi

if [ $(awk -F= '/startRsync/{print $2}' $path/main.conf | sed 's/ //g') -ne 0 ];then
    main_ip=$(awk '$3==1' $path/host.log | awk '/nginx/{print $1}')

    # install the necessary software
    ssh $main_ip yum install -y rsync
    ssh $main_ip source /nginx/nginx_rsync 0 &
    for i in $( awk '$3>1' $path/host.log | awk '/nginx/{print $1}')
    do
        ssh $i yum install -y rsync
        ssh $main_ip source /nginx/nginx_rsync $i &
    done
fi
