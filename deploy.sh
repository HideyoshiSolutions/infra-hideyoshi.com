#!/bin/sh

# eval "$(awk 'BEGIN{                                                                                                        
#   for (i in ENVIRON) {
#     if (i ~ /^(KUBE_)[a-zA-Z_][a-zA-Z0-9_]*$/) {
#       printf "export " i "_B64=";
#       system("echo \"$"i"\" | base64 -w0");
#       print;
#     }
#   }
# }' /dev/null)"


function read_env_file() {
    if [[ -f $1 ]]; then
        set -a && source $1 && set +a;
    fi
}


function build_secret_envs() {
    for i in $(env | grep -E '^KUBE_[a-zA-Z_][a-zA-Z0-9_]*=' | cut -d= -f1); do
        eval "export ${i}_B64=$(echo ${!i} | base64 -w0)"
    done
}


function deploy_kubernetes() {
    KUBE_FILES=(
        "./template/portfolio-namespace.template.yaml"
        "./template/portfolio-secret.template.yml"
    )

    for file in ${KUBE_FILES[@]}; do
        echo -e "\n\n----------------------------------------------------\n"
        echo -e "Deploying: $file\n"
        echo -e "----------------------------------------------------\n\n\n"

        envsubst < $file
    done
}


function main() {
    build_secret_envs

    deploy_kubernetes
}


while getopts ":f:" opt; do
    case ${opt} in
        f )
            echo "Reading env file: ${OPTARG}"
            read_env_file ${OPTARG}
            ;;
        \? )
            echo "Usage: deploy.sh [-f <env_file>]"
            ;;
    esac
done

main