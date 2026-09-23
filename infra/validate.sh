#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage:
  ./infra/validate.sh --resource-group <name>

The script requires an existing resource group, compiles Bicep, and runs a
resource-group what-if. All resources use the resource group's location. The
script never creates resources.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group)
      [[ $# -ge 2 ]] || fail "--resource-group requires a value."
      RESOURCE_GROUP="$2"
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
require_command az
require_azure_cli_version
select_subscription
resolve_resource_location

az bicep build --file "${INFRA_DIR}/main.bicep" --stdout >/dev/null
printf 'Bicep compilation passed.\n'

VALIDATION_IDENTIFIER="$(generate_run_identifier)"
az deployment group what-if \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "${INFRA_DIR}/main.bicep" \
  --parameters "${INFRA_DIR}/main.parameters.json" \
  --parameters \
    location="$RESOURCE_LOCATION" \
    environmentName="$VALIDATION_IDENTIFIER" \
    deploymentLabel="validation" \
  --no-pretty-print
