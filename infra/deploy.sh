#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

LABEL="aisdlc"
SKIP_CODE_DEPLOY="false"
PLACEHOLDER_IMAGE="mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
BACKEND_REPOSITORY="support-desk-api"

usage() {
  cat <<'EOF'
Usage:
  ./infra/deploy.sh --resource-group <name> [options]

Required:
  --resource-group
                 Existing Azure resource group in the active subscription.

Options:
  --label       Human-readable deployment label used in tags (default: aisdlc).
  --skip-code-deploy
                 Provision infrastructure with the placeholder image only.
  --help         Show this help.

Every run creates a new cryptographically random run identifier. It cannot be overridden.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group)
      [[ $# -ge 2 ]] || fail "--resource-group requires a value."
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --label)
      [[ $# -ge 2 ]] || fail "--label requires a value."
      LABEL="$2"
      shift 2
      ;;
    --skip-code-deploy)
      SKIP_CODE_DEPLOY="true"
      shift
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
[[ "$LABEL" =~ ^[a-zA-Z0-9-]{1,32}$ ]] ||
  fail "--label must contain 1-32 letters, numbers, or hyphens."

require_command az
require_azure_cli_version
require_command openssl
if [[ "$SKIP_CODE_DEPLOY" == "false" ]]; then
  require_command npm
  require_command zip
  require_command curl
fi
select_subscription
resolve_resource_location

RUN_IDENTIFIER="$(generate_run_identifier)"
STACK_NAME="azstk${RUN_IDENTIFIER}"
CREATED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
DEPLOYED_BY="$(az ad signed-in-user show --query displayName --output tsv 2>/dev/null || true)"
if [[ -z "$DEPLOYED_BY" ]]; then
  DEPLOYED_BY="$(az account show --query user.name --output tsv)"
fi

printf 'Deploying fresh run %s to %s in %s.\n' \
  "$RUN_IDENTIFIER" "$RESOURCE_GROUP" "$RESOURCE_LOCATION"

deploy_stack() {
  local image="$1"
  local external_ingress="$2"
  local enable_diagnostics="$3"
  az stack group create \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STACK_NAME" \
    --template-file "${INFRA_DIR}/main.bicep" \
    --parameters "${INFRA_DIR}/main.parameters.json" \
    --parameters \
      location="$RESOURCE_LOCATION" \
      environmentName="$RUN_IDENTIFIER" \
      deploymentLabel="$LABEL" \
      deployedBy="$DEPLOYED_BY" \
      createdAt="$CREATED_AT" \
      containerImage="$image" \
      externalIngressEnabled="$external_ingress" \
      enableDiagnostics="$enable_diagnostics" \
    --action-on-unmanage deleteAll \
    --deny-settings-mode None \
    --yes \
    --output none
}

deploy_stack "$PLACEHOLDER_IMAGE" false false

REGISTRY_NAME="$(stack_output "$STACK_NAME" registryName)"
REGISTRY_SERVER="$(stack_output "$STACK_NAME" registryLoginServer)"
CONTAINER_APP_NAME="$(stack_output "$STACK_NAME" containerAppName)"
FRONTEND_APP_NAME="$(stack_output "$STACK_NAME" frontendAppName)"
BACKEND_URL="$(stack_output "$STACK_NAME" backendUrl)"
FRONTEND_URL="$(stack_output "$STACK_NAME" frontendUrl)"

if [[ "$SKIP_CODE_DEPLOY" == "false" ]]; then
  IMAGE_TAG="$RUN_IDENTIFIER"
  az acr build \
    --subscription "$SUBSCRIPTION_ID" \
    --registry "$REGISTRY_NAME" \
    --image "${BACKEND_REPOSITORY}:${IMAGE_TAG}" \
    --file "${PROJECT_ROOT}/src/backend/Dockerfile" \
    "${PROJECT_ROOT}/src/backend" \
    --output none

  IMAGE_DIGEST="$(az acr manifest show-metadata \
    --subscription "$SUBSCRIPTION_ID" \
    --registry "$REGISTRY_NAME" \
    --name "${BACKEND_REPOSITORY}:${IMAGE_TAG}" \
    --query digest \
    --output tsv)"
  [[ -n "$IMAGE_DIGEST" ]] || fail "ACR did not return a digest for the backend image."
  BACKEND_IMAGE="${REGISTRY_SERVER}/${BACKEND_REPOSITORY}@${IMAGE_DIGEST}"

  deployed="false"
  delay=10
  for attempt in 1 2 3 4 5 6; do
    printf 'Applying backend image (attempt %s of 6).\n' "$attempt"
    if deploy_stack "$BACKEND_IMAGE" true true; then
      deployed="true"
      break
    fi
    if [[ "$attempt" -lt 6 ]]; then
      printf 'Waiting %s seconds for AcrPull role propagation.\n' "$delay"
      sleep "$delay"
      delay=$((delay * 2))
    fi
  done
  [[ "$deployed" == "true" ]] ||
    fail "The backend image could not be applied after AcrPull propagation retries."

  ZIP_PATH="${INFRA_DIR}/frontend-${RUN_IDENTIFIER}.zip"
  trap 'rm -f "$ZIP_PATH"' EXIT
  (
    cd "${PROJECT_ROOT}/src/frontend"
    npm ci --replace-registry-host=never
    VITE_API_BASE_URL="$BACKEND_URL" npm run build
    cd dist
    zip -q -r "$ZIP_PATH" .
  )

  az webapp deploy \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$FRONTEND_APP_NAME" \
    --src-path "$ZIP_PATH" \
    --type zip \
    --clean true \
    --restart true \
    --output none
  rm -f "$ZIP_PATH"
  trap - EXIT

  curl --fail --silent --show-error --retry 8 --retry-delay 10 \
    "${BACKEND_URL}/api/health" >/dev/null
  curl --fail --silent --show-error --retry 8 --retry-delay 10 \
    "$FRONTEND_URL" >/dev/null
fi

cat <<EOF

Deployment complete.
Run identifier:  ${RUN_IDENTIFIER}
Deployment stack: ${STACK_NAME}
Resource group:   ${RESOURCE_GROUP}
Location:         ${RESOURCE_LOCATION}
Frontend URL:     ${FRONTEND_URL}
Backend URL:      ${BACKEND_URL}
Container App:    ${CONTAINER_APP_NAME}
Registry:         ${REGISTRY_NAME}

To remove only this generated environment:
./infra/destroy.sh --resource-group '${RESOURCE_GROUP}' --environment-name '${RUN_IDENTIFIER}' --confirm '${RUN_IDENTIFIER}'
EOF
