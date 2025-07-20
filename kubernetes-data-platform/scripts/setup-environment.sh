#!/bin/bash
# Environment Setup Script

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

echo "🔧 Setting up Kubernetes environment for Data Platform..."
echo "======================================================="

# Detect environment
if command -v microk8s &> /dev/null; then
    echo "📦 Configuring MicroK8s..."

    # Check MicroK8s status
    if ! microk8s status --wait-ready --timeout 60; then
        print_error "MicroK8s is not ready"
        exit 1
    fi

    # Enable required add-ons
    print_info "Enabling required MicroK8s add-ons..."
    microk8s enable dns storage

    # Enable ingress if available
    if microk8s enable ingress 2>/dev/null; then
        print_success "Ingress enabled"
    else
        print_warning "Ingress not available or already enabled"
    fi

    # Set up kubectl alias
    if ! command -v kubectl &> /dev/null; then
        print_info "Setting up kubectl alias..."
        sudo snap alias microk8s.kubectl kubectl || echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
    fi

    print_success "MicroK8s configured"

elif command -v minikube &> /dev/null; then
    echo "📦 Configuring Minikube..."

    # Check if Minikube is running
    if ! minikube status | grep -q "Running"; then
        print_error "Minikube is not running. Start it with: minikube start"
        exit 1
    fi

    # Enable required add-ons
    print_info "Enabling required Minikube add-ons..."
    minikube addons enable ingress
    minikube addons enable storage-provisioner

    print_success "Minikube configured"

else
    echo "📦 Generic Kubernetes cluster detected"
    print_info "Please ensure you have storage classes available"
fi

# Check cluster connectivity
echo ""
print_info "Checking cluster connectivity..."
if kubectl cluster-info &>/dev/null; then
    print_success "Kubernetes cluster is accessible"
    echo ""
    kubectl get nodes
    echo ""
    kubectl get sc
else
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_success "Environment setup complete!"
echo ""
print_info "Next steps:"
echo "  1. Run: ./scripts/deploy.sh"
echo "  2. Run: ./scripts/check-health.sh"
echo "  3. Run: ./scripts/port-forward.sh"
