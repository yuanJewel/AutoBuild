#!/bin/bash
# Writer is Zhiyuan Yu , E-mail: luyu151111@163.com

path=${0%/*}
echo $path | grep '^/' &>/dev/null
if [ $? -ne 0 ];then
  path=$(echo $path | sed -r 's/\.\/*//')
  path=$PWD/$path
fi
path=$(echo $path | sed -r 's/\/{2,}/\//')
path=$1

# write a status page on the control server to view the service status after installation
echo '<?php' > /var/www/html/status.php
start=$(awk '{print $1}' $path/host.log | head -1)
stop=$(awk '{print $1}' $path/host.log | tail -1)
echo ' for($i='${start##*.}';$i<'${stop##*.}';$i++){
  $name="'${start%.*}'.{$i}";
  $command = "nmap -A '${start%.*}'.{$i}";' >> /var/www/html/status.php
echo '
   $arr = array();
   exec($command, $arr, $status);
   echo "<h1> {$name} </h1>";
   for($s=0;$s<count($arr);$s++) {
    echo $arr[$s];
    echo "<br>";
   }
 }
?>' >> /var/www/html/status.php
