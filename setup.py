from base64 import b64decode, b64encode
from dotenv import load_dotenv
from envsubst import envsubst
from pathlib import Path, PosixPath
import argparse
import warnings
import json
import os


def write_template(template: str, output: str):
    with open(template, 'r') as template,\
         open(output, 'w') as output:
        output.write(envsubst(template.read()))

def configure_templates(environment: str):
    if not environment in ("prod", "staging", "local", "dev"):
        raise ValueError("Invalid Environment Selected")

    match environment:
        case "local":
            DOMAIN = "local.hideyoshi.com.br"
            API_DOMAIN = "api.local.hideyoshi.com.br"
        case "staging":
            DOMAIN = "staging.hideyoshi.com.br"
            API_DOMAIN = "api.staging.hideyoshi.com.br"
        case _:
            DOMAIN = "hideyoshi.com.br"
            API_DOMAIN = "api.hideyoshi.com.br"

    os.environ["DOMAIN"] = DOMAIN
    os.environ["API_DOMAIN"] = API_DOMAIN

    write_template(
        "template/cert-manager/cert-manager-certificate.template.yaml", 
        "deployment/cert-manager/cert-manager-certificate.yaml"
    )

    write_template(
        "template/nginx-ingress/nginx-ingress-api.yaml",
        "deployment/nginx-ingress/nginx-ingress-api.yaml"
    )

    write_template(
        "template/nginx-ingress/nginx-ingress-root.yaml",
        "deployment/nginx-ingress/nginx-ingress-root.yaml"
    )


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
