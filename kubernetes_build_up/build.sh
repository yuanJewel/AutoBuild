Password='M#v861zxa_PO'
for i in {1..3}
do
yum install -y expect
expect <<EOF
spawn ansible master,slaver -m authorized_key -a "user=root exclusive=true manage_dir=true key='$(< ~/.ssh/id_rsa.pub)'" -k -v
expect password {send $Password\n }
expect password {send $Password\n }
EOF
[[ $? != 0 ]] && exit 1
done
# init
ansible master,slaver -m copy -a 'src=/etc/hosts dest=/etc/hosts' || exit 2
ansible master,slaver -m script -a 'init.sh' || exit 3
ansible master,slaver -m shell -a '[[ $(rpm -qa | grep kube | wc -l ) == 4 ]] && echo OK ' || exit 4
ansible 172.16.0.215 -m script -a 'ssh-copy.sh' || exit 5

# yum docker
ansible master,slaver -m script -a 'docker' || exit 6

# keepalived
ansible master -m shell -a 'yum install -y keepalived' || exit 9
ansible master -m copy -a 'src=keepalived.conf dest=/etc/keepalived/keepalived.conf' || exit 10
ansible master -m script -a 'keepalived.sh' || exit 11
ansible master -m shell -a 'systemctl restart keepalived ; systemctl enable keepalived'  || exit 12
ansible master -m shell -a 'systemctl status keepalived' || exit 13

# etcd
ansible master -m script -a 'install_etcd_1' || exit 15
ansible 172.16.0.215  -m script -a 'install_etcd_2' || exit 14
ansible master -m script -a 'install_etcd_3' || exit 16

# kubeadm
ansible master -m copy -a 'src=config.yaml dest=/kubernetes/config.yaml' || exit 17
ansible 172.16.0.215 -m shell -a 'kubeadm init --config /kubernetes/config.yaml | tail -4 | grep 'kubeadm' > /kubernetes/join'  || exit 18
ansible 172.16.0.215 -m shell -a 'mkdir -p $HOME/.kube ; rm -f $HOME/.kube/config ; cp -i /etc/kubernetes/admin.conf $HOME/.kube/config ; chown $(id -u):$(id -g) $HOME/.kube/config ; kubectl get nodes' || exit 19
ansible 172.16.0.215 -m shell -a 'scp -r /etc/kubernetes/pki  172.16.0.216:/etc/kubernetes/ ;scp -r /etc/kubernetes/pki  172.16.0.217:/etc/kubernetes/' || exit 20
ansible 172.16.0.216,172.16.0.217 -m shell -a 'kubeadm init --config /kubernetes/config.yaml && mkdir -p $HOME/.kube ; rm -f $HOME/.kube/config ; cp -i /etc/kubernetes/admin.conf $HOME/.kube/config ; chown $(id -u):$(id -g) $HOME/.kube/config ; kubectl get nodes' || exit 21
ssh 172.16.0.215 'cat /kubernetes/join' > join
ansible slaver -m shell -a "$(cat join)" || exit 22
rm -f join

# caclico
ansible 172.16.0.215 -m script -a 'calico.sh' || exit 23

# dashboard
ansible 172.16.0.215 -m copy -a 'src=kubernetes-dashboard.yaml dest=/kubernetes/kubernetes-dashboard.yaml'
ansible 172.16.0.215 -m shell -a 'kubectl apply -f /kubernetes/kubernetes-dashboard.yaml'

# prometheus
ansible 172.16.0.215 -m script -a 'prometheus.sh'





ansible 172.16.0.215 -m shell -a 'kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk "{print \$1}")'
