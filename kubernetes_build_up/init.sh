cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum clean all && yum repolist -y

cat <<EOF >  /etc/sysctl.d/k8s.conf
vm.swappiness = 0
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf

#cat << EOF > /etc/sysconfig/modules/ipvs.modules 
#!/bin/bash
#ipvs_modules_dir="/usr/lib/modules/\`uname -r\`/kernel/net/netfilter/ipvs"
#for i in \`ls \$ipvs_modules_dir | sed  -r 's#(.*).ko.*#\1#'\`; do
#    /sbin/modinfo -F filename \$i  &> /dev/null
#    if [ \$? -eq 0 ]; then
#        /sbin/modprobe \$i
#    fi
#done
#EOF

#chmod +x /etc/sysconfig/modules/ipvs.modules 
#bash /etc/sysconfig/modules/ipvs.modules

yum install -y kubeadm kubelet kubectl
systemctl enable kubelet
mkdir /kubernetes 

hostname $(grep $(ifconfig eth0 | grep inet | awk '{print $2}' | head -1) /etc/hosts | awk '{print $2}')
echo $(grep $(ifconfig eth0 | grep inet | awk '{print $2}' | head -1) /etc/hosts | awk '{print $2}') > /etc/hostname
