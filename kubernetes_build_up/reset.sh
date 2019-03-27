echo '--------------------reset----------------------------'
ansible master,slaver -m shell -a 'kubeadm reset --force'

echo '--------------------rm----------------------------'
ansible master -m shell -a 'rm -rf /var/lib/etcd/*'
ansible master,slaver -m shell -a 'rm -rf /var/lib/docker/*'

echo '--------------------stop----------------------------'
ansible master -m shell -a 'systemctl stop etcd'
ansible master,slaver -m shell -a 'systemctl stop docker'

echo '--------------------start----------------------------'
ansible master,slaver -m shell -a 'systemctl start docker'
ansible master -m shell -a 'systemctl start etcd'

echo '--------------------init----------------------------'
ssh 172.16.0.237 'kubeadm init --config config.yaml ; mkdir -p $HOME/.kube; rm -f $HOME/.kube/config; sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config;  sudo chown $(id -u):$(id -g) $HOME/.kube/config'


etcdctl --endpoints=https://172.16.0.237:2379,\
https://172.16.0.216:2379,https://172.16.0.217:2379 \
  --ca-file=/etc/etcd/ssl/ca.pem \
  --cert-file=/etc/etcd/ssl/etcd.pem \
  --key-file=/etc/etcd/ssl/etcd-key.pem  cluster-health

ansible master,slaver -m shell -a 'sysctl --system ; modprobe ip_vs ; modprobe ip_vs_rr ;modprobe ip_vs_wrr;modprobe ip_vs_sh ;modprobe nf_conntrack_ipv4'
