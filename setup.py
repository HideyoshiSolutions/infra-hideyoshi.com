from base64 import b64decode, b64encode
from dotenv import load_dotenv
from envsubst import envsubst
from pathlib import Path, PosixPath
import argparse
import os

ENV_SECRETS = [
    "TOKEN_SECRET",
    "ACCESS_TOKEN_DURATION",
    "REFRESH_TOKEN_DURATION",
    "DEFAULT_USER_FULLNAME",
    "DEFAULT_USER_EMAIL",
    "DEFAULT_USER_USERNAME",
    "DEFAULT_USER_PASSWORD",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "POSTGRES_DB",
    "REDIS_PASSWORD",
]

REPO_SECRETS = [
    "FRONTEND_PATH",
    "BACKEND_URL",
    "BACKEND_OAUTH_URL",
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET",
    "GOOGLE_REDIRECT_URL",
    "OAUTH_GITHUB_CLIENT_ID",
    "OAUTH_GITHUB_CLIENT_SECRET",
    "OAUTH_GITHUB_REDIRECT_URL",
]


def setting_environment(environment: str):
    if not environment in ("prod", "staging", "dev"):
        raise ValueError("Invalid Environment Selected")

    match environment:
        case "staging":
            DOMAIN = "staging.hideyoshi.com.br"
            API_DOMAIN = "api.staging.hideyoshi.com.br"
        case _:
            DOMAIN = "hideyoshi.com.br"
            API_DOMAIN = "api.hideyoshi.com.br"

    os.environ["DOMAIN"] = DOMAIN
    os.environ["API_DOMAIN"] = API_DOMAIN


def load_secret_file(file: str):
    secret_file_path = Path(file)
    if not secret_file_path.exists():
        raise FileNotFoundError("Secret File Doesn't Exists")

    load_dotenv(dotenv_path=secret_file_path)


def fetch_env_variables():
    for env in ENV_SECRETS:
        if not os.environ[env]:
            raise ValueError(f"Environment Variable {env} is Empty")

        value = os.environ[env].encode("utf-8")
        os.environ[env] = b64encode(value).decode()


def validate_env_variables():
    for env in (ENV_SECRETS + REPO_SECRETS):
        if not os.environ[env]:
            raise ValueError(f"Environment Variable {env} is Empty")


def envsubst_file(file: PosixPath):
    with open(file) as f:
        formated_file = envsubst(f.read())

    new_file = Path("deployment") \
        .joinpath(*[part.split('.')[0] for part in file.parts if part != "template"]) \
        .with_suffix(".yaml")

    with open(new_file, 'w') as f:
        f.write(formated_file)


def substitute_secrets_from_templates():
    for subdir in Path("template").glob("*"):
        for file in subdir.glob("*.yaml"):
            envsubst_file(file)


def main(file, environment):
    setting_environment(environment)

    load_secret_file(file)

    fetch_env_variables()

    validate_env_variables()

    substitute_secrets_from_templates()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="Setup")
    parser.add_argument(
        "-f", "--file",
        dest="file",
        default=".secret",
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