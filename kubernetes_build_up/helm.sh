mkdir -p /kubernetes/helm ; cd /kubernetes/helm
tar -xf /root/helm-v2.12.1-linux-amd64.tar.gz -C .
rm -f /usr/local/bin/helm ; cp linux-amd64/helm /usr/local/bin/
helm init --upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.12.1 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
helm version
