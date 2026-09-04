#!/usr/bin/env bash
# ==============================================================================
# Script: destroy-aws-infra.sh
# Description: Teardown AWS EKS and supporting infrastructure cleanly
# Usage: ./destroy-aws-infra.sh [dev|staging|prod]
# ==============================================================================
set -euo pipefail

ENV="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
TFVARS_FILE="${TERRAFORM_DIR}/environments/${ENV}.tfvars"

log_info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
log_success() { printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"; }
log_warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }

log_warn "Starting full teardown of environment: ${ENV}..."

# Clean K8s resources first so AWS Load Balancers are safely deregistered
if command -v kubectl >/dev/null 2>&1; then
    log_info "Uninstalling Astronomy Shop Helm release and observability stack if present..."
    helm uninstall astronomy-shop --namespace astronomy-shop 2>/dev/null || true
    kubectl delete -f "${SCRIPT_DIR}/../observability/" 2>/dev/null || true
    kubectl delete -f "${SCRIPT_DIR}/../sre-slo/" 2>/dev/null || true
fi

# Clean ACM certificates created for the domain
if command -v aws >/dev/null 2>&1; then
    log_info "Cleaning up any test ACM certificates in us-east-1..."
    for cert in $(aws acm list-certificates --region us-east-1 --query 'CertificateSummaryList[*].CertificateArn' --output text 2>/dev/null || true); do
        aws acm delete-certificate --certificate-arn "$cert" --region us-east-1 2>/dev/null || true
    done
fi

cd "${TERRAFORM_DIR}"
log_info "Running terraform destroy for environment: ${ENV}..."
terraform destroy -auto-approve -var-file="${TFVARS_FILE}" -var="enable_acm_ssl=false"

log_success "Environment ${ENV} infrastructure destroyed successfully ($0 AWS Cost)."
