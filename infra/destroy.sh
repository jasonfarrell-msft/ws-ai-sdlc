#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

ENVIRONMENT_NAME=""
CONFIRMATION=""

usage() {
  cat <<'EOF'
Usage:
  ./infra/destroy.sh --resource-group <name> \
    --environment-name <run-identifier> \
    --confirm <same-run-identifier>

Deletes only the deployment stack and resources belonging to the named fresh run.
The resource group and other generated environments are preserved. The resource
group must exist in the active Azure subscription.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group)
      [[ $# -ge 2 ]] || fail "--resource-group requires a value."
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --environment-name)
      [[ $# -ge 2 ]] || fail "--environment-name requires a value."
      ENVIRONMENT_NAME="$2"
      shift 2
      ;;
    --confirm)
      [[ $# -ge 2 ]] || fail "--confirm requires a value."
      CONFIRMATION="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument '$1'."
      ;;
  esac
done

[[ -n "$RESOURCE_GROUP" ]] || fail "--resource-group is required."
[[ "$ENVIRONMENT_NAME" =~ ^[a-f0-9]{18}$ ]] ||
  fail "--environment-name must be the 18-character identifier emitted by deploy.sh."
[[ "$CONFIRMATION" == "$ENVIRONMENT_NAME" ]] ||
  fail "--confirm must exactly match --environment-name."

require_command az
select_subscription
resolve_resource_location

STACK_NAME="azstk${ENVIRONMENT_NAME}"
az stack group show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STACK_NAME" \
  --output none

az stack group delete \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STACK_NAME" \
  --action-on-unmanage deleteAll \
  --yes

printf 'Deleted generated environment %s from %s. Resource group preserved.\n' \
  "$ENVIRONMENT_NAME" "$RESOURCE_GROUP"
