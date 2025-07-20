#!/bin/bash
# Port Forward Script for Easy Access

echo "🌐 Starting port-forwards for Data Platform services..."
echo "======================================================="

# Function to start port-forward in background
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local namespace=${4:-data-platform}

    echo "Starting $service on localhost:$local_port"
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
start_port_forward "minio-console" 9001 9001
start_port_forward "prometheus" 9090 9090

echo ""
echo "✅ Port-forwards started!"
echo ""
echo "Access your services at:"
echo "  🔍 Grafana (admin/admin123):     http://localhost:3000"
echo "  ⚙️  Airflow (admin/admin123):     http://localhost:8080"
echo "  💾 MinIO (minioadmin/minioadmin123): http://localhost:9001"
echo "  📈 Prometheus:                   http://localhost:9090"
echo ""
echo "Press Ctrl+C to stop all port-forwards"

# Wait for Ctrl+C
trap 'echo "Stopping port-forwards..."; jobs -p | xargs -r kill; exit 0' INT
wait
