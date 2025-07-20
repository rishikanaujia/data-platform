# Kubernetes Data Platform - Production Ready

A complete, production-ready data platform deployed on Kubernetes with all fixes applied.

## 🏗️ Architecture

### Core Services
- **PostgreSQL**: Primary database with HA configuration
- **Redis**: High-performance caching and message broker
- **Apache Airflow 2.8.1**: Latest workflow orchestration with CeleryExecutor
- **MinIO**: S3-compatible object storage
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Dashboards and visualization

### 🚀 Advanced Features
- **CeleryExecutor**: Distributed task processing across multiple workers
- **Flower Monitoring**: Real-time Celery worker monitoring
- **Production Security**: Secure Fernet keys and webserver secrets
- **External Access**: NodePort services for team collaboration
- **Auto-scaling**: Ready for horizontal pod scaling

## 🎯 Quick Start

### Prerequisites
- Kubernetes cluster (MicroK8s, Minikube, or any K8s cluster)
- kubectl access with cluster-admin permissions
- 8GB+ RAM, 4+ CPU cores, 50GB+ storage

### Option 1: One-Command Deployment (Recommended)
```bash
# Setup environment
./scripts/setup-environment.sh

# Complete automated deployment with all fixes
./scripts/complete-setup.sh
```

### Option 2: Step-by-Step Deployment
```bash
# 1. Setup environment
./scripts/setup-environment.sh

# 2. Deploy platform
./scripts/deploy.sh

# 3. Fix Airflow security (required)
./scripts/fix-airflow-secrets.sh

# 4. Expose services for external access
./scripts/expose-services.sh

# 5. Verify deployment
./scripts/check-health.sh
```

## 🔐 Access Information

After deployment, your services will be externally accessible via NodePort:

| Service | External Access | Credentials | Purpose |
|---------|----------------|-------------|---------|
| **🚀 Airflow** | http://YOUR_IP:PORT | admin / admin123 | Workflow orchestration & DAG management |
| **💾 MinIO** | http://YOUR_IP:PORT | minioadmin / minioadmin123 | S3-compatible object storage |
| **🌸 Flower** | http://YOUR_IP:PORT | - | Celery worker monitoring |
| **📊 Grafana** | http://YOUR_IP:PORT | admin / admin123 | Metrics dashboards |

*Exact URLs will be displayed after running the setup scripts*

## 🛠️ Management Commands

### Health Monitoring
```bash
# Check overall platform health
./scripts/check-health.sh

# View specific service logs
kubectl logs <pod-name> -n data-platform

# Monitor resource usage
kubectl top pods -n data-platform
```

### Scaling Operations
```bash
# Scale Airflow workers
kubectl scale deployment airflow-worker --replicas=4 -n data-platform

# Scale other services
kubectl scale deployment <service-name> --replicas=2 -n data-platform
```

### Access Services Locally
```bash
# Start port-forwarding for local access
./scripts/port-forward.sh

# Then access via localhost:
# - Airflow:    http://localhost:8080
# - MinIO:      http://localhost:9001
# - Flower:     http://localhost:5555
# - Grafana:    http://localhost:3000
```

## 📊 Platform Capabilities

### Data Pipeline Features
- **ETL/ELT Workflows**: Build complex data transformation pipelines
- **Distributed Processing**: Scale across multiple Celery workers
- **Scheduled Execution**: Cron-based and event-driven scheduling
- **Retry Logic**: Automatic failure handling and retry mechanisms
- **Data Quality**: Built-in data validation and testing

### Storage & Connectivity
- **S3-Compatible Storage**: MinIO for data lakes and object storage
- **Database Connectivity**: PostgreSQL for metadata and data storage
- **External Integrations**: Connect to APIs, databases, cloud services
- **File Processing**: Handle CSV, JSON, Parquet, and other formats

### Monitoring & Observability
- **Real-time Monitoring**: Grafana dashboards for system metrics
- **Worker Health**: Flower interface for Celery worker monitoring
- **Log Aggregation**: Centralized logging via Kubernetes
- **Performance Metrics**: Prometheus metrics collection

## 🔧 Troubleshooting

### Common Issues & Solutions

**Airflow Webserver Not Starting:**
```bash
# Fix security keys (most common issue)
./scripts/fix-airflow-secrets.sh
```

**Services Not Accessible Externally:**
```bash
# Expose services via NodePort
./scripts/expose-services.sh
```

**Pod Stuck in Pending:**
```bash
# Check storage and resources
kubectl describe pod <pod-name> -n data-platform
kubectl get pv,pvc -n data-platform
```

**Database Connection Issues:**
```bash
# Check PostgreSQL status
kubectl logs postgres-primary-0 -n data-platform
kubectl exec -it postgres-primary-0 -n data-platform -- psql -U postgres
```

### Debug Commands
```bash
# Get all resources
kubectl get all -n data-platform

# Check events
kubectl get events -n data-platform --sort-by='.lastTimestamp'

# Pod details
kubectl describe pod <pod-name> -n data-platform

# Service details
kubectl describe svc <service-name> -n data-platform
```

## 🚀 Next Steps

### 1. Create Your First DAG
1. Access Airflow UI via the external URL
2. Navigate to **Admin > Connections** to set up data sources
3. Create a simple Python DAG in the DAGs folder
4. Enable and trigger your workflow

### 2. Set Up Data Storage
1. Access MinIO console via the external URL
2. Create buckets for your data lake
3. Upload sample datasets
4. Configure Airflow connections to MinIO

### 3. Build Monitoring Dashboards
1. Access Grafana via the external URL
2. Import pre-built dashboards for Kubernetes
3. Create custom dashboards for your data pipelines
4. Set up alerting for critical metrics

### 4. Scale Your Platform
```bash
# Add more Airflow workers
kubectl scale deployment airflow-worker --replicas=5 -n data-platform

# Increase database resources
kubectl patch statefulset postgres-primary -n data-platform -p '{"spec":{"template":{"spec":{"containers":[{"name":"postgres","resources":{"requests":{"memory":"2Gi","cpu":"1000m"}}}]}}}}'
```

## 📚 Advanced Configuration

### Custom DAGs
Place your DAG files in the Airflow pods or use a shared volume:
```bash
# Copy DAG to running pod
kubectl cp my_dag.py airflow-webserver-xxx:/opt/airflow/dags/ -n data-platform
```

### Environment Variables
Update Airflow configuration via ConfigMap:
```bash
kubectl edit configmap airflow-config -n data-platform
kubectl rollout restart deployment/airflow-webserver -n data-platform
```

### SSL/TLS Configuration
For production, consider enabling SSL:
```bash
# Add TLS certificates
kubectl create secret tls airflow-tls --cert=cert.pem --key=key.pem -n data-platform
```

## 🎉 Success!

Your Kubernetes Data Platform is now ready for production use with:

✅ **Apache Airflow 2.8.1** - Latest version with all features
✅ **CeleryExecutor** - Distributed task processing
✅ **Production Security** - Secure keys and configurations
✅ **External Access** - Team collaboration ready
✅ **Complete Monitoring** - Full observability stack
✅ **Scalable Architecture** - Ready for enterprise workloads

**Start building amazing data pipelines!** 🚀📊💫
