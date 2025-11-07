#!/bin/bash


### deploy flux operator ###
helm upgrade --install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
    --namespace flux-system \
    --create-namespace


kubectl apply -f manifest/flux-instance.yml


###  Additional components ###
# deploy descheduler
kubectl apply -f manifest/charts/descheduler


# deploy ingress-nginx
kubectl create namespace ingress-nginx \
    --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f manifest/charts/nginx


# deploy cert-manager
kubectl create namespace cert-manager \
    --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f manifest/charts/cert-manager


### set application namespaces and configures docker registry secret ###
if [[ -f $HOME/.docker/config.json ]]; then
    for NAMESPACE in ${NAMESPACES_LIST//,/ }; do
        kubectl create namespace $NAMESPACE \
            --dry-run=client -o yaml | kubectl apply -f -
            
        kubectl create secret generic $(echo $NAMESPACE | tr '[:upper:]' '[:lower:]')-regcred \
            --from-file=.dockerconfigjson=$HOME/.docker/config.json \
            --type=kubernetes.io/dockerconfigjson \
            -n $NAMESPACE \
            --dry-run=client -o yaml | kubectl apply -f -
    done
else
    echo "Docker config file not found at $HOME/.docker/config.json. Skipping registry secret creation."
fi