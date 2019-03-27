#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

cd /mnt/openfalcon
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
sed -i '/\[mysqld\]/avalidate_password_length=0' /etc/my.cnf
systemctl restart mysqld
pass=$(awk '/temporary password/{print $11}' /var/log/mysqld.log)

mysql -uroot -p$pass --connect-expired-password -e'\
alter user root@"localhost" identified by "123456"'
mysql -uroot -p123456 --connect-expired-password -e'\
update mysql.user set authentication_string="";'

systemctl restart mysqld
if [ $? -ne 0 ];then
    echo mysql init is error
    exit 6
fi

rm -f /etc/redis/status/redis_6379.pid 
bash /etc/init.d/redis restart

tar -xf /mnt/openfalcon/falcon.tar.gz -C /etc

cd /etc/open-falcon/db

mysql -h 127.0.0.1 -u root < 1_uic-db-schema.sql
mysql -h 127.0.0.1 -u root < 2_portal-db-schema.sql
mysql -h 127.0.0.1 -u root < 3_dashboard-db-schema.sql
mysql -h 127.0.0.1 -u root < 4_graph-db-schema.sql
mysql -h 127.0.0.1 -u root < 5_alarms-db-schema.sql

cd /etc/open-falcon
./open-falcon start all

cd dashboard

./control start

mv /mnt/openfalcon/ControlOpenfalcon.sh /usr/local/bin
