#!/bin/bash
# Health Check Script

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo "🏥 Data Platform Health Check"
echo "============================"

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
print_info "Pod Status:"
kubectl get pods -n data-platform

# Count pod states
total_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | wc -l)
running_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Running" | wc -l)
pending_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Pending" | wc -l)
failed_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep -E "Error|CrashLoopBackOff|ImagePullBackOff" | wc -l)

echo ""
print_info "Pod Summary:"
echo "  Total: $total_pods"
echo "  Running: $running_pods"
if [ "$pending_pods" -gt 0 ]; then
    print_warning "Pending: $pending_pods"
fi
if [ "$failed_pods" -gt 0 ]; then
    print_error "Failed: $failed_pods"
fi

# Check services
echo ""
print_info "Services:"
kubectl get svc -n data-platform

# Overall status
echo ""
if [ "$running_pods" -gt 0 ] && [ "$failed_pods" -eq 0 ]; then
    print_success "Data Platform appears to be healthy!"
    echo ""
    print_info "To access services, run: ./scripts/port-forward.sh"
else
    print_warning "Data Platform has some issues that need attention"
fi
