#!/bin/bash

NAMESPACES=(
    portfolio
)

DEPLOYMENTS=(
    "frontend-deployment"
    "backend-deployment"
    "storage-deployment"
    "storage-processor-deployment"
)

for i in "${NAMESPACES[@]}"; do
    for x in "${DEPLOYMENTS[@]}"; do
        PODS=$(kubectl -n $i get pods --no-headers | awk '{print $1}' | grep $x | tr '\n' ' ')
        kubectl -n $i delete pods $PODS
    done
done
