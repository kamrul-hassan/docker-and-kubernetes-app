#!/usr/bin/env bash
# One-time Azure + GitHub setup. Run in Azure Cloud Shell (bash), WSL or Git Bash
# with the Azure CLI and GitHub CLI signed in:  az login  &&  gh auth login
#
#   ./infra/bootstrap.sh <github-owner/repo> [resource-group] [location]
#
# It will:
#   1. create the resource group and deploy infra/main.bicep (ACR, AKS, PostgreSQL)
#   2. create a managed identity with federated credentials for GitHub Actions (OIDC, no stored secrets)
#   3. grant that identity access to the resource group and ACR
#   4. store the IDs, names and DB connection string as GitHub secrets/variables
set -euo pipefail

REPO="${1:?usage: bootstrap.sh <owner/repo> [resource-group] [location]}"
RG="${2:-rg-taskflow}"
LOCATION="${3:-southeastasia}"   # resource group metadata only; see main.bicepparam for resource regions
ID_NAME="taskflow-github-deploy"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

if [[ -z "${POSTGRES_ADMIN_PASSWORD:-}" ]]; then
  POSTGRES_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)Aa1!"
fi
export POSTGRES_ADMIN_PASSWORD

echo "==> Resource group $RG ($LOCATION)"
az group create -n "$RG" -l "$LOCATION" -o none

echo "==> Deploying infrastructure (AKS takes ~10 minutes)"
OUT=$(az deployment group create -g "$RG" -n taskflow-infra \
  -f "$(dirname "$0")/main.bicep" -p "$(dirname "$0")/main.bicepparam" \
  --query properties.outputs -o json)

ACR_NAME=$(jq -r .acrName.value <<<"$OUT")
AKS_NAME=$(jq -r .aksName.value <<<"$OUT")
PG_HOST=$(jq -r .postgresHost.value <<<"$OUT")
PG_DB=$(jq -r .postgresDatabase.value <<<"$OUT")
PG_USER=taskflowadmin

echo "==> Managed identity for GitHub OIDC: $ID_NAME"
# A user-assigned managed identity needs only Azure RBAC rights on the resource group,
# not Entra ID app-registration rights (often blocked for guest or restricted users).
az identity create -g "$RG" -n "$ID_NAME" -o none
CLIENT_ID=$(az identity show -g "$RG" -n "$ID_NAME" --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show -g "$RG" -n "$ID_NAME" --query principalId -o tsv)

add_fic() {  # name subject
  if ! az identity federated-credential show -g "$RG" --identity-name "$ID_NAME" -n "$1" -o none 2>/dev/null; then
    az identity federated-credential create -g "$RG" --identity-name "$ID_NAME" -n "$1" \
      --issuer "https://token.actions.githubusercontent.com" \
      --subject "$2" --audiences "api://AzureADTokenExchange" -o none
  fi
}
add_fic "main-branch" "repo:${REPO}:ref:refs/heads/main"
add_fic "production-env" "repo:${REPO}:environment:production"
# Newer GitHub repos send ID-based subjects (repo:owner@<ownerId>/name@<repoId>:...); register those too.
OWNER_ID=$(gh api "repos/${REPO}" --jq .owner.id)
REPO_ID=$(gh api "repos/${REPO}" --jq .id)
ID_SUBJECT="repo:${REPO%%/*}@${OWNER_ID}/${REPO##*/}@${REPO_ID}"
add_fic "main-branch-ids" "${ID_SUBJECT}:ref:refs/heads/main"
add_fic "production-env-ids" "${ID_SUBJECT}:environment:production"

echo "==> Role assignments"
RG_ID=$(az group show -n "$RG" --query id -o tsv)
ACR_ID=$(az acr show -n "$ACR_NAME" --query id -o tsv)
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role Contributor --scope "$RG_ID" -o none 2>/dev/null || true
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role AcrPush --scope "$ACR_ID" -o none 2>/dev/null || true

echo "==> GitHub secrets and variables on $REPO"
gh api -X PUT "repos/${REPO}/environments/production" --silent
gh secret set AZURE_CLIENT_ID       -R "$REPO" -b "$CLIENT_ID"
gh secret set AZURE_TENANT_ID       -R "$REPO" -b "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID -R "$REPO" -b "$SUBSCRIPTION_ID"
gh secret set DB_CONNECTION_STRING  -R "$REPO" \
  -b "Host=${PG_HOST};Port=5432;Database=${PG_DB};Username=${PG_USER};Password=${POSTGRES_ADMIN_PASSWORD};SSL Mode=Require"
gh variable set AZURE_RESOURCE_GROUP -R "$REPO" -b "$RG"
gh variable set ACR_NAME             -R "$REPO" -b "$ACR_NAME"
gh variable set AKS_NAME             -R "$REPO" -b "$AKS_NAME"

cat <<DONE

Done.
  ACR:        $ACR_NAME
  AKS:        $AKS_NAME
  PostgreSQL: $PG_HOST / $PG_DB

Push to main to trigger the CD workflow. When it finishes, get the public IP with:
  az aks get-credentials -g $RG -n $AKS_NAME
  kubectl get ingress -n taskflow
DONE
