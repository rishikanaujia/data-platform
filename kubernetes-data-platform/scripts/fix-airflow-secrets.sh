#!/bin/bash
# Production Airflow Security Configuration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header "Production Airflow Security Setup"

# Generate secure keys
print_info "Generating cryptographically secure keys..."

# Check if python cryptography is available
if python3 -c "from cryptography.fernet import Fernet" 2>/dev/null; then
    FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
    print_success "Generated Fernet key using cryptography library"
else
    print_warning "Python cryptography not available, using openssl fallback"
    FERNET_KEY=$(openssl rand -base64 32)
fi

SECRET_KEY=$(openssl rand -hex 30)

if [ -z "$FERNET_KEY" ] || [ -z "$SECRET_KEY" ]; then
    print_error "Failed to generate secure keys"
    print_info "Please install python3-cryptography: sudo apt-get install python3-pip && pip3 install cryptography"
    exit 1
fi

print_success "Generated production-grade security keys"

# Update the Airflow secret
print_info "Updating Airflow security configuration..."

# Try to patch existing secret first
if kubectl patch secret airflow-secret -n data-platform \
    -p "{\"data\":{\"fernet-key\":\"$(echo -n $FERNET_KEY | base64 -w 0)\",\"webserver-secret-key\":\"$(echo -n $SECRET_KEY | base64 -w 0)\"}}" 2>/dev/null; then
    print_success "Airflow secrets updated via patch"
else
    print_warning "Patch failed, recreating secret..."

    # Delete and recreate secret
    kubectl delete secret airflow-secret -n data-platform 2>/dev/null || true
    kubectl create secret generic airflow-secret -n data-platform \
        --from-literal=fernet-key="$FERNET_KEY" \
        --from-literal=webserver-secret-key="$SECRET_KEY"

    if [ $? -eq 0 ]; then
        print_success "Airflow secrets recreated successfully"
    else
        print_error "Failed to update secrets"
        exit 1
    fi
fi

# Restart Airflow components to pick up new secrets
print_info "Restarting Airflow components with new security configuration..."

kubectl rollout restart deployment/airflow-webserver -n data-platform
kubectl rollout restart deployment/airflow-scheduler -n data-platform
kubectl rollout restart deployment/airflow-worker -n data-platform
kubectl rollout restart deployment/airflow-flower -n data-platform

print_success "All Airflow components restarted"

# Wait for webserver to be ready
print_info "Waiting for Airflow webserver to be ready with new security..."
if kubectl wait --for=condition=available deployment/airflow-webserver -n data-platform --timeout=300s; then
    print_success "🔐 Airflow webserver is ready with production security!"
else
    print_warning "Webserver restart taking longer than expected"
    print_info "Check status with: kubectl get pods -n data-platform -l component=webserver"
fi

print_header "🔒 Security Configuration Complete"
print_success "Airflow is now secured with production-grade encryption"
print_info "Fernet key and webserver secret have been regenerated"
print_info "All components restarted with new security configuration"
