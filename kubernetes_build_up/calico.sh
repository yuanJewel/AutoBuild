kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/rbac.yaml
cd /kubernetes
rm -f calico.yaml
curl https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/calico.yaml -O

sed -i 's@.*etcd_endpoints:.*@\ \ etcd_endpoints:\ \"https://172.16.0.215:2379,https://172.16.0.216:2379,https://172.16.0.217:2379\"@gi' calico.yaml

export ETCD_CERT=`cat /etc/etcd/ssl/etcd.pem | base64 | tr -d '\n'` 
export ETCD_KEY=`cat /etc/etcd/ssl/etcd-key.pem | base64 | tr -d '\n'` 
export ETCD_CA=`cat /etc/etcd/ssl/ca.pem | base64 | tr -d '\n'`

sed -i "s@.*etcd-cert:.*@\ \ etcd-cert:\ ${ETCD_CERT}@gi" calico.yaml 
sed -i "s@.*etcd-key:.*@\ \ etcd-key:\ ${ETCD_KEY}@gi" calico.yaml 
sed -i "s@.*etcd-ca:.*@\ \ etcd-ca:\ ${ETCD_CA}@gi" calico.yaml 

sed -i 's@.*etcd_ca:.*@\ \ etcd_ca:\ "/calico-secrets/etcd-ca"@gi' calico.yaml 
sed -i 's@.*etcd_cert:.*@\ \ etcd_cert:\ "/calico-secrets/etcd-cert"@gi' calico.yaml 
sed -i 's@.*etcd_key:.*@\ \ etcd_key:\ "/calico-secrets/etcd-key"@gi' calico.yaml 

sed -i 's@192.168.0.0/16@10.0.0.0/8@' calico.yaml

kubectl apply -f calico.yaml
wget https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/manifests/app-layer-policy/etcd/calico-networking/calico-node.yaml
sed -i 's@192.168.0.0/16@10.0.0.0/8@' calico-node.yaml
kubectl apply -f calico-node.yaml
