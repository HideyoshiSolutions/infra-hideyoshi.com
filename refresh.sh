#!/bin/bash


function refresh_kubernetes_secrets() {
    kubectl delete secret backend-secret -n portfolio
    kubectl delete secret frontend-secret -n portfolio
    kubectl delete secret postgres-secret -n portfolio
    kubectl delete secret redis-secret -n portfolio
    kubectl delete secret storage-secret -n portfolio

    kubectl create secret generic backend-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/backendSecret.json)
    kubectl create secret generic frontend-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/frontendSecret.json)
    kubectl create secret generic postgres-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/postgresSecret.json)
    kubectl create secret generic redis-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/redisSecret.json)
    kubectl create secret generic storage-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/storageSecret.json)
}

function refresh_kubernetes_deployments() {
    NAMESPACES=(
        portfolio
    )
    DEPLOYMENTS=("$@")

    for i in "${NAMESPACES[@]}"; do
        for x in "${DEPLOYMENTS[@]}"; do
            PODS=$(kubectl -n $i get pods --no-headers | awk '{print $1}' | grep $x | tr '\n' ' ')
            kubectl -n $i delete pods $PODS
        done
    done
}


if [ $# -eq 0 ]; then
    DEPLOYMENTS=(
        "frontend-deployment"
        "backend-deployment"
        "storage-deployment"
        "storage-processor-deployment"
    )
else
    DEPLOYMENTS=("$@")
fi

refresh_kubernetes_secrets

refresh_kubernetes_deployments "${NAMESPACES[@]}" "${DEPLOYMENTS[@]}"

