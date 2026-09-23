#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

ENVIRONMENT_NAME=""
GITHUB_REPOSITORY="jasonfarrell-msft/ws-ai-sdlc"
CONTAINER_REGISTRY=""
CONTAINER_APP=""
APP_SERVICE=""
BACKEND_URL=""

readonly BACKEND_GITHUB_ENVIRONMENT="workshop-backend"
readonly FRONTEND_GITHUB_ENVIRONMENT="workshop-frontend"

usage() {
  cat <<'EOF'
Usage:
  ./infra/configure-github-actions.sh \
    --resource-group <name> \
    --environment-name <run-identifier> \
    --container-registry <name> \
    --container-app <name> \
    --app-service <name> \
    --backend-url <https-origin> \
    [--repository <owner/name>]

Creates two deployment identities, resource-scoped Azure role assignments,
GitHub OIDC federated credentials, protected GitHub environments, and the
variables required by the backend and frontend workflows.
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
    --repository)
      [[ $# -ge 2 ]] || fail "--repository requires a value."
      GITHUB_REPOSITORY="$2"
      shift 2
      ;;
    --container-registry)
      [[ $# -ge 2 ]] || fail "--container-registry requires a value."
      CONTAINER_REGISTRY="$2"
      shift 2
      ;;
    --container-app)
      [[ $# -ge 2 ]] || fail "--container-app requires a value."
      CONTAINER_APP="$2"
      shift 2
      ;;
    --app-service)
      [[ $# -ge 2 ]] || fail "--app-service requires a value."
      APP_SERVICE="$2"
      shift 2
      ;;
    --backend-url)
      [[ $# -ge 2 ]] || fail "--backend-url requires a value."
      BACKEND_URL="$2"
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
[[ "$GITHUB_REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] ||
  fail "--repository must use the owner/name format."
[[ -n "$CONTAINER_REGISTRY" ]] || fail "--container-registry is required."
[[ -n "$CONTAINER_APP" ]] || fail "--container-app is required."
[[ -n "$APP_SERVICE" ]] || fail "--app-service is required."
[[ "$BACKEND_URL" =~ ^https://[^/]+$ ]] ||
  fail "--backend-url must be an HTTPS origin without a trailing slash."

require_command az
require_command gh
require_azure_cli_version
select_subscription
resolve_resource_location

TENANT_ID="$(az account show --query tenantId --output tsv)"
[[ -n "$TENANT_ID" ]] || fail "Azure CLI did not return a tenant ID."

IS_REPOSITORY_ADMIN="$(gh api "repos/${GITHUB_REPOSITORY}" \
  --jq '.permissions.admin' 2>/dev/null)" ||
  fail "GitHub CLI cannot access repository '${GITHUB_REPOSITORY}'. Run 'gh auth login'."
[[ "$IS_REPOSITORY_ADMIN" == "true" ]] ||
  fail "Administrator access to '${GITHUB_REPOSITORY}' is required."

BACKEND_IDENTITY="id-gha-be-${ENVIRONMENT_NAME}"
FRONTEND_IDENTITY="id-gha-fe-${ENVIRONMENT_NAME}"

ensure_identity() {
  local identity_name="$1"
  if ! az identity show \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$identity_name" \
    --output none 2>/dev/null
  then
    az identity create \
      --subscription "$SUBSCRIPTION_ID" \
      --resource-group "$RESOURCE_GROUP" \
      --name "$identity_name" \
      --location "$RESOURCE_LOCATION" \
      --output none
  fi
}

ensure_federated_credential() {
  local identity_name="$1"
  local credential_name="$2"
  local github_environment="$3"
  local expected_subject="repo:${GITHUB_REPOSITORY}:environment:${github_environment}"
  local existing_subject

  existing_subject="$(az identity federated-credential show \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" \
    --identity-name "$identity_name" \
    --name "$credential_name" \
    --query subject \
    --output tsv 2>/dev/null || true)"

  if [[ -z "$existing_subject" ]]; then
    az identity federated-credential create \
      --subscription "$SUBSCRIPTION_ID" \
      --resource-group "$RESOURCE_GROUP" \
      --identity-name "$identity_name" \
      --name "$credential_name" \
      --issuer "https://token.actions.githubusercontent.com" \
      --subject "$expected_subject" \
      --audiences "api://AzureADTokenExchange" \
      --output none
  elif [[ "$existing_subject" != "$expected_subject" ]]; then
    fail "Federated credential '${credential_name}' has an unexpected subject."
  fi
}

ensure_role_assignment() {
  local principal_id="$1"
  local role_name="$2"
  local scope="$3"
  local assignment_count

  assignment_count="$(az role assignment list \
    --subscription "$SUBSCRIPTION_ID" \
    --assignee-object-id "$principal_id" \
    --role "$role_name" \
    --scope "$scope" \
    --query 'length(@)' \
    --output tsv)" ||
    fail "Could not inspect role '${role_name}' at scope '${scope}'."

  if [[ "$assignment_count" == "0" ]]; then
    for attempt in {1..6}; do
      if az role assignment create \
        --subscription "$SUBSCRIPTION_ID" \
        --assignee-object-id "$principal_id" \
        --assignee-principal-type ServicePrincipal \
        --role "$role_name" \
        --scope "$scope" \
        --output none
      then
        return
      fi
      [[ "$attempt" -lt 6 ]] || break
      printf 'Waiting for managed identity propagation before retrying role assignment.\n'
      sleep 10
    done
    fail "Could not assign role '${role_name}' at scope '${scope}'."
  fi
}

configure_github_environment() {
  local github_environment="$1"
  local main_policy_id
  local stale_policy_ids

  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "repos/${GITHUB_REPOSITORY}/environments/${github_environment}" \
    --input - >/dev/null <<'EOF'
{
  "wait_timer": 0,
  "reviewers": [],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF

  stale_policy_ids="$(gh api \
    "repos/${GITHUB_REPOSITORY}/environments/${github_environment}/deployment-branch-policies" \
    --paginate \
    --jq '.branch_policies[] |
      select(.name != "main" or .type != "branch") |
      .id')" ||
    fail "Could not inspect branch policies for '${github_environment}'."

  while read -r policy_id; do
    [[ -n "$policy_id" ]] || continue
    gh api \
      --method DELETE \
      "repos/${GITHUB_REPOSITORY}/environments/${github_environment}/deployment-branch-policies/${policy_id}" \
      >/dev/null
  done <<< "$stale_policy_ids"

  main_policy_id="$(gh api \
    "repos/${GITHUB_REPOSITORY}/environments/${github_environment}/deployment-branch-policies" \
    --jq '.branch_policies[] |
      select(.name == "main" and .type == "branch") |
      .id')"
  if [[ -z "$main_policy_id" ]]; then
    gh api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      "repos/${GITHUB_REPOSITORY}/environments/${github_environment}/deployment-branch-policies" \
      -f name="main" \
      -f type="branch" \
      >/dev/null
  fi
}

ensure_identity "$BACKEND_IDENTITY"
ensure_identity "$FRONTEND_IDENTITY"

BACKEND_CLIENT_ID="$(az identity show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$BACKEND_IDENTITY" \
  --query clientId \
  --output tsv)"
BACKEND_PRINCIPAL_ID="$(az identity show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$BACKEND_IDENTITY" \
  --query principalId \
  --output tsv)"
FRONTEND_CLIENT_ID="$(az identity show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FRONTEND_IDENTITY" \
  --query clientId \
  --output tsv)"
FRONTEND_PRINCIPAL_ID="$(az identity show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FRONTEND_IDENTITY" \
  --query principalId \
  --output tsv)"

ensure_federated_credential \
  "$BACKEND_IDENTITY" \
  "github-workshop-backend" \
  "$BACKEND_GITHUB_ENVIRONMENT"
ensure_federated_credential \
  "$FRONTEND_IDENTITY" \
  "github-workshop-frontend" \
  "$FRONTEND_GITHUB_ENVIRONMENT"

ACR_ID="$(az acr show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_REGISTRY" \
  --query id \
  --output tsv)"
CONTAINER_APP_ID="$(az containerapp show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_APP" \
  --query id \
  --output tsv)"
APP_SERVICE_ID="$(az webapp show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_SERVICE" \
  --query id \
  --output tsv)"

ensure_role_assignment \
  "$BACKEND_PRINCIPAL_ID" \
  "Container Registry Tasks Contributor" \
  "$ACR_ID"
ensure_role_assignment "$BACKEND_PRINCIPAL_ID" "AcrPull" "$ACR_ID"
ensure_role_assignment \
  "$BACKEND_PRINCIPAL_ID" \
  "Container Apps Contributor" \
  "$CONTAINER_APP_ID"
ensure_role_assignment \
  "$FRONTEND_PRINCIPAL_ID" \
  "Website Contributor" \
  "$APP_SERVICE_ID"

configure_github_environment "$BACKEND_GITHUB_ENVIRONMENT"
configure_github_environment "$FRONTEND_GITHUB_ENVIRONMENT"

gh variable set AZURE_CLIENT_ID \
  --repo "$GITHUB_REPOSITORY" \
  --env "$BACKEND_GITHUB_ENVIRONMENT" \
  --body "$BACKEND_CLIENT_ID"
gh variable set AZURE_TENANT_ID \
  --repo "$GITHUB_REPOSITORY" \
  --env "$BACKEND_GITHUB_ENVIRONMENT" \
  --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID \
  --repo "$GITHUB_REPOSITORY" \
  --env "$BACKEND_GITHUB_ENVIRONMENT" \
  --body "$SUBSCRIPTION_ID"
gh variable set AZURE_RESOURCE_GROUP \
  --repo "$GITHUB_REPOSITORY" \
  --env "$BACKEND_GITHUB_ENVIRONMENT" \
  --body "$RESOURCE_GROUP"
gh variable set AZURE_CONTAINER_REGISTRY \
  --repo "$GITHUB_REPOSITORY" \
  --env "$BACKEND_GITHUB_ENVIRONMENT" \
  --body "$CONTAINER_REGISTRY"
gh variable set AZURE_CONTAINER_APP \
  --repo "$GITHUB_REPOSITORY" \
  --env "$BACKEND_GITHUB_ENVIRONMENT" \
  --body "$CONTAINER_APP"

gh variable set AZURE_CLIENT_ID \
  --repo "$GITHUB_REPOSITORY" \
  --env "$FRONTEND_GITHUB_ENVIRONMENT" \
  --body "$FRONTEND_CLIENT_ID"
gh variable set AZURE_TENANT_ID \
  --repo "$GITHUB_REPOSITORY" \
  --env "$FRONTEND_GITHUB_ENVIRONMENT" \
  --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID \
  --repo "$GITHUB_REPOSITORY" \
  --env "$FRONTEND_GITHUB_ENVIRONMENT" \
  --body "$SUBSCRIPTION_ID"
gh variable set AZURE_RESOURCE_GROUP \
  --repo "$GITHUB_REPOSITORY" \
  --env "$FRONTEND_GITHUB_ENVIRONMENT" \
  --body "$RESOURCE_GROUP"
gh variable set AZURE_APP_SERVICE \
  --repo "$GITHUB_REPOSITORY" \
  --env "$FRONTEND_GITHUB_ENVIRONMENT" \
  --body "$APP_SERVICE"

gh variable set AZURE_BACKEND_URL \
  --repo "$GITHUB_REPOSITORY" \
  --body "$BACKEND_URL"

cat <<EOF

GitHub Actions access configured.
Repository:           ${GITHUB_REPOSITORY}
Backend environment:  ${BACKEND_GITHUB_ENVIRONMENT}
Frontend environment: ${FRONTEND_GITHUB_ENVIRONMENT}
Backend identity:     ${BACKEND_IDENTITY}
Frontend identity:    ${FRONTEND_IDENTITY}

Pushes to main now deploy changed backend or frontend files automatically.
EOF
