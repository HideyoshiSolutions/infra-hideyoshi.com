#!/bin/bash


TEMPLATE='./template'
WORK_DIR='./deployment'

function set_working_dir() {

    mkdir -p $WORK_DIR;
    mkdir -p $WORK_DIR/redis;
    mkdir -p $WORK_DIR/postgres;
    mkdir -p $WORK_DIR/frontend;
    mkdir -p $WORK_DIR/backend;

    envsubst < $TEMPLATE/redis/redis-secret.template.yaml > $WORK_DIR/redis/redis-secret.yaml;
    envsubst < $TEMPLATE/postgres/postgres-secret.template.yaml > $WORK_DIR/postgres/postgres-secret.yaml;
    envsubst < $TEMPLATE/frontend/frontend-secret.template.yaml > $WORK_DIR/frontend/frontend-secret.yaml;
    envsubst < $TEMPLATE/backend/backend-secret.template.yaml > $WORK_DIR/backend/backend-secret.yaml;

}

function main {

    [[ -z $1 ]] && file=".secret" || file=$1

    if [[ -e $file ]]; then

        set -a
        
        if [[ $1 == "--dev" || $1 == "-d" ]]; then
            DOMAIN="dev.hideyoshi.com.br"
        elif [[ $1 == "--staging" || $1 == "-a" ]]; then
            DOMAIN="staging.hideyoshi.com.br"
        else 
            DOMAIN="hideyoshi.com.br"
        fi

        while read line; do
            if [[ $line != "" ]]; then
                variable=$(echo -n "$line" | cut -f 1 -d '=')
                value=$(echo -n $(echo -n "$line" | cut -f 2 -d '=') | base64)
                declare $variable=$value
            fi
        done < $file

        set +a

    else 

        echo "ERROR: Secret file not found.";
        exit 1;

    fi

    set_working_dir

}

main $@