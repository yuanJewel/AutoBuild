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

go_start 50&

path=${0%/*}
echo $path | grep '^/' &>/dev/null
if [ $? -ne 0 ];then
  path=$(echo $path | sed -r 's/.\/*//')
  path=$PWD/$path
fi
path=$(echo $path | sed -r 's/\/{2,}/\//')
path=$1
cd $path

start=$(awk -F= '/range_start/{print $2}' $path/main.conf | sed 's/ //g')
stop=$(awk -F= '/range_stop/{print $2}' $path/main.conf | sed 's/ //g')

for i in `seq ${start##*.} ${stop##*.}`
do
  ping -c 5 ${start%.*}.$i &>/dev/null &
done

rm -f $path/tmp.txt $path/tmp2.txt $path/host.log
touch $path/tmp.txt $path/tmp2.txt $path/host.log
for i in `seq ${start##*.} ${stop##*.}`
do
  {
  ping -c 5 ${start%.*}.$i  &>/dev/null
  [ $? -eq 0 ] && echo $i >> $path/tmp.txt && echo -n '#'
  } &
done
wait
echo ''
cat $path/tmp.txt | sort -n > $path/tmp2.txt
for i in $(cat $path/tmp2.txt)
do
  echo ${start%.*}.$i >> $path/host.log
done
rm -f $path/tmp*.txt

if [ ! -f ~/.ssh/id_rsa ];then

expect << EOF
spawn ssh-keygen
expect "key"  {send "\n"}
expect "passphrase" {send "\n"}
expect "passphrase" {send "\n"}
expect "passphrase" {send "\n"}
expect "key" {send "\n"}
EOF

  echo 'you need a key to ssh, now I am making'
fi

for i in $(cat $path/host.log)
do
expect << EOF
spawn ssh-copy-id -f $i
expect yes/no {send "yes\n"}
expect password {send "Yu06078\n"}
expect password {send "Yu06078\n"}
EOF
done

# $len is to mark which line will be writed in host.log
# $num is to mark the server's number
len=1
max_len=$(sed -n  '/^# end/=' $path/main.conf)
for i in nginx tomcat cache mysql falcon
do
  num=1
  while [ $num -le $(awk -F= '/'$i'_server/{print $2}' $path/main.conf | sed 's/ //g') ]
  do
    [ $len -gt $max_len ] && echo your configure has problem about the number of servers && exit 4
    sed -i $len's/$/  '$i' '$num'/' $path/host.log
    let len++
    let num++
  done
done
cat $path/host.log

for i in `seq $( cat $path/host.log | wc -l )`
do
  ssh $(awk 'NR=='$i'{print $1}' $path/host.log) "echo $(awk 'NR=='$i'{print $2}' $path/host.log)$(awk 'NR=='$i'{print $3}' $path/host.log) > /etc/hostname"
  ssh $(awk 'NR=='$i'{print $1}' $path/host.log) hostname "$(awk 'NR=='$i'{print $2}' $path/host.log)$(awk 'NR=='$i'{print $3}' $path/host.log)"
done

bash $path/scripts/status.sh $path &

bash $path/scripts/yum.sh $path
if [ $? -ne 0 ];then
    echo yum is error
    exit 10
fi

source $path/scripts/nginx.sh $path
if [ $? -ne 0 ];then
    echo nginx is error
    exit 11
fi

bash $path/scripts/tomcat.sh $path
if [ $? -ne 0 ];then
    echo tomcat is error
    exit 11
fi

bash $path/scripts/cache.sh $path
if [ $? -ne 0 ];then
    echo cache is error
    exit 12
fi

bash $path/scripts/mysql.sh $path
if [ $? -ne 0 ];then
    echo mysql is error
    exit 13
fi

bash $path/scripts/open-falcon.sh $path
if [ $? -ne 0 ];then
    echo falcon is error
    exit 14
fi

echo -e "\033[92mnow you can test the servers\033[0m"
