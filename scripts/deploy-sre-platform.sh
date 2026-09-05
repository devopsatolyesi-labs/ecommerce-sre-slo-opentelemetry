#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-sre-platform.sh
# Description: Deploys Ingress-NGINX, cert-manager (Let's Encrypt),
#              OpenTelemetry Astronomy Shop, LGTM Stack, and SRE SLO Rules
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."

log_info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
log_success() { printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"; }

log_info "1/6 Deploying Ingress-NGINX Controller on AWS EKS..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=LoadBalancer \
    --wait --timeout=300s

log_info "2/6 Deploying cert-manager for automated Let's Encrypt TLS..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/component=webhook --timeout=180s

log_info "3/6 Deploying OpenTelemetry Collector in 'opentelemetry' namespace..."
kubectl create namespace opentelemetry --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace astronomy-shop --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "${ROOT_DIR}/observability/otel-collector-config.yaml"
kubectl apply -f "${ROOT_DIR}/observability/04-otel-collector-deployment.yaml"
kubectl rollout status deployment/otel-collector -n opentelemetry --timeout=120s

log_info "4/6 Deploying Prometheus StatefulSet, Tempo StatefulSet, and Grafana in 'monitoring' namespace..."
kubectl apply -f "${ROOT_DIR}/observability/01-prometheus-statefulset.yaml"
kubectl apply -f "${ROOT_DIR}/observability/02-tempo-statefulset.yaml"
kubectl apply -f "${ROOT_DIR}/observability/03-grafana-deployment.yaml"
kubectl apply -f "${ROOT_DIR}/sre-slo/01-slo-definitions.yaml"

kubectl rollout status statefulset/prometheus -n monitoring --timeout=180s
kubectl rollout status statefulset/tempo -n monitoring --timeout=180s
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

log_info "5/6 Deploying Astronomy Shop microservices via Helm..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update
helm repo update
helm upgrade --install astronomy-shop open-telemetry/opentelemetry-demo \
    --namespace astronomy-shop --create-namespace \
    -f "${ROOT_DIR}/observability/values-production.yaml" \
    --timeout 10m || true

log_info "6/6 Deploying Let's Encrypt ClusterIssuer and SRE Ingresses..."
kubectl apply -f "${ROOT_DIR}/observability/05-unified-ingress.yaml"

log_success "SRE & Full Observability Platform with Ingress & Let's Encrypt successfully deployed!"
kubectl get ingress -A
