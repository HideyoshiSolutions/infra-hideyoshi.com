# infra-hideyoshi.com

## How to Configure

- Requirements:

    This project requires a working kubernetes cluster, in case of a testing environment a minikube cluster will by configured for you, otherwise a kubernetes will not be configured.

- Configuring Secrets:

    ```
    python -m pip install --upgrade pip pipenv
    pipenv install
    pipenv run python setup.py -e {{environment-option}} -f config.json
    ```

- Running Kubernetes Application:

    ```
    sudo apt update && sudo apt install -y jq python3-pip
    cd infra-hideyoshi.com
    ./deploy.sh {{environmet-flag}}
    ```

    `{{environment-flag}}` : `--local`, `--staging`, `--prod`

    `{{environment-option}` : `local`, `staging`, `prod`
