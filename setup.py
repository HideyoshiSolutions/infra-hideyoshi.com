from base64 import b64decode, b64encode
from dotenv import load_dotenv
from envsubst import envsubst
from pathlib import Path, PosixPath
from typing import Generator
import argparse
import warnings
import json
import os


def unpack_list_dict(dl: list[dict]) -> Generator[tuple[str, str], None, None]:
    for d in dl:
        yield tuple(d.values())


def write_template(template: str, output: str):
    with open(template, 'r') as template,\
         open(output, 'w') as output:
        output.write(envsubst(template.read()))


def configure_env_variables(environment: str):
    if not environment in ("prod", "staging", "local"):
        raise ValueError("Invalid Environment Selected")

    match environment:
        case "local":
            DOMAIN = "local.hideyoshi.com.br"
            API_DOMAIN = "api.local.hideyoshi.com.br"
            MASTER_NODE_LABEL = "minikube.k8s.io/name: minikube"
            WORKER_NODE_LABEL = "minikube.k8s.io/name: minikube"
            
        case "staging":
            DOMAIN = "staging.hideyoshi.com.br"
            API_DOMAIN = "api.staging.hideyoshi.com.br"
            MASTER_NODE_LABEL = "node_type: master"
            WORKER_NODE_LABEL = "node_type: worker"

        case _:
            DOMAIN = "hideyoshi.com.br"
            API_DOMAIN = "api.hideyoshi.com.br"
            MASTER_NODE_LABEL = "node_type: master"
            WORKER_NODE_LABEL = "node_type: worker"

    os.environ["DOMAIN"] = DOMAIN
    os.environ["API_DOMAIN"] = API_DOMAIN
    os.environ["MASTER_NODE_LABEL"] = MASTER_NODE_LABEL
    os.environ["WORKER_NODE_LABEL"] = WORKER_NODE_LABEL


def configure_templates(environment: str):
    MAPPINS = [
        {"template": "template/cert-manager/cert-manager-certificate.template.yaml", "output": "deployment/cert-manager/cert-manager-certificate.yaml"},
        {"template": "template/nginx-ingress/nginx-ingress-root.template.yaml", "output": "deployment/nginx-ingress/nginx-ingress-root.yaml"},
        {"template": "template/postgres/cn-cluster.template.yaml", "output": "deployment/postgres/cn-cluster.yaml"},
        {"template": "template/frontend/frontend.template.yaml", "output": "deployment/frontend/frontend.yaml"},
        {"template": "template/backend/backend.template.yaml", "output": "deployment/backend/backend.yaml"},
        {"template": "template/storage/storage-processor.template.yaml", "output": "deployment/storage/storage-processor.yaml"},
        {"template": "template/storage/storage.template.yaml", "output": "deployment/storage/storage.yaml"},
    ]
    
    for template, output in unpack_list_dict(MAPPINS):
        write_template(template, output)


def validate_backend_secret(secret: str):
    required_keys = [
        'tokenSecret',
        'accessTokenDuration',
        'refreshTokenDuration',
        'defaultUserFullName',
        'defaultUserEmail',
        'defaultUserUsername',
        'defaultUserPassword',
        'googleClientId',
        'googleClientSecret',
        'googleRedirectUrl',
        'githubClientId',
        'githubClientSecret',
        'githubRedirectUrl'
    ]

    for key in required_keys:
        if key not in secret:
            raise ValueError(f"Key {key} not found in backendSecret")


def validate_frontend_secret(secret: str):
    required_keys = [
        'frontendPath',
        'backendUrl',
        'backendOAuthUrl',
        'githubUser'
    ]

    for key in required_keys:
        if key not in secret:
            raise ValueError(f"Key {key} not found in frontendSecret")


def validate_postgres_secret(secret: str):
    required_keys = [
        'postgresUser',
        'postgresPassword',
        'postgresDatabase'
    ]

    for key in required_keys:
        if key not in secret:
            raise ValueError(f"Key {key} not found in postgresSecret")



def validate_redis_secret(secret: str):
    required_keys = [
        'redisPassword',
    ]

    for key in required_keys:
        if key not in secret:
            raise ValueError(f"Key {key} not found in redisSecret")


def validate_storage_secret(secret: str):
    required_keys = [
        'storageType',
        'awsAccessKeyId',
        'awsSecretAccessKey',
        'awsRegion',
        'awsBucket',
        'virusCheckerType',
        'virusCheckerApiKey',
    ]

    for key in required_keys:
        if key not in secret:
            raise ValueError(f"Key {key} not found in storageSecret")


def validate_env(env: dict):
    required_secrets = [
        'backendSecret',
        'frontendSecret',
        'postgresSecret',
        'redisSecret',
        'storageSecret',
    ]

    for secret in required_secrets:
        if secret not in env:
            raise ValueError(f"Secret {secret} not found in env.json")

        if secret == 'backendSecret':
            validate_backend_secret(env[secret])

        if secret == 'frontendSecret':
            validate_frontend_secret(env[secret])

        if secret == 'postgresSecret':
            validate_postgres_secret(env[secret])
        
        if secret == 'redisSecret':
            validate_redis_secret(env[secret])

        if secret == 'storageSecret':
            validate_storage_secret(env[secret])

def write_secrets_to_file(env: dict):
    for key, secret in env.items():
        secrets_dir = Path("deployment", "secrets")
        if not secrets_dir.exists():
            secrets_dir.mkdir()

        with open(secrets_dir.joinpath(f"{key}.json"), "w") as f:
            json.dump(secret, f, indent=4)


def read_env_json(file: str) -> dict:
    with open(file, "r") as f:
        return json.load(f)


def main(file, environment):
    env = read_env_json(file)

    validate_env(env)

    write_secrets_to_file(env)

    configure_env_variables(environment)

    configure_templates(environment)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="Setup")
    parser.add_argument(
        "-f", "--file",
        dest="file",
        default=".env",
        help="Secret file [default = .secret]"
    )
    parser.add_argument(
        "-e", "--environment",
        dest="environment",
        default="prod",
        help="Selected Deployment Environment [default = prod, options = [prod, staging, dev]]"
    )

    args = parser.parse_args()

    main(**vars(args))
