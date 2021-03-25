def add_starlark_lint_pipeline(pipelines):
    pipelines.append({
        "kind": "pipeline",
        "type": "docker",
        "name": "Lint Starlark",
        "trigger": {
            "event": {
                "exclude": [
                    "promote",
                    "cron"
                ],
                "include": [
                    "push"
                ]
            }
        },
        "platform": {
            "os": "linux",
            "arch": "amd64"
        },
        "steps": [
            {
                "name": "Lint",
                "depends_on": [
                    "clone"
                ],
                "image": "quay.io/agari/python",
                "commands": [
                    "flake8 --max-line-length=250 ./.drone.star"
                ]
            },
        ]
    })


def add_deployment_pipelines(pipelines):
    for env in pr_deployment_config["enabled_environments"]:
        steps = []
        for provider in pr_deployment_step_providers:
            steps.extend(provider(env))

        if len(steps) > 0:
            build_dependencies = pr_deployment_config["pipelines"]["build"] + additional_deployment_pipeline_dependencies
            pipelines.append({
                "kind": "pipeline",
                "type": "docker",
                "name": "Deploy {}".format(env),
                "trigger": pr_deployment_config[env]["deploy_when"],
                "depends_on": build_dependencies,
                "platform": {
                    "os": "linux",
                    "arch": "amd64"
                },
                "steps": steps
            })


def main(ctx):
    pipelines = []
    secrets = []
    add_pipelines(pipelines)
    add_secrets(secrets)
    return pipelines + secrets


def add_pipelines(pipelines):
    for definitions in [pipeline_definitions, pr_pipeline_definitions]:
        for definition in definitions:
            definition(pipelines)


def validate_no_duplicate_secrets():
    intersection = [k for k in vault_secret_definitions if k in pr_vault_secret_definitions]
    if intersection:
        fail("There are conflicting keys in vault_secret_definitions and pr_vault_secret_definitions, namely: " + str(intersection))  # noqa: F821


def add_secrets(secrets):
    validate_no_duplicate_secrets()

    all_vault_secret_definitions = vault_secret_definitions.items() + pr_vault_secret_definitions.items()
    for name, value in all_vault_secret_definitions:
        path, key = value.rsplit("/", 1)
        add_vault_secret(secrets, name, path, key)


def add_vault_secret(secrets, secret_name, vault_path, vault_key):
    secrets.append({
        "kind": "secret",
        "name": secret_name,
        "get": {
            "path": vault_path,
            "name": vault_key
        }
    })


# add vault secret definitions to this map.  both the keys and values should
# be strings with the key being the secret name within this build file and the
# value being the full path to the secret in vault.
vault_secret_definitions = {}

# add pipeline definitions to this array, each definition should be a reference to
# a method which adds 1 or more pipelines to a passed in list of pipelines.
pipeline_definitions = []

# add the names of additional pipelines that you want the deployment
# pipelines to be dependent on here.
additional_deployment_pipeline_dependencies = []

# below this line is reserved for agari-cli paved-road automation
# ---------------------------------------------------------------

# paved-road managed secret definitions
pr_vault_secret_definitions = {}

# paved-raod managed pipeline definitions
pr_pipeline_definitions = [
    add_starlark_lint_pipeline,
    add_deployment_pipelines
]

# paved-road managed deployment step providers
pr_deployment_step_providers = []

# paved-road deployment configuration
pr_deployment_config = {
    "enabled_environments": [],
    "pipelines": {
        "build": [
            "Lint Starlark"
        ]
    }
}
