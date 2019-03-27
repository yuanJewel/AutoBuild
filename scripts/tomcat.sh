#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

path=$1
for i in $( awk '/tomcat/{print $1}' $path/host.log )
do
    ssh $i yum -y install  java-1.8.0-openjdk java-1.8.0-openjdk-headless
    if [ $? -ne 0 ]; then
        echo yum is error
        exit 1
    fi

    scp $path/tomcat/apache-tomcat-9.0.6.tar.gz $i:/mnt
    scp $path/tomcat/tomcat $i:/usr/bin/
    if [ $? -ne 0 ]; then
        echo file is error
        exit 2
    fi

    ssh $i chmod +x /usr/bin/tomcat
    ssh $i tar -xf /mnt/apache-tomcat-9.0.6.tar.gz -C /mnt/
    ssh $i mv /mnt/apache-tomcat-9.0.6 /var/tomcat
    ssh $i useradd tomcat
    ssh $i chown -R tomcat:tomcat /var/tomcat
    ssh $i tomcat start
    if [ $? -ne 0 ]; then
        echo tomcat is error
        exit 3
    fi

    ssh $i echo 'tomcat start' >> /etc/rc.d/rc.local
    if [ $? -ne 0 ]; then
        echo init start is error
        exit 4
    fi
    
    ssh $i chmod +x /etc/rc.d/rc.local
done
