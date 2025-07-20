#!/bin/bash
# Production Deployment Script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}

    print_status "Waiting for $deployment to be ready..."
    if kubectl wait --for=condition=available deployment/$deployment -n $namespace --timeout=${timeout}s 2>/dev/null; then
        print_success "$deployment is ready!"
        return 0
    else
        print_error "$deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

wait_for_statefulset() {
    local statefulset=$1
    local namespace=$2
    local timeout=${3:-300}

    print_status "Waiting for $statefulset to be ready..."
    if kubectl wait --for=condition=ready pod -l app=$statefulset -n $namespace --timeout=${timeout}s 2>/dev/null; then
        print_success "$statefulset is ready!"
        return 0
    else
        print_error "$statefulset failed to become ready within ${timeout}s"
        return 1
    fi
}

wait_for_job() {
    local job=$1
    local namespace=$2
    local timeout=${3:-300}

    print_status "Waiting for job $job to complete..."
    if kubectl wait --for=condition=complete job/$job -n $namespace --timeout=${timeout}s 2>/dev/null; then
        print_success "Job $job completed!"
        return 0
    else
        print_error "Job $job did not complete within ${timeout}s"
        return 1
    fi
}

print_header "Production Kubernetes Data Platform Deployment"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not available. Please install kubectl first."
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_success "Connected to Kubernetes cluster"

# Deploy in order
print_header "Step 1: Deploying PostgreSQL Database"
kubectl apply -f deployment/01-postgres-ha.yaml
wait_for_statefulset "postgres" "data-platform" 600
wait_for_job "postgres-init" "data-platform" 300

print_header "Step 2: Deploying Redis Message Broker"
kubectl apply -f deployment/02-redis.yaml
wait_for_deployment "redis-master" "data-platform" 300

print_header "Step 3: Deploying Monitoring Stack"
kubectl apply -f deployment/03-prometheus.yaml
kubectl apply -f deployment/04-grafana.yaml
wait_for_deployment "prometheus" "data-platform" 300
wait_for_deployment "grafana" "data-platform" 300

print_header "Step 4: Deploying Apache Airflow 2.8.1"
kubectl apply -f deployment/05-airflow.yaml
wait_for_job "airflow-db-init-fixed" "data-platform" 600
wait_for_deployment "airflow-webserver" "data-platform" 600
wait_for_deployment "airflow-scheduler" "data-platform" 300
wait_for_deployment "airflow-worker" "data-platform" 300
wait_for_deployment "airflow-flower" "data-platform" 300

print_header "Step 5: Deploying MinIO Object Storage"
kubectl apply -f deployment/06-minio.yaml
wait_for_deployment "minio" "data-platform" 300

print_header "🎉 Production Deployment Completed!"
echo ""
print_success "All services deployed successfully!"
print_status "Next steps:"
echo "  1. Run './scripts/check-health.sh' to verify all services"
echo "  2. Run './scripts/fix-airflow-secrets.sh' to secure Airflow"
echo "  3. Run './scripts/expose-services.sh' to enable external access"
echo ""
print_status "Or run './scripts/complete-setup.sh' for automated post-deployment setup"
