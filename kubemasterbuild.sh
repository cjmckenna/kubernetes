#!/bin/bash

echo Enter your desired pod network CIDR in format xxx.xxx.xxx.xxx/xx

read podcidr

apt-get update && sudo apt-get install -y vim

apt-get update && sudo apt-get install -y docker.io

apt-get update && sudo apt-get install -y apt-transport-https curl

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb http://packages.cloud.google.com/apt/ kubernetes-xenial main
EOF

apt-get update

apt-get install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

cat <<EOF | sudo tee /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

sleep 2

systemctl daemon-reload

sleep 5

systemctl restart docker

sleep 5

systemctl restart kubelet

sleep 5

echo starting image pulls

kubeadm config images pull

kubeadm init --control-plane-endpoint kube-master:6443 --pod-network-cidr=$podcidr

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

curl -O https://raw.githubusercontent.com/cjmckenna/kubernetes/main/calico.yaml

sed -i "s@192.168.0.0/23@$podcidr@g" calico.yaml

kubectl apply -f calico.yaml

#Kubernetes Dashboard install and config

curl -O https://raw.githubusercontent.com/cjmckenna/kubernetes/main/nodeport_dashboard_patch.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml
kubectl --namespace kubernetes-dashboard patch svc kubernetes-dashboard -p '{"spec": {"type": "NodePort"}}'
kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard --patch "$(cat nodeport_dashboard_patch.yaml)"
kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa
