#!/bin/bash

function check_k3s_installation() {
    if [ ! -f /usr/local/bin/k3s ]; then
        curl -sfL https://get.k3s.io | sh - 
        sudo chmod 644 /etc/rancher/k3s/k3s.yaml;
    fi
}

function start_cert_manager() {

    kubectl apply -f ./deployment/cert-manager/cert-manager.yaml;
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/cert-manager \
        deployment.apps/cert-manager-cainjector \
        deployment.apps/cert-manager-webhook \
        -n cert-manager;

}

function application_deploy() {

    kubectl apply -f ./deployment/portfolio-namespace.yaml;

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
        
        start_cert_manager

        kubectl apply -f \
            ./deployment/cert-manager/cert-manager-issuer-dev.yaml;
        
        application_deploy

        echo "http://$(/usr/bin/minikube ip)";

    elif [[ $1 == "--staging" || $1 == "-s" ]]; then

        check_k3s_installation

        kubectl apply -f ./deployment/nginx-ingress/nginx-ingress.yaml;
        kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s;

        start_cert_manager
        kubectl apply -f ./deployment/cert-manager/cert-manager-issuer.yaml;

        application_deploy

    else

        check_k3s_installation

        kubectl apply -f ./deployment/nginx-ingress/nginx-ingress.yaml;
        kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s;

        start_cert_manager
        kubectl apply -f ./deployment/cert-manager/cert-manager-issuer.yaml;

        application_deploy

    fi

    exit 0;

}

main $1
