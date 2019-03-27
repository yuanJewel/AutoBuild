#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

sleep_time=0.1
go_start(){
    dead=0
    while [ $dead -le $1 ]
    do
        echo -e '-'"\b\c"
        sleep ${sleep_time}s
        echo -e '/'"\b\c"
        sleep ${sleep_time}s
        echo -e '|'"\b\c"
        sleep ${sleep_time}s
        echo -e '\\'"\b\c"
        sleep ${sleep_time}s
        dead=$[$dead+1]
    done
    echo -e ' '"\b\c"
}

# check yum and get the path
[ $(yum repolist | awk '/repolist/{print$2}' | sed 's/,//') -eq 0 ] && echo 'your yum has problem' && exit 2
yum install -y dhcp
path=${0%/*}
echo $path | grep '^/' &>/dev/null
if [ $? -ne 0 ];then
    path=$(echo $path | sed -r 's/.\/*//')
    path=$PWD/$path
fi
path=$(echo $path | sed -r 's/\/{2,}/\//')
path=$1

# bulid dhcp server
rm -f /etc/dhcp/dhcpd.conf
cp $path/pxe/dhcpd.conf /etc/dhcp/dhcpd.conf

for i in IP subnet netmask range_start range_stop
do
    sed -i 's/yzy_'$i'/'$(awk -F= '/'$i'/{print $2}' $path/main.conf | sed 's/ //g')'/' /etc/dhcp/dhcpd.conf
done
systemctl restart dhcpd
if [ $? -ne 0 ];then
    echo dhcp cannot start
    exit 3
fi

systemctl enable dhcpd

# bulid tftp server
yum install -y tftp-server
systemctl restart tftp
if [ $? -ne 0 ]; then
    echo tftp is error
    exit 4
fi

systemctl enable tftp
rm -rf /var/lib/tftpboot/*
cp $path/pxe/pxelinux.0 /var/lib/tftpboot/
mkdir /var/lib/tftpboot/pxelinux.cfg
rm -rf /var/lib/tftpboot/pxelinux.cfg/*
cp $path/pxe/isolinux.cfg /var/lib/tftpboot/pxelinux.cfg/default
sed -i 's/yzy_IP/'$(awk -F= '/IP/{print $2}' $path/main.conf | sed 's/ //g')'/' /var/lib/tftpboot/pxelinux.cfg/default
cp $path/pxe/linuz/* /var/lib/tftpboot/

# bulid iso server
yum -y install httpd expect mod_php
systemctl start httpd
if [ $? -ne 0 ]; then
    echo httpd is error
    exit 5
fi

systemctl enable httpd
mkdir /var/www/html/rhel7
rm -rf /var/www/html/rhel7/*

# start to rotate pointer
go_start 300 &

cp -rf $(awk -F= '/isoPath/{print $2}' $path/main.conf | sed 's/ //g')/*  /var/www/html/rhel7
if [ $? -ne 0 ]; then
    echo iso path is wrong
    exit 6
fi

kill $!
rm -f /var/www/html/ks.cfg
cp $path/pxe/ks.cfg /var/www/html/
sed -i 's/yzy_IP/'$(awk -F= '/IP/{print $2}' $path/main.conf | sed 's/ //g')'/' /var/www/html/ks.cfg
echo build pxe successfully