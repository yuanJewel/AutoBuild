#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

path=$1
cd $path
cp $path/conf/yum.repo .
sed -i 's/IP/'$(awk -F= '/IP/{print $2}' $path/main.conf | sed 's/ //g')'/' yum.repo

for i in  $(awk '{print $1}' $path/host.log)
do
    scp yum.repo $i:/etc/yum.repos.d/
    scp $path/conf/start $i:/root/
    ssh $i source /root/start
    if [ $? -ne 0 ];then
        echo yum start is error
        exit 1
    fi
    ssh $i systemctl restart network
    if [ $? -ne 0 ];then
        echo network start is error
        exit 2
    fi
    ssh $i rm -f /root/start
done
rm -f yum.repo
