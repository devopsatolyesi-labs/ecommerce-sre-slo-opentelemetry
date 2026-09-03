#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-sre-platform.sh
# Description: Deploys OpenTelemetry Astronomy Shop, LGTM Stack, and SRE SLO Rules
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."

log_info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
log_success() { printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"; }

log_info "1/4 Deploying OpenTelemetry Collector in 'opentelemetry' namespace..."
kubectl apply -f "${ROOT_DIR}/observability/otel-collector-config.yaml"
kubectl apply -f "${ROOT_DIR}/observability/04-otel-collector-deployment.yaml"
kubectl rollout status deployment/otel-collector -n opentelemetry --timeout=120s

log_info "2/4 Deploying Prometheus StatefulSet and Tempo StatefulSet in 'monitoring' namespace..."
kubectl apply -f "${ROOT_DIR}/observability/01-prometheus-statefulset.yaml"
kubectl apply -f "${ROOT_DIR}/observability/02-tempo-statefulset.yaml"
kubectl apply -f "${ROOT_DIR}/observability/03-grafana-deployment.yaml"
kubectl apply -f "${ROOT_DIR}/sre-slo/01-slo-definitions.yaml"

log_info "3/4 Waiting for Monitoring StatefulSets and Deployments to be Ready..."
kubectl rollout status statefulset/prometheus -n monitoring --timeout=180s
kubectl rollout status statefulset/tempo -n monitoring --timeout=180s
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

log_info "4/4 Deploying Astronomy Shop microservices via Helm..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update
helm repo update
helm upgrade --install astronomy-shop open-telemetry/opentelemetry-demo \
    --namespace astronomy-shop --create-namespace \
    --set default.env[0].name=OTEL_EXPORTER_OTLP_ENDPOINT \
    --set default.env[0].value="http://otel-collector.opentelemetry.svc.cluster.local:4317" \
    --wait --timeout 5m

log_success "SRE & Full Observability Platform successfully deployed!"
kubectl get statefulsets,pods,svc -n monitoring
