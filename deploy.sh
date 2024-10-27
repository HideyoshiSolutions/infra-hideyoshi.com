#!/bin/bash


validate_dependencies() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl could not be found"
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        echo "helm could not be found"
        exit 1
    fi

    if ! command -v envsubst &> /dev/null; then
        echo "envsubst could not be found"
        exit 1
    fi

    if [[ $environment == "local" ]]; then
        if ! command -v minikube &> /dev/null; then
            echo "minikube could not be found"
            exit 1
        fi
    fi

    echo "Dependencies validated"  
}


read_env_file() {
    if [ -f $1 ]; then
        set -a && source $1 && set +a;
    fi
}


build_secret_envs() {
    for i in $(env | grep -E '^KUBE_[a-zA-Z_][a-zA-Z0-9_]*=' | cut -d= -f1); do
        eval "export ${i}_B64=$(echo -n ${!i} | base64 -w0)"
    done
}


apply_template() {
    echo -e "\n\n----------------------------------------------------\n"
    echo -e "Applying: $1\n"
    echo -e "----------------------------------------------------\n\n\n"

    envsubst < $1 | kubectl apply -f -
}


apply_resource() {
    resource_name=$1
    deployment_files=$2

    for file in $(find $2 -type f); do
        apply_template $file
    done

    kubectl wait --for=condition=available \
        --timeout=600s \
        ${resource_name} \
        -n ${KUBE_NAMESPACE}
}


configure_nginx_minikube() {
    if [[ $setup_minikube == "true" ]]; then
        minikube start --driver kvm2 --cpus 8 --memory 8Gib
    fi

    minikube addons enable ingress-dns
    minikube addons enable ingress
}


configure_descheduler() {
    helm repo add descheduler https://kubernetes-sigs.github.io/descheduler
    helm upgrade --install descheduler descheduler/descheduler \
        --namespace kube-system \
        --set schedule="*/5 * * * *" \
        --set successfulJobsHistoryLimit=1 \
        --set failedJobsHistoryLimit=1
}


configure_nginx_ingress() {
    helm upgrade --install ingress-nginx ingress-nginx \
        --repo https://kubernetes.github.io/ingress-nginx \
        --namespace ingress-nginx --create-namespace

    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
}


configure_cert_manager() {
    helm repo add jetstack https://charts.jetstack.io --force-update
    helm repo update
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.14.2 \
        --set installCRDs=true \
        --timeout=600s || echo "Cert Manager already installed"
}


configure_postgres_cluster() {
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    helm upgrade --install cnpg \
        --namespace ${KUBE_NAMESPACE} \
        --create-namespace \
        cnpg/cloudnative-pg
}


configure_ingress() {
    apply_template "./template/nginx-ingress/nginx-ingress-root.template.yaml"

    if [[ $environment == "local" ]]; then
        apply_template "./template/cert-manager/cert-manager-issuer-dev.yaml"
    else
        apply_template "./template/cert-manager/cert-manager-issuer.yaml"
    fi

    apply_template "./template/cert-manager/cert-manager-certificate.template.yaml"
}


deploy_kubernetes() {
    if [[ $environment == "local" ]]; then
        configure_nginx_minikube
    else 
        configure_nginx_ingress
    fi

    configure_descheduler

    configure_cert_manager

    configure_postgres_cluster

    KUBE_FILES=(
        "./template/portfolio-namespace.template.yaml"
        "./template/portfolio-secret.template.yml"
    )

    for file in ${KUBE_FILES[@]}; do
        apply_template $file
    done

    apply_resource "cluster/postgres-cn-cluster" "./template/postgres"

    apply_resource "deployment.apps/redis-deployment" "./template/redis"

    apply_resource "deployment.apps/storage-deployment" "./template/storage"

    apply_resource "deployment.apps/backend-deployment" "./template/backend"

    apply_resource "deployment.apps/frontend-deployment" "./template/frontend"

    configure_ingress

    if [[ $environment == "local" ]]; then
        echo "Minikube IP: http://$(minikube ip)"
    fi
}


main() {
    build_secret_envs

    deploy_kubernetes $@
}


refresh() {
    deployments=$1
    if [[ -z $1 ]]; then
        deployments=(
            "redis-deployment"
            "storage-deployment"
            "backend-deployment"
            "frontend-deployment"
        )
    fi
    for deployment in ${deployments[@]}; do
        kubectl rollout restart deployment/${deployment} -n ${KUBE_NAMESPACE}
    done
}


environment="remote"
setup_minikube="false"
execution_mode="deploy"

while getopts ":f:e:mrh" opt; do
    case ${opt} in
        f )
            echo "Reading env file: ${OPTARG}"
            read_env_file ${OPTARG}
            ;;
        e )
            [[ ${OPTARG} == "local" ]] && environment="local"
            echo "Environment: ${OPTARG}"
            ;;
        m )
            setup_minikube="true"
            echo "Setting up minikube"
            ;;
        h )
            echo "Usage: deploy.sh [-f <env_file>] [-e <environment>] [-m <minikube>]"
            exit 0
            ;;
        r )
            echo "Executing Refresh"
            execution_mode="refresh"

            eval nextopt=\${$OPTIND}
            if [[ -n $nextopt && $nextopt != -* ]]; then
                OPTIND=$((OPTIND + 1))
                refresh_deployments=($nextopt)
            fi
            ;;
        *)
            echo "Invalid option: $OPTARG"
            exit 1
            ;;
    esac
done

validate_dependencies

if [[ $execution_mode == "deploy" ]]; then
    main
elif [[ $execution_mode == "refresh" ]]; then
    [[ -z $refresh_deployments ]] && refresh || refresh $refresh_deployments
else
    echo "Invalid execution mode: $execution_mode"
    exit 1
fi