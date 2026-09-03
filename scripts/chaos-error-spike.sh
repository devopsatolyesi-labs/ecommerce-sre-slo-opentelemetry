#!/usr/bin/env bash
# ==============================================================================
# Script: chaos-error-spike.sh
# Description: Simulates synthetic HTTP 500 error surge to burn SRE Error Budget
# ==============================================================================
set -euo pipefail

log_info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
log_warn() { printf '\033[1;33m[CHAOS]\033[0m %s\n' "$*"; }

DURATION_SECONDS=${1:-60}
CONCURRENCY=${2:-10}

log_warn "Starting synthetic Chaos Failure Injection for ${DURATION_SECONDS}s with concurrency ${CONCURRENCY}..."
log_info "This drill will deplete the 30-day Error Budget and trigger the ErrorBudgetBurnRateCritical alert."

END_TIME=$((SECONDS + DURATION_SECONDS))

while [ $SECONDS -lt $END_TIME ]; do
    for _ in $(seq 1 "$CONCURRENCY"); do
        # Sending faulty requests to trigger 500 responses
        curl -s -o /dev/null -w "%{http_code}\n" \
            -H "X-Simulate-Error: true" \
            http://frontend.astronomy-shop.svc.cluster.local:8080/cart || true &
    done
    wait
    sleep 0.5
done

log_info "Chaos injection completed. Open Grafana SLO Dashboard to observe Error Budget burn rate curve."
