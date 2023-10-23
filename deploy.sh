#!/bin/bash

function configure_nginx_ingress() {
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.0/deploy/static/provider/cloud/deploy.yaml
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
}

function configure_cert_manager() {
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.5/cert-manager.yaml
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/cert-manager \
        deployment.apps/cert-manager-cainjector \
        deployment.apps/cert-manager-webhook \
        -n cert-manager
}

function application_deploy() {

    kubectl apply -f ./deployment/portfolio-namespace.yaml

    kubectl create secret generic backend-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/backendSecret.json)
    kubectl create secret generic frontend-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/frontendSecret.json)
    kubectl create secret generic postgres-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/postgresSecret.json)
    kubectl create secret generic redis-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/redisSecret.json)
    kubectl create secret generic storage-secret -n portfolio --from-env-file <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ./deployment/secrets/storageSecret.json)

    kubectl apply -f ./deployment/postgres
    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/postgres-deployment \
        -n portfolio

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
        ./deployment/nginx-ingress/nginx-ingress-root.yaml
    kubectl apply -f \
        ./deployment/nginx-ingress/nginx-ingress-api.yaml

}

function main() {

    if [[ $1 == "--local" || $1 == "-l" ]]; then

        function kubectl {
            minikube kubectl -- $@
        }

        minikube start --driver kvm2 --cpus 6 --memory 6Gib
        minikube addons enable ingress-dns
        minikube addons enable ingress

        application_deploy

        configure_cert_manager

        kubectl apply -f ./deployment/cert-manager/cert-manager-issuer-dev.yaml

        kubectl apply -f \
            ./deployment/cert-manager/cert-manager-certificate.yaml

        echo "http://$(/usr/bin/minikube ip)"

    else

        configure_nginx_ingress

        application_deploy

        external_ip=""
        while [ -z $external_ip ]; do
            echo "Waiting for end point..."
            external_ip=$(kubectl get svc --namespace=ingress-nginx ingress-nginx-controller --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
            [ -z "$external_ip" ] && sleep 10
        done

        configure_cert_manager

        kubectl apply -f \
            ./deployment/cert-manager/cert-manager-issuer.yaml

        kubectl apply -f \
            ./deployment/cert-manager/cert-manager-certificate.yaml

        if [[ $1 == "--staging" || $1 == "-s" ]]; then
            bash ./refresh.sh
        fi

    fi

    exit 0

}

main $1
