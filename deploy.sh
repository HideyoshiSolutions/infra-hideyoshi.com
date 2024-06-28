#!/bin/bash

function check_for_dependencies() {
    if ! command -v kubectl &>/dev/null; then
        echo "kubectl could not be found"
        exit 1
    fi
    if ! command -v jq &>/dev/null; then
        echo "jq could not be found"
        exit 1
    fi
    if ! command -v helm &>/dev/null; then
        echo "helm could not be found"
        exit 1
    fi
}

function configure_nginx_ingress() {
    helm upgrade --install ingress-nginx ingress-nginx \
        --repo https://kubernetes.github.io/ingress-nginx \
        --namespace ingress-nginx --create-namespace

    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
}

function configure_cert_manager() {
    helm repo add jetstack https://charts.jetstack.io --force-update
    helm repo update
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.14.2 \
        --set installCRDs=true \
        --timeout=600s
}

function configure_postgres() {
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    helm upgrade --install cnpg \
        --namespace portfolio \
        --create-namespace \
        cnpg/cloudnative-pg

    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/cnpg-cloudnative-pg \
        -n portfolio

    kubectl apply -f ./deployment/postgres/cn-cluster.yaml
    kubectl wait --for=condition=Ready \
        --timeout=600s \
        cluster/postgres-cn-cluster \
        -n portfolio
}

function application_deploy() {

    kubectl create secret generic backend-secret -n portfolio \
        --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/backendSecret.json)

    kubectl create secret generic frontend-secret -n portfolio \
        --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/frontendSecret.json)

    kubectl create secret generic redis-secret -n portfolio \
        --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/redisSecret.json)

    kubectl create secret generic storage-secret -n portfolio \
        --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/storageSecret.json)

    kubectl apply -f ./deployment/redis
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/redis-deployment \
        -n portfolio

    kubectl apply -f ./deployment/frontend
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/frontend-deployment \
        -n portfolio

    kubectl apply -f ./deployment/storage
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/storage-deployment \
        -n portfolio

    kubectl apply -f ./deployment/backend
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/backend-deployment \
        -n portfolio

    kubectl apply -f \
        ./deployment/nginx-ingress

}

function main() {

    check_for_dependencies

    if [[ $1 == "--local" || $1 == "-l" ]]; then

        function kubectl {
            minikube kubectl -- $@
        }

        minikube start --driver kvm2 --cpus 4 --memory 4Gib
        minikube addons enable ingress-dns
        minikube addons enable ingress

    else

        configure_nginx_ingress

    fi

    configure_cert_manager

    kubectl apply -f ./deployment/portfolio-namespace.yaml

    configure_postgres

    application_deploy

    if [[ $1 == "--local" || $1 == "-l" ]]; then

        kubectl apply -f \
            ./deployment/cert-manager/cert-manager-issuer-dev.yaml

        kubectl apply -f \
            ./deployment/cert-manager/cert-manager-certificate.yaml

        echo "http://$(/usr/bin/minikube ip)"

    else

        kubectl apply -f \
            ./deployment/cert-manager/cert-manager-issuer.yaml

        kubectl apply -f \
            ./deployment/cert-manager/cert-manager-certificate.yaml

    fi

    exit 0

}

main $1
