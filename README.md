<div align="center">
  <a href="https://github.com/HideyoshiNakazone/hideyoshi.com">
    <img src="https://drive.google.com/uc?export=view&id=1ka1kTMcloX_wjAlKLET9VoaRTyRuGmxQ" width="100" height="100" allow="autoplay"\>
  </a>
</div>


# infra-hideyoshi.com

Made using Kubernetes, this project was made for the deployment of the [hideyoshi.com project](https://github.com/HideyoshiNakazone/hideyoshi.com).

All code in this repo is distributed freely by the GPLv3 License.
## Usage

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
## Authors

- [@HideyoshiNakazone](https://github.com/HideyoshiNakazone)

