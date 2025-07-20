#!/bin/bash
# Production Health Check Script

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header "Production Data Platform Health Check"

# Check if we can connect to cluster
if ! kubectl cluster-info &>/dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check namespace
if kubectl get namespace data-platform &>/dev/null; then
    print_success "Namespace 'data-platform' exists"
else
    print_error "Namespace 'data-platform' not found"
    exit 1
fi

# Check pods
echo ""
print_info "Pod Status Overview:"
kubectl get pods -n data-platform -o wide

# Count pod states
total_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | wc -l)
running_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Running" | wc -l)
pending_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Pending" | wc -l)
failed_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep -E "Error|CrashLoopBackOff|ImagePullBackOff" | wc -l)
completed_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Completed" | wc -l)

echo ""
print_info "Pod Summary:"
echo "  Total: $total_pods"
echo "  Running: $running_pods"
echo "  Completed: $completed_pods"
if [ "$pending_pods" -gt 0 ]; then
    print_warning "Pending: $pending_pods"
fi
if [ "$failed_pods" -gt 0 ]; then
    print_error "Failed: $failed_pods"
fi

# Check services
echo ""
print_info "Service Status:"
kubectl get svc -n data-platform -o wide

# Check storage
echo ""
print_info "Storage Status:"
kubectl get pvc -n data-platform

# Check resource usage if metrics available
echo ""
print_info "Resource Usage:"
kubectl top pods -n data-platform 2>/dev/null || print_warning "Metrics server not available"

# Detailed health checks
echo ""
print_header "Component Health Details"

# PostgreSQL
PG_STATUS=$(kubectl get pods -n data-platform -l app=postgres --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$PG_STATUS" -eq 1 ]; then
    print_success "PostgreSQL is healthy"
else
    print_error "PostgreSQL issues detected"
fi

# Redis
REDIS_STATUS=$(kubectl get pods -n data-platform -l app=redis --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$REDIS_STATUS" -eq 1 ]; then
    print_success "Redis is healthy"
else
    print_error "Redis issues detected"
fi

# Airflow components
AIRFLOW_WEBSERVER=$(kubectl get pods -n data-platform -l component=webserver --no-headers 2>/dev/null | grep "Running" | wc -l)
AIRFLOW_SCHEDULER=$(kubectl get pods -n data-platform -l component=scheduler --no-headers 2>/dev/null | grep "Running" | wc -l)
AIRFLOW_WORKERS=$(kubectl get pods -n data-platform -l component=worker --no-headers 2>/dev/null | grep "Running" | wc -l)
AIRFLOW_FLOWER=$(kubectl get pods -n data-platform -l component=flower --no-headers 2>/dev/null | grep "Running" | wc -l)

if [ "$AIRFLOW_WEBSERVER" -eq 1 ]; then
    print_success "Airflow Webserver is healthy"
else
    print_error "Airflow Webserver issues detected"
fi

if [ "$AIRFLOW_SCHEDULER" -eq 1 ]; then
    print_success "Airflow Scheduler is healthy"
else
    print_error "Airflow Scheduler issues detected"
fi

if [ "$AIRFLOW_WORKERS" -eq 2 ]; then
    print_success "Airflow Workers are healthy (2/2)"
elif [ "$AIRFLOW_WORKERS" -gt 0 ]; then
    print_warning "Some Airflow Workers are running ($AIRFLOW_WORKERS/2)"
else
    print_error "No Airflow Workers running"
fi

if [ "$AIRFLOW_FLOWER" -eq 1 ]; then
    print_success "Flower monitoring is healthy"
else
    print_error "Flower monitoring issues detected"
fi

# MinIO
MINIO_STATUS=$(kubectl get pods -n data-platform -l app=minio --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$MINIO_STATUS" -eq 1 ]; then
    print_success "MinIO is healthy"
else
    print_error "MinIO issues detected"
fi

# Monitoring
PROMETHEUS_STATUS=$(kubectl get pods -n data-platform -l app=prometheus --no-headers 2>/dev/null | grep "Running" | wc -l)
GRAFANA_STATUS=$(kubectl get pods -n data-platform -l app=grafana --no-headers 2>/dev/null | grep "Running" | wc -l)

if [ "$PROMETHEUS_STATUS" -eq 1 ]; then
    print_success "Prometheus is healthy"
else
    print_error "Prometheus issues detected"
fi

if [ "$GRAFANA_STATUS" -eq 1 ]; then
    print_success "Grafana is healthy"
else
    print_error "Grafana issues detected"
fi

# Overall status
echo ""
print_header "Overall Platform Status"
if [ "$running_pods" -gt 8 ] && [ "$failed_pods" -eq 0 ]; then
    print_success "🎉 Data Platform is healthy and ready for production!"
    echo ""
    print_info "Next steps:"
    echo "  - Run: ./scripts/fix-airflow-secrets.sh (if not done)"
    echo "  - Run: ./scripts/expose-services.sh (for external access)"
    echo "  - Access services via port-forward: ./scripts/port-forward.sh"
else
    print_warning "⚠️  Data Platform has some issues that need attention"
    echo ""
    print_info "To fix common issues:"
    echo "  - Run: ./scripts/fix-airflow-secrets.sh"
    echo "  - Check pod logs: kubectl logs <pod-name> -n data-platform"
    echo "  - Check events: kubectl get events -n data-platform --sort-by='.lastTimestamp'"
fi
