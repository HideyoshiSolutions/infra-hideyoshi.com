#!/bin/bash


helm upgrade --install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
    --namespace flux-system \
    --create-namespace


kubectl apply -f manifest/flux-instance.yml


kubectl apply -f manifest/charts/descheduler


kubectl create namespace ingress-nginx \
    --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f manifest/charts/nginx


kubectl create namespace cert-manager \
    --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f manifest/charts/cert-manager