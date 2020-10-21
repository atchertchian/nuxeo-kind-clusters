
# Install kind 

## Install `kind` itself

Provided you installed Go:

    GO111MODULE="on" go get sigs.k8s.io/kind@v0.9.0

NB: Setting the version is important because I initially ended up with 0.10.alpha and I had issues for pulling images ...

## Create kind Cluster with Ingress enabled

### Create Cluster and Ingress

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


Verify that you can connect:

    kubectl cluster-info

### Install Nginx

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml

	kubectl wait --namespace ingress-nginx \
	  --for=condition=ready pod \
	  --selector=app.kubernetes.io/component=controller \
	  --timeout=90s

## Install Helm


    kubectl create -f rbac-config.yaml

    helm init --service-account tiller --history-max 200

# Deploy nuxeo Cluster

## load Nuxeo image

    kind load docker-image nuxeo/nuxeo:tiry --name nx


Check that the image in now in the registry:

    docker exec -it nx-control-plane crictl images


## Deploy Cluster

    helm dependency update nuxeo

helm install \
 -f nuxeo/values-tiry.yaml \
 --name nuxeo-cluster \
 --debug \
 --set nuxeo.packages=nuxeo-web-ui \
 --set tags.mongodb=true \
 --set tags.elasticsearch=true \
 --set tags.kafka=true \
 --set nuxeo.ingress.enabled=true \
 --set nuxeo.clid='XXX' \
  nuxeo


## Testing the cluster

### http access

There are 3 deployed nuxeo:

 - app1.localhost/nuxeo
 - app2.localhost/nuxeo
 - localhost/nuxeo
 


### Checking ES indices

Enter one of the Nuxeo containers

 > kubectl get pods | grep nuxeo-app1

 > kubectl exec -ti nuxeo-cluster-nuxeo-app1-6cdccc8c95-8bckv -- /bin/bash

 > wget -O  - http://nuxeo-cluster-elasticsearch-client:9200/_cat/indices



### Checking Mongo Databases

 > kubectl get pods | grep mongodb

 > kubectl exec -ti nuxeo-cluster-mongodb-df547c46-t6vpm -- /bin/bash

 > mongo

Listing databases

 > db.adminCommand( { listDatabases: 1 } )


Listing collections

 > use app1
 > db.runCommand( { listCollections: 1, nameOnly: true } )

### Checking Kafka

 > kubectl get pods | grep mongodb

 > kubectl exec -ti nuxeo-cluster-kafka-0 -- /bin/bash

List Kafka topics:


 > kafka-topics --list --zookeeper nuxeo-cluster-zookeeper



## Install Kubernetes Dashboards

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

helm install dashboard kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard --create-namespace

helm install  kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard


kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml


cat <<EOF | kubectl apply -f -
kind: Service
apiVersion: v1
metadata:	
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-nodeport
  namespace: kubernetes-dashboard
spec:
  type: NodePort
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30080
  selector:
    k8s-app: kubernetes-dashboard
EOF

NB: https://medium.com/@munza/local-kubernetes-with-kind-helm-dashboard-41152e4b3b3d

