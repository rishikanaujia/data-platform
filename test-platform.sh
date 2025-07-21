#!/bin/bash
# Comprehensive Kubernetes Data Platform Test Suite
# Tests all components of your enterprise-grade data platform
# ENHANCED: Dynamic port detection instead of hardcoded values

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Dynamic port variables (will be auto-detected)
AIRFLOW_PORT=""
MINIO_PORT=""
FLOWER_PORT=""
GRAFANA_PORT=""

# Print functions
print_header() {
    echo ""
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

print_test() {
    echo -e "${BLUE}🧪 Testing: $1${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_fail() {
    echo -e "${RED}❌ $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Function to detect server IP dynamically
detect_server_ip() {
    print_test "Auto-detecting server IP address"

    # Try multiple methods to get the server IP
    EXTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
    INTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

    # Use external IP if available, otherwise internal IP
    SERVER_IP=${EXTERNAL_IP:-$INTERNAL_IP}

    if [ -n "$SERVER_IP" ]; then
        print_success "Server IP detected: $SERVER_IP"
        return 0
    else
        print_fail "Could not auto-detect server IP"
        print_warning "Please set SERVER_IP manually in the script"
        return 1
    fi
}

# Function to detect NodePort assignments dynamically
detect_service_ports() {
    print_test "Auto-detecting service NodePort assignments"

    # Get Airflow NodePort
    AIRFLOW_PORT=$(kubectl get svc airflow-webserver -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    if [ -n "$AIRFLOW_PORT" ]; then
        print_success "Airflow NodePort detected: $AIRFLOW_PORT"
    else
        print_fail "Could not detect Airflow NodePort"
        return 1
    fi

    # Get MinIO Console NodePort
    MINIO_PORT=$(kubectl get svc minio-console -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    if [ -n "$MINIO_PORT" ]; then
        print_success "MinIO NodePort detected: $MINIO_PORT"
    else
        print_fail "Could not detect MinIO NodePort"
        return 1
    fi

    # Get Flower NodePort
    FLOWER_PORT=$(kubectl get svc airflow-flower -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    if [ -n "$FLOWER_PORT" ]; then
        print_success "Flower NodePort detected: $FLOWER_PORT"
    else
        print_fail "Could not detect Flower NodePort"
        return 1
    fi

    # Get Grafana NodePort
    GRAFANA_PORT=$(kubectl get svc grafana -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    if [ -n "$GRAFANA_PORT" ]; then
        print_success "Grafana NodePort detected: $GRAFANA_PORT"
    else
        print_fail "Could not detect Grafana NodePort"
        return 1
    fi

    print_info "Port Detection Summary:"
    print_info "  Airflow:  $AIRFLOW_PORT"
    print_info "  MinIO:    $MINIO_PORT"
    print_info "  Flower:   $FLOWER_PORT"
    print_info "  Grafana:  $GRAFANA_PORT"

    return 0
}

# Load credentials
if [ -f "credentials.env" ]; then
    source credentials.env
    print_success "Loaded credentials from credentials.env"
else
    print_fail "credentials.env not found! Run from kubernetes-data-platform directory"
    exit 1
fi

# Platform configuration
NAMESPACE="data-platform"

print_header "🧪 COMPREHENSIVE PLATFORM TEST SUITE (DYNAMIC VERSION)"
print_info "Testing enterprise-grade Kubernetes Data Platform"
print_info "Namespace: $NAMESPACE"

# Auto-detect server IP and service ports
print_header "Pre-Test: Dynamic Configuration Detection"

if ! detect_server_ip; then
    print_fail "Cannot continue without server IP"
    exit 1
fi

if ! detect_service_ports; then
    print_fail "Cannot continue without service port information"
    exit 1
fi

print_success "Dynamic configuration complete!"
print_info "Server: $SERVER_IP"
print_info "Services will be tested on their auto-detected ports"

# Test 1: Pod Health Status
print_header "Test 1: Pod Health Status"

print_test "Checking if namespace exists"
if kubectl get namespace $NAMESPACE &>/dev/null; then
    print_success "Namespace '$NAMESPACE' exists"
else
    print_fail "Namespace '$NAMESPACE' not found"
    exit 1
fi

print_test "Checking pod status"
echo ""
kubectl get pods -n $NAMESPACE
echo ""

# Count pod states
TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep "Running" | wc -l)
COMPLETED_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep "Completed" | wc -l)
FAILED_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -E "Error|CrashLoop|Failed|Pending" | wc -l)

print_info "Pod Summary: Total=$TOTAL_PODS, Running=$RUNNING_PODS, Completed=$COMPLETED_PODS, Failed=$FAILED_PODS"

if [ "$FAILED_PODS" -eq 0 ]; then
    print_success "No failed pods found"
else
    print_fail "$FAILED_PODS failed pods detected"
fi

# Test 2: Service Connectivity
print_header "Test 2: Service Connectivity (Dynamic Ports)"

print_test "Getting service information"
kubectl get svc -n $NAMESPACE
echo ""

print_test "Testing Airflow Webserver (port $AIRFLOW_PORT)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP:$AIRFLOW_PORT/health 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    print_success "Airflow Webserver responding (HTTP $HTTP_STATUS)"
else
    print_fail "Airflow Webserver not responding (HTTP $HTTP_STATUS)"
fi

print_test "Testing MinIO Console (port $MINIO_PORT)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP:$MINIO_PORT 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "403" ]; then
    print_success "MinIO Console responding (HTTP $HTTP_STATUS)"
else
    print_fail "MinIO Console not responding (HTTP $HTTP_STATUS)"
fi

print_test "Testing Flower Monitoring (port $FLOWER_PORT)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP:$FLOWER_PORT 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    print_success "Flower Monitoring responding (HTTP $HTTP_STATUS)"
else
    print_fail "Flower Monitoring not responding (HTTP $HTTP_STATUS)"
fi

print_test "Testing Grafana (port $GRAFANA_PORT)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP:$GRAFANA_PORT/api/health 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    print_success "Grafana responding (HTTP $HTTP_STATUS)"
else
    print_fail "Grafana not responding (HTTP $HTTP_STATUS)"
fi

# Test 3: Database Connectivity
print_header "Test 3: Database Connectivity"

print_test "Testing PostgreSQL connection"
if kubectl exec postgres-primary-0 -n $NAMESPACE -- psql -U postgres -c "SELECT 1;" &>/dev/null; then
    print_success "PostgreSQL connection successful"

    # Get PostgreSQL version
    PG_VERSION=$(kubectl exec postgres-primary-0 -n $NAMESPACE -- psql -U postgres -t -c "SELECT version();" 2>/dev/null | head -1 | xargs)
    print_info "PostgreSQL Version: $PG_VERSION"
else
    print_fail "PostgreSQL connection failed"
fi

print_test "Testing Airflow database exists"
if kubectl exec postgres-primary-0 -n $NAMESPACE -- psql -U postgres -c "\l" 2>/dev/null | grep -q airflow; then
    print_success "Airflow database found"
else
    print_fail "Airflow database not found"
fi

print_test "Testing Airflow tables exist"
TABLE_COUNT=$(kubectl exec postgres-primary-0 -n $NAMESPACE -- psql -U postgres -d airflow -c "\dt" 2>/dev/null | grep -c "table" || echo "0")
if [ "$TABLE_COUNT" -gt 10 ]; then
    print_success "Airflow tables exist ($TABLE_COUNT tables found)"
else
    print_fail "Airflow tables missing or incomplete ($TABLE_COUNT tables found)"
fi

# Test 4: Redis Connectivity
print_header "Test 4: Redis Connectivity"

REDIS_POD=$(kubectl get pod -n $NAMESPACE -l app=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$REDIS_POD" ]; then
    print_test "Testing Redis authentication"
    if kubectl exec $REDIS_POD -n $NAMESPACE -- redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG; then
        print_success "Redis authentication working"
    else
        print_fail "Redis authentication failed"
    fi

    print_test "Testing Redis memory info"
    REDIS_MEMORY=$(kubectl exec $REDIS_POD -n $NAMESPACE -- redis-cli -a "$REDIS_PASSWORD" info memory 2>/dev/null | grep used_memory_human | cut -d: -f2 | tr -d '\r')
    if [ -n "$REDIS_MEMORY" ]; then
        print_success "Redis memory usage: $REDIS_MEMORY"
    else
        print_fail "Could not get Redis memory info"
    fi
else
    print_fail "Redis pod not found"
fi

# Test 5: Airflow API Tests
print_header "Test 5: Airflow API Tests (Dynamic Port)"

print_test "Testing Airflow health endpoint"
HEALTH_RESPONSE=$(curl -s http://$SERVER_IP:$AIRFLOW_PORT/health 2>/dev/null || echo "failed")
if echo "$HEALTH_RESPONSE" | grep -q "healthy\|ok"; then
    print_success "Airflow health endpoint responding"
    print_info "Health Status: $HEALTH_RESPONSE"
else
    print_fail "Airflow health endpoint not responding properly"
fi

print_test "Testing Airflow version"
WEBSERVER_POD=$(kubectl get pod -n $NAMESPACE -l component=webserver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$WEBSERVER_POD" ]; then
    AIRFLOW_VERSION=$(kubectl exec $WEBSERVER_POD -n $NAMESPACE -- airflow version 2>/dev/null | head -1)
    if [ -n "$AIRFLOW_VERSION" ]; then
        print_success "Airflow Version: $AIRFLOW_VERSION"
    else
        print_fail "Could not get Airflow version"
    fi
else
    print_fail "Airflow webserver pod not found"
fi

print_test "Testing Airflow API authentication"
API_RESPONSE=$(curl -s -u admin:$AIRFLOW_ADMIN_PASSWORD http://$SERVER_IP:$AIRFLOW_PORT/api/v1/config 2>/dev/null | head -100)
if echo "$API_RESPONSE" | grep -q "sections\|config"; then
    print_success "Airflow API authentication working"
else
    print_fail "Airflow API authentication failed"
fi

# Test 6: Worker and Queue Tests
print_header "Test 6: Worker and Queue Tests (Dynamic Port)"

print_test "Checking Airflow worker count"
WORKER_COUNT=$(kubectl get pods -n $NAMESPACE -l component=worker --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$WORKER_COUNT" -ge 2 ]; then
    print_success "Airflow workers running: $WORKER_COUNT/2"
else
    print_warning "Only $WORKER_COUNT/2 workers running"
fi

print_test "Testing Flower worker API"
FLOWER_RESPONSE=$(curl -s http://$SERVER_IP:$FLOWER_PORT/api/workers 2>/dev/null)
if echo "$FLOWER_RESPONSE" | grep -q "celery@"; then
    ACTIVE_WORKERS=$(echo "$FLOWER_RESPONSE" | grep -o "celery@" | wc -l)
    print_success "Flower API working - $ACTIVE_WORKERS active workers"
else
    print_fail "Flower API not responding properly"
fi

print_test "Checking worker logs for errors"
WORKER_POD=$(kubectl get pod -n $NAMESPACE -l component=worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$WORKER_POD" ]; then
    ERROR_COUNT=$(kubectl logs $WORKER_POD -n $NAMESPACE --tail=50 2>/dev/null | grep -i error | wc -l)
    if [ "$ERROR_COUNT" -eq 0 ]; then
        print_success "No errors in worker logs"
    else
        print_warning "$ERROR_COUNT errors found in worker logs"
    fi
else
    print_fail "Worker pod not found"
fi

# Test 7: Storage Tests
print_header "Test 7: Storage Tests"

print_test "Testing persistent volumes"
kubectl get pvc -n $NAMESPACE
echo ""

PVC_COUNT=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
BOUND_PVC=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | grep Bound | wc -l)

if [ "$PVC_COUNT" -eq "$BOUND_PVC" ] && [ "$PVC_COUNT" -gt 0 ]; then
    print_success "All persistent volumes bound ($BOUND_PVC/$PVC_COUNT)"
else
    print_fail "Some persistent volumes not bound ($BOUND_PVC/$PVC_COUNT)"
fi

print_test "Testing MinIO storage"
MINIO_POD=$(kubectl get pod -n $NAMESPACE -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$MINIO_POD" ]; then
    if kubectl exec $MINIO_POD -n $NAMESPACE -- ls -la /data &>/dev/null; then
        print_success "MinIO storage accessible"
    else
        print_fail "MinIO storage not accessible"
    fi
else
    print_fail "MinIO pod not found"
fi

# Test 8: Monitoring Stack Tests
print_header "Test 8: Monitoring Stack Tests (Dynamic Port)"

print_test "Testing Prometheus"
PROMETHEUS_POD=$(kubectl get pod -n $NAMESPACE -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$PROMETHEUS_POD" ]; then
    if kubectl exec $PROMETHEUS_POD -n $NAMESPACE -- wget -q --spider http://localhost:9090/-/ready 2>/dev/null; then
        print_success "Prometheus is ready"
    else
        print_fail "Prometheus not ready"
    fi
else
    print_fail "Prometheus pod not found"
fi

print_test "Testing Grafana API"
GRAFANA_API_RESPONSE=$(curl -s http://admin:$GRAFANA_ADMIN_PASSWORD@$SERVER_IP:$GRAFANA_PORT/api/health 2>/dev/null)
if echo "$GRAFANA_API_RESPONSE" | grep -q "ok\|database"; then
    print_success "Grafana API responding"
else
    print_fail "Grafana API not responding properly"
fi

# Test 9: Resource Usage Test
print_header "Test 9: Resource Usage Test"

print_test "Checking resource usage"
if command -v kubectl &>/dev/null; then
    echo ""
    print_info "Pod resource usage:"
    kubectl top pods -n $NAMESPACE 2>/dev/null || print_warning "Metrics server not available for pod resources"

    echo ""
    print_info "Node resource usage:"
    kubectl top nodes 2>/dev/null || print_warning "Metrics server not available for node resources"
    print_success "Resource usage check completed"
else
    print_fail "kubectl not available"
fi

# Test 10: End-to-End Access Test
print_header "Test 10: End-to-End Access Test (Dynamic Ports)"

print_test "Verifying all access URLs"
echo ""
print_info "🌐 Your Platform Access URLs (Auto-Detected):"
echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  🚀 AIRFLOW: http://$SERVER_IP:$AIRFLOW_PORT                                │${NC}"
echo -e "${CYAN}│     Login: admin / $AIRFLOW_ADMIN_PASSWORD                     │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  💾 MinIO: http://$SERVER_IP:$MINIO_PORT                               │${NC}"
echo -e "${CYAN}│     Login: minioadmin / ${MINIO_ROOT_PASSWORD:0:16}...              │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  📊 GRAFANA: http://$SERVER_IP:$GRAFANA_PORT                             │${NC}"
echo -e "${CYAN}│     Login: admin / $GRAFANA_ADMIN_PASSWORD                     │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  🌸 FLOWER: http://$SERVER_IP:$FLOWER_PORT                              │${NC}"
echo -e "${CYAN}│     No authentication required                                  │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
echo ""

print_test "Testing login page availability"
LOGIN_TESTS=0
LOGIN_SUCCESS=0

# Test Airflow login page
if curl -s http://$SERVER_IP:$AIRFLOW_PORT/login 2>/dev/null | grep -q "Sign In\|login\|password"; then
    LOGIN_SUCCESS=$((LOGIN_SUCCESS + 1))
    print_success "Airflow login page loads"
else
    print_fail "Airflow login page not accessible"
fi
LOGIN_TESTS=$((LOGIN_TESTS + 1))

# Test Grafana login page
if curl -s http://$SERVER_IP:$GRAFANA_PORT/login 2>/dev/null | grep -q "Grafana\|login\|password"; then
    LOGIN_SUCCESS=$((LOGIN_SUCCESS + 1))
    print_success "Grafana login page loads"
else
    print_fail "Grafana login page not accessible"
fi
LOGIN_TESTS=$((LOGIN_TESTS + 1))

if [ "$LOGIN_SUCCESS" -eq "$LOGIN_TESTS" ]; then
    print_success "All login pages accessible"
else
    print_fail "Some login pages not accessible ($LOGIN_SUCCESS/$LOGIN_TESTS)"
fi

# Final Results
print_header "🎯 TEST RESULTS SUMMARY"

echo ""
print_info "Total Tests Run: $TOTAL_TESTS"
print_success "Tests Passed: $PASSED_TESTS"
if [ "$FAILED_TESTS" -gt 0 ]; then
    print_fail "Tests Failed: $FAILED_TESTS"
else
    print_success "Tests Failed: $FAILED_TESTS"
fi

SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
print_info "Success Rate: $SUCCESS_RATE%"

echo ""
if [ "$FAILED_TESTS" -eq 0 ]; then
    print_success "🎉 ALL TESTS PASSED! Your platform is production-ready!"
    echo -e "${GREEN}🚀 Ready to build amazing data pipelines! 🚀${NC}"
elif [ "$SUCCESS_RATE" -ge 80 ]; then
    print_success "🎊 Platform is mostly healthy with minor issues"
    echo -e "${YELLOW}⚠️  Check failed tests above for optimization${NC}"
else
    print_fail "❌ Platform has significant issues that need attention"
    echo -e "${RED}🔧 Review failed tests and fix before production use${NC}"
    exit 1
fi

# Save detected configuration for future reference
print_test "Saving dynamic configuration"
cat > detected-config.env << EOF
# Auto-detected Platform Configuration
# Generated: $(date)

# Server Configuration
SERVER_IP=$SERVER_IP

# NodePort Assignments
AIRFLOW_PORT=$AIRFLOW_PORT
MINIO_PORT=$MINIO_PORT
FLOWER_PORT=$FLOWER_PORT
GRAFANA_PORT=$GRAFANA_PORT

# Access URLs
AIRFLOW_URL=http://$SERVER_IP:$AIRFLOW_PORT
MINIO_URL=http://$SERVER_IP:$MINIO_PORT
FLOWER_URL=http://$SERVER_IP:$FLOWER_PORT
GRAFANA_URL=http://$SERVER_IP:$GRAFANA_PORT
EOF

print_success "Configuration saved to detected-config.env"

print_header "🌟 Happy Data Engineering with your Enterprise Platform! 🌟"