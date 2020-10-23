#!/bin/bash

# delete cluster
#kind delete cluster --name nx


### create cluster with ingress
echo "*** Create Kind Cluster"
cat <<EOF | kind create cluster --name nx --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

sleep 5

# install nginx
echo "*** Install nginx"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml

sleep 20

echo "*** Wait for nginx to be ready"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# helm
echo "*** Tiller rbac"
kubectl create -f rbac-config.yaml

echo "*** Install Tiller"
helm init --service-account tiller --history-max 200


# load image
echo "*** load Nuxeo image"
kind load docker-image nuxeo/nuxeo:tiry --name nx


#fetch dependencies
echo "*** fetch Helm dependencies"
helm dependency update nuxeo



