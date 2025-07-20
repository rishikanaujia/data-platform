#!/bin/bash
# Production External Access Configuration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_feature() {
    echo -e "${CYAN}🚀 $1${NC}"
}

print_header "Production External Access Setup"

# Convert services to NodePort
print_info "Converting services to NodePort for external access..."

kubectl patch svc airflow-webserver -n data-platform -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc minio-console -n data-platform -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc airflow-flower -n data-platform -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc grafana -n data-platform -p '{"spec":{"type":"NodePort"}}'

print_success "All services converted to NodePort"

# Get external IP
print_info "Detecting server IP addresses..."
EXTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
INTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

# Use external IP if available, otherwise internal IP
SERVER_IP=${EXTERNAL_IP:-$INTERNAL_IP}

if [ -z "$SERVER_IP" ]; then
    print_warning "Could not auto-detect server IP"
    SERVER_IP="<YOUR_SERVER_IP>"
else
    print_success "Server IP detected: $SERVER_IP"
fi

# Wait a moment for services to update
sleep 5

# Get service details
echo ""
print_info "Service Configuration:"
kubectl get svc -n data-platform -o wide

# Extract NodePort information
echo ""
print_info "Extracting NodePort assignments..."
AIRFLOW_PORT=$(kubectl get svc airflow-webserver -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
MINIO_PORT=$(kubectl get svc minio-console -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
FLOWER_PORT=$(kubectl get svc airflow-flower -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
GRAFANA_PORT=$(kubectl get svc grafana -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

# Display access information
echo ""
print_header "🌐 Production Platform Access URLs"
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│                     🎯 SERVICE ACCESS INFORMATION                    │"
echo "├─────────────────────────────────────────────────────────────────────┤"
echo "│                                                                     │"
echo "│  🚀 AIRFLOW ORCHESTRATION                                          │"
echo "│     URL: http://$SERVER_IP:$AIRFLOW_PORT                                      │"
echo "│     Username: admin | Password: admin123                           │"
echo "│     Purpose: Data pipeline orchestration & DAG management          │"
echo "│                                                                     │"
echo "│  💾 MinIO OBJECT STORAGE                                           │"
echo "│     URL: http://$SERVER_IP:$MINIO_PORT                                       │"
echo "│     Username: minioadmin | Password: minioadmin123                 │"
echo "│     Purpose: S3-compatible data lake and object storage            │"
echo "│                                                                     │"
echo "│  🌸 FLOWER WORKER MONITORING                                       │"
echo "│     URL: http://$SERVER_IP:$FLOWER_PORT                                      │"
echo "│     Purpose: Real-time Celery worker monitoring & task tracking    │"
echo "│                                                                     │"
echo "│  📊 GRAFANA DASHBOARDS                                             │"
echo "│     URL: http://$SERVER_IP:$GRAFANA_PORT                                     │"
echo "│     Username: admin | Password: admin123                           │"
echo "│     Purpose: System metrics, monitoring & alerting dashboards      │"
echo "│                                                                     │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo ""

# Create detailed access info file
print_info "Creating access information file..."
cat > access-info.txt << EOL
# Kubernetes Data Platform - Production Access Information
# Generated: $(date)
# Platform Version: 3.0 Production Ready

## 🌐 EXTERNAL ACCESS URLS:

### Primary Services
- Airflow Orchestration:    http://$SERVER_IP:$AIRFLOW_PORT
  Username: admin | Password: admin123
  Features: DAG management, task scheduling, workflow monitoring

- MinIO Object Storage:     http://$SERVER_IP:$MINIO_PORT
  Username: minioadmin | Password: minioadmin123
  Features: S3-compatible API, bucket management, data lake storage

- Flower Worker Monitoring: http://$SERVER_IP:$FLOWER_PORT
  Features: Real-time worker status, task distribution, performance metrics

- Grafana Dashboards:       http://$SERVER_IP:$GRAFANA_PORT
  Username: admin | Password: admin123
  Features: System monitoring, custom dashboards, alerting

## 📊 PLATFORM ARCHITECTURE:

### Core Components
- Apache Airflow 2.8.1 with CeleryExecutor
- PostgreSQL 15 with HA configuration
- Redis 7 message broker and cache
- MinIO S3-compatible object storage
- Prometheus metrics collection
- Grafana monitoring dashboards

### Scaling Configuration
- Airflow Workers: 2 replicas (16 tasks each)
- Auto-scaling ready for production workloads
- Load balancing across worker nodes

## 🔧 MANAGEMENT COMMANDS:

### Health Monitoring
kubectl get pods -n data-platform
kubectl get svc -n data-platform
kubectl top pods -n data-platform

### Scaling Operations
kubectl scale deployment airflow-worker --replicas=4 -n data-platform
kubectl scale deployment airflow-webserver --replicas=2 -n data-platform

### Log Analysis
kubectl logs -l app=airflow -n data-platform
kubectl logs -l app=postgres -n data-platform

## 📈 SERVICE DETAILS:
$(kubectl get svc -n data-platform -o wide)

## 🏥 CURRENT PLATFORM STATUS:
$(kubectl get pods -n data-platform -o wide)

## 💾 STORAGE STATUS:
$(kubectl get pvc -n data-platform)

---
Generated by Kubernetes Data Platform Production Setup v3.0
For support and documentation: Check README.md
EOL

print_success "Detailed access information saved to: access-info.txt"

# Final verification
echo ""
print_header "🔍 Final Verification"
print_info "Testing service accessibility..."

# Quick connectivity test (if curl is available)
if command -v curl &> /dev/null; then
    if [ "$SERVER_IP" != "<YOUR_SERVER_IP>" ]; then
        for port in $AIRFLOW_PORT $MINIO_PORT $FLOWER_PORT $GRAFANA_PORT; do
            if curl -s --connect-timeout 5 http://$SERVER_IP:$port >/dev/null; then
                print_success "Port $port is accessible"
            else
                print_warning "Port $port may not be ready yet (normal during startup)"
            fi
        done
    fi
fi

print_header "🎉 External Access Configuration Complete!"
print_feature "Your production data platform is now accessible from anywhere!"
print_info "Save the URLs above for your team and bookmark access-info.txt"
