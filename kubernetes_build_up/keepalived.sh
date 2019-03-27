a=$(ifconfig eth0 | grep inet | awk '{print $2}' | head -1)
case $a in
172.16.0.215)
   JH_STATE=MASTER
   JH_PRI=100
   JH_IP2=172.16.0.216
   JH_IP3=172.16.0.217;;
172.16.0.216)
   JH_STATE=BACKUP
   JH_PRI=90
   JH_IP2=172.16.0.215
   JH_IP3=172.16.0.217;;
172.16.0.217)
   JH_STATE=BACKUP
   JH_PRI=80
   JH_IP2=172.16.0.216
   JH_IP3=172.16.0.215;;
*)
   echo error !!!!!
esac

sed -i 's/JH_STATE/'$JH_STATE'/' /etc/keepalived/keepalived.conf
sed -i 's/JH_PRI/'$JH_PRI'/' /etc/keepalived/keepalived.conf
sed -i 's/JH_IP1/'$a'/' /etc/keepalived/keepalived.conf
sed -i 's/JH_IP2/'$JH_IP2'/' /etc/keepalived/keepalived.conf
sed -i 's/JH_IP3/'$JH_IP3'/' /etc/keepalived/keepalived.conf
