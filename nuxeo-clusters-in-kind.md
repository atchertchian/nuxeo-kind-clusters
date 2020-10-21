
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


	helm upgrade \
	 -f nuxeo/values-tiry.yaml \
	 nuxeo-cluster \
	 --debug \
	 --set nuxeo.packages=nuxeo-web-ui \
	 --set tags.mongodb=true \
	 --set tags.elasticsearch=true \
	 --set tags.kafka=true \
	 --set nuxeo.ingress.enabled=true \
	 --set nuxeo.clid='xxx' \
	  nuxeo


## Principles used to deploy multiple nuxeo application

### First test

For now, I used a viking approach, basicaly copy/pasting the needed resources:

 - duplicated configMap to have 3 different configurations
    - default configuration
    	- using `nuxeo` as database name
    	- using `nuxeo` as index prefix
    	- using `nuxeo-` as kafka prefix
    - app1 configuration
    	- using `app1` as database name
    	- using `app1` as index prefix
    	- using `app1-` as kafka prefix
    - app2 configuration
    	- using `app2` as database name
    	- using `app2` as index prefix
    	- using `app2-` as kafka prefix 
 - duplicated deployment to have 3 deployments
 	- nuxeo using the default configuration
 	- nuxeo-app1 using the app1 configuration
 	- nuxeo-app2 using the app2 configuration
 - duplicated service to have 3 services
 - added routing rule in the ingress
 	- app1.localhost goes to app1
    - app2.localhost goes to app2
    - everything else goes to the default nuxeo

This system is far from ideal:

 - lot of duplicated yaml
 - no k8s namespace isolation
 
###	Civilized templating

Among the differnt options I would like to investigate:

 - pure helm
 	- split storare and nuxeo charts
 	- use a loop in Nuxeo helm charts (using `range`)
 - leverage [helmfile](https://github.com/roboll/helmfile)

### namespace 

The goal would be to:

 - deploy each "tenant" inside a dedicated namespace
 - deploy the shared storage layer in a dedicated namespace
 - define network-policies to 
     - keep the tenants namespace isolated from each other 
     - allow all tenants to access the storage services

However, if the goal is to migrate all storage services outside of the k8s cluster to be able to leverage PaaS, then we can probably skip that step.       

## Testing the cluster

### http access

There are 3 deployed nuxeo:

 - app1.localhost/nuxeo
 - app2.localhost/nuxeo
 - localhost/nuxeo
 
### Checking ES indices

Enter one of the Nuxeo containers

    kubectl get pods | grep nuxeo-app1

    kubectl exec -ti nuxeo-cluster-nuxeo-app1-6cdccc8c95-8bckv -- /bin/bash

    wget -O  - http://nuxeo-cluster-elasticsearch-client:9200/_cat/indices


### Checking Mongo Databases

    kubectl get pods | grep mongodb

    kubectl exec -ti nuxeo-cluster-mongodb-df547c46-t6vpm -- /bin/bash

Start Mongo CLI

    mongo

Listing databases

    db.adminCommand( { listDatabases: 1 } )


Listing collections

    use app1
    db.runCommand( { listCollections: 1, nameOnly: true } )

### Checking Kafka

    kubectl get pods | grep mongodb

    kubectl exec -ti nuxeo-cluster-kafka-0 -- /bin/bash

List Kafka topics:

    kafka-topics --list --zookeeper nuxeo-cluster-zookeeper


## Install Kubernetes Dashboards

*Not tested recently!!!*

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



kubectl scale deployment.v1.apps/nuxeo-cluster-nuxeo-app1 --replicas=2



https://github.com/nuxeo-projects/loreal/blob/721c351b8e4a5023751276a7b24f5282a3b1415b/loreal-package/src/main/resources/install/templates/milor-package/config/authentication-config.xml.nxftl


 - update
 - multiple deployments

 - loop

 - config file


