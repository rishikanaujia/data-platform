#!/bin/bash
# Complete Production Setup Automation

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
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

print_header "Complete Production Kubernetes Data Platform Setup"
print_feature "Apache Airflow 2.8.1 • CeleryExecutor • External Access • Production Security"

echo ""
echo "This automation script will:"
echo "  1. 🚀 Deploy the entire production platform"
echo "  2. 🔐 Configure production-grade security"
echo "  3. 🌐 Enable external access via NodePort"
echo "  4. 📊 Verify all services and provide access URLs"
echo "  5. 📋 Generate comprehensive access documentation"
echo ""
echo "Estimated time: 10-15 minutes"
echo "Platform features: Airflow 2.8.1, CeleryExecutor, 2 Workers, Monitoring"
echo ""

read -p "🎯 Continue with complete production setup? (y/N): " -n 1 -r
echo
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setup cancelled by user"
    exit 0
fi

# Step 1: Deploy platform
print_header "Step 1: Deploying Production Platform (5-8 minutes)"
print_info "Deploying PostgreSQL, Redis, Monitoring, Airflow 2.8.1, and MinIO..."
./scripts/deploy.sh

if [ $? -ne 0 ]; then
    print_error "Platform deployment failed!"
    exit 1
fi

# Step 2: Fix Airflow secrets
print_header "Step 2: Configuring Production Security (1-2 minutes)"
print_info "Generating secure keys and restarting Airflow components..."
./scripts/fix-airflow-secrets.sh

if [ $? -ne 0 ]; then
    print_error "Security configuration failed!"
    exit 1
fi

# Step 3: Expose services
print_header "Step 3: Enabling External Access (1 minute)"
print_info "Converting services to NodePort and generating access URLs..."
./scripts/expose-services.sh

if [ $? -ne 0 ]; then
    print_error "External access configuration failed!"
    exit 1
fi

# Step 4: Final health check
print_header "Step 4: Final Production Verification"
print_info "Verifying all services are healthy and ready..."
./scripts/check-health.sh

# Final summary
print_header "🎉 PRODUCTION SETUP COMPLETE!"
echo ""
print_success "🎯 Your enterprise-grade Kubernetes Data Platform is ready!"
echo ""
print_feature "Platform highlights:"
echo "  ✅ Apache Airflow 2.8.1 with latest Python 3.11"
echo "  ✅ CeleryExecutor with 2 distributed workers (32 parallel tasks)"
echo "  ✅ Production security with encrypted secrets"
echo "  ✅ External access via NodePort services"
echo "  ✅ Complete monitoring stack (Prometheus + Grafana)"
echo "  ✅ S3-compatible object storage (MinIO)"
echo "  ✅ Flower worker monitoring interface"
echo "  ✅ High availability PostgreSQL database"
echo "  ✅ Redis message broker and cache"
echo ""
print_info "📋 Next steps:"
echo "  1. Check 'access-info.txt' for complete service URLs and credentials"
echo "  2. Access Airflow UI to create your first data pipeline"
echo "  3. Configure MinIO buckets for your data lake"
echo "  4. Set up Grafana dashboards for monitoring"
echo "  5. Scale workers as needed: kubectl scale deployment airflow-worker --replicas=4 -n data-platform"
echo ""
print_success "🌟 Happy data engineering with your production-ready platform!"
