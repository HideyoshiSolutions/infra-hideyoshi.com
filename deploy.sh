#!/bin/bash

function configure_helm() {
    if [ ! -f /usr/local/bin/helm ]; then
        curl -sfL curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash -
    fi

    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

    helm repo update

    helm install nginx-ingress ingress-nginx/ingress-nginx --set controller.publishService.enabled=true
}

function application_deploy() {

    kubectl apply -f ./deployment/portfolio-namespace.yaml;


    kubectl apply -f ./deployment/postgres/postgres-secret.yaml;
    kubectl apply -f ./deployment/redis/redis-secret.yaml;
    kubectl apply -f ./deployment/storage/storage-secret.yaml;
    kubectl apply -f ./deployment/backend/backend-secret.yaml;
    kubectl apply -f ./deployment/frontend/frontend-secret.yaml;

    kubectl apply -f \
        ./deployment/cert-manager/cert-manager-certificate.yaml;

    kubectl apply -f ./deployment/postgres;
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/postgres-deployment \
        -n portfolio;

    kubectl apply -f ./deployment/redis;
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/redis-deployment \
        -n portfolio;

    kubectl apply -f ./deployment/frontend;
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/frontend-deployment \
        -n portfolio;

    kubectl apply -f ./deployment/storage;
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/storage-deployment \
        -n portfolio;

    kubectl apply -f ./deployment/backend;
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/backend-deployment \
        -n portfolio;

    kubectl apply -f \
        ./deployment/nginx-ingress/nginx-ingress-root.yaml;
    kubectl apply -f \
        ./deployment/nginx-ingress/nginx-ingress-api.yaml;

}

function main() {

    if [[ $1 == "--test" || $1 == "-t" ]]; then
    
        function kubectl {
            minikube kubectl -- $@
        }

        minikube start --driver kvm2;
        minikube addons enable ingress-dns;
        minikube addons enable ingress;
        
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

        kubectl apply -f ./deployment/cert-manager/cert-manager-issuer-dev.yaml;
        
        application_deploy

        echo "http://$(/usr/bin/minikube ip)";

    else

        configure_helm

        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

        kubectl apply -f ./deployment/cert-manager/cert-manager-issuer.yaml;

        application_deploy

    fi

    exit 0;

}

main $1
