#!/bin/bash
# Port Forward Script for Local Access

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header "Starting Local Access Port Forwards"

# Function to start port-forward in background
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local namespace=${4:-data-platform}

    print_info "Starting $service on localhost:$local_port"
    kubectl port-forward svc/$service $local_port:$remote_port -n $namespace &
    sleep 2
}

# Kill any existing port-forwards
echo "Stopping any existing port-forwards..."
pkill -f "kubectl port-forward" || true
sleep 2

# Start all port-forwards
start_port_forward "grafana" 3000 3000
start_port_forward "airflow-webserver" 8080 8080
start_port_forward "airflow-flower" 5555 5555
start_port_forward "minio-console" 9001 9001
start_port_forward "prometheus" 9090 9090

echo ""
print_success "All port-forwards started successfully!"
echo ""
print_header "🌐 Access Your Services"
echo ""
echo "  🔍 Grafana (Dashboards):         http://localhost:3000"
echo "      Username: admin | Password: admin123"
echo ""
echo "  ⚙️  Airflow (Orchestration):      http://localhost:8080"
echo "      Username: admin | Password: admin123"
echo ""
echo "  🌸 Flower (Worker Monitoring):   http://localhost:5555"
echo "      Real-time Celery worker monitoring"
echo ""
echo "  💾 MinIO (Object Storage):       http://localhost:9001"
echo "      Username: minioadmin | Password: minioadmin123"
echo ""
echo "  📈 Prometheus (Metrics):         http://localhost:9090"
echo "      Raw metrics and monitoring data"
echo ""
print_info "Press Ctrl+C to stop all port-forwards"

# Wait for Ctrl+C
trap 'echo ""; echo "Stopping all port-forwards..."; jobs -p | xargs -r kill; exit 0' INT
wait
