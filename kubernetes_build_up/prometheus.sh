cd /kubernetes
rm -rf k8s-prometheus-grafana
git clone https://github.com/redhatxl/k8s-prometheus-grafana.git
cd k8s-prometheus-grafana
sed -i 's/31672/30002/' node-exporter.yaml
kubectl apply -f node-exporter.yaml
cd prometheus
kubectl apply -f .
cd ../grafana/
sed -i '/port:/a\      nodePort: 30004' grafana-svc.yaml
kubectl apply -f .
