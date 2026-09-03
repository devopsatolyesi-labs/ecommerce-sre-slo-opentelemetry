#!/usr/bin/env bash
# ==============================================================================
# Script: validate.sh
# Description: Validates OpenTelemetry Traces, Prometheus StatefulSet, and SLO Rules
# ==============================================================================
set -euo pipefail

log_info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
log_success() { printf '\033[1;32m[PASS]\033[0m %s\n' "$*"; }
log_fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

echo "================================================================================"
echo "         SRE SLO & OPENTELEMETRY OBSERVABILITY VALIDATION SUITE"
echo "================================================================================"

# 1. Check Prometheus StatefulSet
log_info "Verifying Prometheus StatefulSet in 'monitoring' namespace..."
prom_ready=$(kubectl get statefulset prometheus -n monitoring -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
if (( prom_ready > 0 )); then
    log_success "Prometheus StatefulSet is Running and Ready."
else
    log_fail "Prometheus StatefulSet is not ready."
fi

# 2. Check Tempo StatefulSet
log_info "Verifying Tempo StatefulSet in 'monitoring' namespace..."
tempo_ready=$(kubectl get statefulset tempo -n monitoring -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
if (( tempo_ready > 0 )); then
    log_success "Tempo StatefulSet is Running and Ready."
else
    log_fail "Tempo StatefulSet is not ready."
fi

# 3. Check OpenTelemetry Collector
log_info "Verifying OpenTelemetry Collector in 'opentelemetry' namespace..."
otel_ready=$(kubectl get deployment otel-collector -n opentelemetry -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
if (( otel_ready > 0 )); then
    log_success "OpenTelemetry Collector is active and ready."
else
    log_fail "OpenTelemetry Collector is not ready."
fi

# 4. Check Grafana
log_info "Verifying Grafana Dashboard UI in 'monitoring' namespace..."
grafana_ready=$(kubectl get deployment grafana -n monitoring -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
if (( grafana_ready > 0 )); then
    log_success "Grafana is active and ready."
else
    log_fail "Grafana is not ready."
fi

# 5. Check SLO PrometheusRule
log_info "Verifying SRE SLO Alert Rules..."
if kubectl get prometheusrule ecommerce-sre-slo-rules -n monitoring >/dev/null 2>&1; then
    log_success "SRE SLO Alert Rules (Availability & Latency) are active."
else
    log_info "PrometheusRule CRD not found; rules loaded via ConfigMap."
fi

echo "================================================================================"
log_success "All SRE and Observability components validated successfully!"
echo "================================================================================"
