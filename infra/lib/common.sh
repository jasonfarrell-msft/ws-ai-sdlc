#!/usr/bin/env bash

set -euo pipefail

readonly INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"

SUBSCRIPTION_ID=""
RESOURCE_GROUP=""
RESOURCE_LOCATION=""

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' is not installed."
}

require_azure_cli_version() {
  local current_version
  current_version="$(az version --query '"azure-cli"' --output tsv)"
  if ! awk -v current="$current_version" 'BEGIN {
    split(current, actual, ".")
    split("2.48.1", required, ".")
    for (i = 1; i <= 3; i++) {
      if ((actual[i] + 0) > (required[i] + 0)) exit 0
      if ((actual[i] + 0) < (required[i] + 0)) exit 1
    }
    exit 0
  }'; then
    fail "Azure CLI 2.48.1 or newer is required."
  fi
}

select_subscription() {
  SUBSCRIPTION_ID="$(az account show --query id --output tsv 2>/dev/null)" ||
    fail "Azure CLI is not signed in. Run 'az login' and select a subscription."
  [[ -n "$SUBSCRIPTION_ID" ]] ||
    fail "Azure CLI did not return an active subscription."
}

resolve_resource_location() {
  RESOURCE_LOCATION="$(az group show \
    --subscription "$SUBSCRIPTION_ID" \
    --name "$RESOURCE_GROUP" \
    --query location \
    --output tsv 2>/dev/null)" ||
    fail "Resource group '$RESOURCE_GROUP' does not exist in the active subscription."
  RESOURCE_LOCATION="$(printf '%s' "$RESOURCE_LOCATION" | tr '[:upper:]' '[:lower:]')"
  [[ -n "$RESOURCE_LOCATION" ]] ||
    fail "Azure did not return a location for resource group '$RESOURCE_GROUP'."
}

generate_run_identifier() {
  require_command openssl
  printf '%s%s' "$(date -u +%y%m%d)" "$(openssl rand -hex 6)"
}

stack_output() {
  local stack_name="$1"
  local output_name="$2"
  local value

  value="$(az stack group show \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$stack_name" \
    --query "outputs.${output_name}.value" \
    --output tsv)"
  [[ -n "$value" ]] ||
    fail "Stack '$stack_name' did not return output '$output_name'."
  printf '%s\n' "$value"
}
