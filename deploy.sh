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
for NAMESPACE in ${NAMESPACES_LIST//,/ }; do
    kubectl create namespace $NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -

    kubectl delete secret ghcr-secret \
        --namespace=$NAMESPACE \
        --ignore-not-found=true
    kubectl create secret docker-registry ghcr-secret \
        --docker-server=ghcr.io \
        --docker-username=$GHCR_USERNAME \
        --docker-password=$GHCR_TOKEN \
        --docker-email=unused \
        --namespace=$NAMESPACE
done