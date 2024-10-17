#!/bin/sh


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


apply_deployment() {
    deployment_name=$1
    deployment_files=$2

    for file in $(find $2 -type f); do
        apply_template $file
    done

    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/${deployment_name} \
        -n ${KUBE_NAMESPACE}
}


configure_nginx_minikube() {
    if [[ $setup_minikube == "true" ]]; then
        minikube start --driver kvm2 --cpus 2 --memory 4Gib
    fi

    minikube addons enable ingress-dns
    minikube addons enable ingress
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
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.14.2 \
        --set installCRDs=true \
        --timeout=600s || echo "Cert Manager already installed"
}


configure_postgres() {
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    helm upgrade --install cnpg \
        --namespace ${KUBE_NAMESPACE} \
        --create-namespace \
        cnpg/cloudnative-pg

    kubectl wait --for=condition=available \
        --timeout=600s \
        deployment.apps/cnpg-cloudnative-pg \
        -n ${KUBE_NAMESPACE}

    apply_template "./template/postgres/cn-cluster.template.yaml"
    kubectl wait --for=condition=Ready \
        --timeout=600s \
        cluster/postgres-cn-cluster \
        -n ${KUBE_NAMESPACE}
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

    configure_cert_manager

    KUBE_FILES=(
        "./template/portfolio-namespace.template.yaml"
        "./template/portfolio-secret.template.yml"
    )

    for file in ${KUBE_FILES[@]}; do
        apply_template $file
    done

    configure_postgres

    apply_deployment "redis-deployment" "./template/redis"

    apply_deployment "storage-deployment" "./template/storage"

    apply_deployment "backend-deployment" "./template/backend"

    apply_deployment "frontend-deployment" "./template/frontend"

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
}


environment="remote"
setup_minikube="false"
execution_mode="deploy"

while getopts ":f:e:mh" opt; do
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
            ;;
        *)
            echo "Invalid option: $OPTARG"
            exit 1
            ;;
    esac
done

if [[ $execution_mode == "deploy" ]]; then
    main
elif [[ $execution_mode == "refresh" ]]; then
    refresh
else
    echo "Invalid execution mode: $execution_mode"
    exit 1
fi