#!/bin/sh -l

set -ex

if [ -n "$INPUT_PATH" ]; then
  # Allow user to change directories in which to run Fly commands.
  cd "$INPUT_PATH" || exit
fi

PR_NUMBER=$(jq -r .number /github/workflow/event.json)
if [ -z "$PR_NUMBER" ]; then
  echo "This action only supports pull_request actions."
  exit 1
fi

REPO_NAME=$(echo $GITHUB_REPOSITORY | tr "/" "-")
EVENT_TYPE=$(jq -r .action /github/workflow/event.json)

# Default the Fly app name to pr-{number}-{repo_name}
app="${INPUT_NAME:-pr-$PR_NUMBER-$REPO_NAME}"
region="${INPUT_REGION:-${FLY_REGION:-iad}}"
org="${INPUT_ORG:-${FLY_ORG:-personal}}"
config="${INPUT_CONFIG:-fly.toml}"

if ! echo "$app" | grep "$PR_NUMBER"; then
  echo "For safety, this action requires the app's name to contain the PR number."
  exit 1
fi

# PR was closed - remove the Fly app if one exists and exit.
if [ "$EVENT_TYPE" = "closed" ]; then
  flyctl apps destroy "$app" -y || true
  exit 0
fi

# Change PHX_HOST to the PR hostname prior to deploying
dasel put -t string -v "$app.fly.dev" -f "$config" -r toml '.env.PHX_HOST'

# Deploy the Fly app, creating it first if needed.
if ! flyctl status --app "$app"; then
  # Backup the original config file since 'flyctl launch' messes up the [build.args] section
  cp "$config" "$config.bak"

  # Deploy with modified config file. Fly.io creates the postgres db even with
  # the --no-deploy flag, so we need to manually deploy the app
  # flyctl launch --no-deploy --copy-config --name "$app" --region "$region" --org "$org" --ha=$INPUT_HA
  # 1. fly apps create
  # 2. fly ips allocate v4
  # 3. fly ips allocate v6
  # 4. fly secrets set
  # 5. fly deploy
  # https://community.fly.io/t/launch-an-app-without-a-database/20245

  # 1. Create the app
  # https://fly.io/docs/flyctl/apps-create/
  flyctl apps create --name "$app" --org "$org"

  # 2. Allocate an IPv4 address
  # https://fly.io/docs/flyctl/ips-allocate-v4/
  flyctl ips allocate-v4 --app "$app" --config "$config" --region "$region"

  # 3. Allocate an IPv6 address
  # https://fly.io/docs/flyctl/ips-allocate-v6/
  flyctl ips allocate-v6 --app "$app" --config "$config" --region "$region"

  # Restore the original config file
  cp "$config.bak" "$config"
fi

# 4. Set the secrets
# https://fly.io/docs/flyctl/secrets-set/
if [ -n "$INPUT_SECRETS" ]; then
  echo $INPUT_SECRETS | tr " " "\n" | flyctl secrets import --app "$app"
fi

# Attach postgres cluster to the app if specified.
if [ -n "$INPUT_POSTGRES" ]; then
  flyctl postgres attach "$INPUT_POSTGRES" --app "$app" --yes || true
fi

# 5. Trigger the deploy of the new version.
# https://fly.io/docs/flyctl/deploy/
echo "Contents of config $config file: " && cat "$config"
if [ -n "$INPUT_VMSIZE" ]; then
  flyctl deploy --config "$config" --app "$app" --regions "$region" --strategy immediate --ha=$INPUT_HA --vm-size "$INPUT_VMSIZE"
else
  flyctl deploy --config "$config" --app "$app" --regions "$region" --strategy immediate --ha=$INPUT_HA --vm-cpu-kind "$INPUT_CPUKIND" --vm-cpus $INPUT_CPU --vm-memory "$INPUT_MEMORY"
fi

# Make some info available to the GitHub workflow.
flyctl status --app "$app" --json >status.json
hostname=$(jq -r .Hostname status.json)
appid=$(jq -r .ID status.json)
echo "hostname=$hostname" >>$GITHUB_OUTPUT
echo "url=https://$hostname" >>$GITHUB_OUTPUT
echo "id=$appid" >>$GITHUB_OUTPUT
echo "name=$app" >>$GITHUB_OUTPUT
