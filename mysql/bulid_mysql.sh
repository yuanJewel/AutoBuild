#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

mysql_password='Yu06078'
# install mysql
if [ $1 -eq 0 ];then
    cd /mnt/mysql
    yum -y install perl-JSON  perl-Data-Dumper perl-Time-HiRes mysql-community-*
    if [ $? -ne 0 ];then
        echo mysql cannot start
        exit 2
    fi

    systemctl restart mysqld
    if [ $? -ne 0 ];then
        echo mysql cannot start
        exit 3
    fi

    systemctl enable mysqld
    if [ $? -ne 0 ];then
        echo mysql cannot enable
        exit 4
    fi

    sed -i '/\[mysqld\]/avalidate_password_policy=0' /etc/my.cnf
    sed -i '/\[mysqld\]/avalidate_password_length=1' /etc/my.cnf
    systemctl restart mysqld
    pass=$(awk '/temporary password/{print $11}' /var/log/mysqld.log)

    mysql -uroot -p$pass --connect-expired-password -e'\
        alter user root@"localhost" identified by "'$mysql_password'"'
    if [ $? -ne 0 ];then
        echo mysql init is error
        exit 6
    fi

# build mysql master
elif [ $1 -eq 1 ];then
    ip=$(ifconfig | awk '/inet/{print $2}' | sed -n '1p')
    sed -i '/\[mysqld\]/alog_bin=master' /etc/my.cnf
    sed -i '/\[mysqld\]/abinlog_format="mixed"' /etc/my.cnf
    sed -i '/\[mysqld\]/aserver_id='${ip##*.} /etc/my.cnf
    systemctl restart mysqld
    if [ $? -ne 0 ];then
        echo mysql master is error
        exit 7
    fi

    mysql -uroot -p${mysql_password} -e'\
        grant replication slave on *.* to repluser@"%" identified by "123456"'

    mysql -uroot -p${mysql_password} -e'\
        reset master'

# bulid mysql slave
elif [ $1 -eq 2 ];then
    ip=$(ifconfig | awk '/inet/{print $2}' | sed -n '1p')
    sed -i '/\[mysqld\]/aserver_id='${ip##*.} /etc/my.cnf
    systemctl restart mysqld
    mysql -uroot -p${mysql_password} -e'\
        change master to master_host="'$2'", master_user="repluser", master_password="123456",\
        master_log_file="master.000001", master_log_pos=154'

    mysql -uroot -p${mysql_password} -e'\
        start slave'
    if [ $? -ne 0 ];then
        echo mysql slave is error
        exit 8
    fi
  
else
    echo cannot start mysql!
    exit 1
fi
