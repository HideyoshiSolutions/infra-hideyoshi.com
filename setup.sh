#!/bin/bash


TEMPLATE='./template'
WORK_DIR='./deployment'

function set_working_dir() {

    cp -r $TEMPLATE $WORK_DIR

    envsubst < $WORK_DIR/frontend/frontend-secret.template.yaml > $WORK_DIR/frontend/frontend-secret.yaml;
    envsubst < $WORK_DIR/backend/backend-secret.template.yaml > $WORK_DIR/backend/backend-secret.yaml;
    envsubst < $WORK_DIR/postgres/postgres-secret.template.yaml > $WORK_DIR/postgres/postgres-secret.yaml;
    envsubst < $WORK_DIR/redis/redis-secret.template.yaml > $WORK_DIR/redis/redis-secret.yaml;
    rm $WORK_DIR/frontend/frontend-secret.template.yaml; 
    rm $WORK_DIR/redis/redis-secret.template.yaml; 
    rm $WORK_DIR/postgres/postgres-secret.template.yaml; 
    rm $WORK_DIR/backend/backend-secret.template.yaml;

}

function main {

    if [[ $1 == "--test" || $1 == "-t" ]]; then
        
        if [[ -e .secret ]]; then

            set -a
            while read line; do
                variable=$(echo -n "$line" | cut -f 1 -d '=')
                value=$(echo -n $(echo -n "$line" | cut -f 2 -d '=') | base64)
                declare $variable=$value
            done < ./.secret
            
            set +a

        else 

            echo "ERROR: Secret file not found.";
            exit 1;

        fi
    
    fi

    set_working_dir

}

main $@