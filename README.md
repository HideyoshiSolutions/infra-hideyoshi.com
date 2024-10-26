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

    This project requires a working kubernetes cluster with the following tools installed: kubectl, helm and envsubts. If running in a local environment and if minikube is preset a minikube cluster can be created.

- Running Kubernetes Application:

    ```
    ./deploy.sh [-f <env_file>] [-e <environment>] [-m]
    ```

- Flags:

  - `-f`: The environment file to use. If not set the system environment variables will be used.

  - `-e`: The environment to deploy. Values `[remote|local]`. Default is `remote`.
  
  - `-m`: If set, the minikube cluster will be used.

## Authors

- [@HideyoshiNakazone](https://github.com/HideyoshiNakazone)

