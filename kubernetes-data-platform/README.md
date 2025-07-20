# Kubernetes Data Platform - Production Ready v3.0

A complete, enterprise-grade data platform deployed on Kubernetes with advanced automation and production security.

## 🏗️ Production Architecture

### 🚀 Core Services
- **Apache Airflow 2.8.1**: Latest workflow orchestration with CeleryExecutor and Python 3.11
- **PostgreSQL 15**: High-availability database with automated initialization
- **Redis 7**: High-performance message broker and caching layer
- **MinIO**: Production S3-compatible object storage
- **Prometheus**: Advanced metrics collection and monitoring
- **Grafana**: Professional dashboards and visualization
- **Flower**: Real-time Celery worker monitoring

### ⚡ Advanced Features
- **CeleryExecutor**: Distributed task processing across multiple workers
- **Production Security**: Auto-generated Fernet keys and secure secrets
- **External Access**: NodePort services for team collaboration
- **Auto-scaling**: Ready for horizontal pod scaling
- **Health Monitoring**: Comprehensive health checks and monitoring
- **Resource Management**: Optimized resource allocation and limits

## 🎯 Quick Start

### Prerequisites
- Kubernetes cluster (MicroK8s, Minikube, or any K8s cluster)
- kubectl access with cluster-admin permissions
- 8GB+ RAM, 4+ CPU cores, 100GB+ storage recommended
- Internet access for image downloads

### 🚀 Option 1: One-Command Deployment (Recommended)
```bash
# Setup environment
./scripts/setup-environment.sh

# Complete automated production deployment
./scripts/complete-setup.sh
```

### 🔧 Option 2: Step-by-Step Deployment
```bash
# 1. Setup environment
./scripts/setup-environment.sh

# 2. Deploy platform
./scripts/deploy.sh

# 3. Configure production security
./scripts/fix-airflow-secrets.sh

# 4. Enable external access
./scripts/expose-services.sh

# 5. Verify deployment
./scripts/check-health.sh
```

## 🔐 Access Information

After deployment, your services will be externally accessible:

| Service | External Access | Credentials | Purpose |
|---------|----------------|-------------|---------|
| **🚀 Airflow** | http://YOUR_IP:PORT | admin / admin123 | Workflow orchestration & DAG management |
| **💾 MinIO** | http://YOUR_IP:PORT | minioadmin / minioadmin123 | S3-compatible object storage |
| **🌸 Flower** | http://YOUR_IP:PORT | - | Real-time Celery worker monitoring |
| **📊 Grafana** | http://YOUR_IP:PORT | admin / admin123 | System monitoring & dashboards |

*Exact URLs will be provided after running the setup scripts and saved in `access-info.txt`*

## 🛠️ Production Management

### Health Monitoring
```bash
# Check overall platform health
./scripts/check-health.sh

# View specific service logs
kubectl logs <pod-name> -n data-platform

# Monitor resource usage
kubectl top pods -n data-platform

# Check service status
kubectl get svc -n data-platform
```

### Scaling Operations
```bash
# Scale Airflow workers for high workload
kubectl scale deployment airflow-worker --replicas=4 -n data-platform

# Scale webserver for high availability
kubectl scale deployment airflow-webserver --replicas=2 -n data-platform

# Scale other services
kubectl scale deployment <service-name> --replicas=2 -n data-platform
```

### Local Access (Alternative to External)
```bash
# Start port-forwarding for local access
./scripts/port-forward.sh

# Then access via localhost:
# - Airflow:    http://localhost:8080
# - MinIO:      http://localhost:9001
# - Flower:     http://localhost:5555
# - Grafana:    http://localhost:3000
# - Prometheus: http://localhost:9090
```

## 📊 Production Capabilities

### Data Pipeline Features
- **Advanced ETL/ELT**: Build complex data transformation pipelines
- **Distributed Processing**: Scale across multiple Celery workers (32 concurrent tasks)
- **Flexible Scheduling**: Cron-based, event-driven, and manual execution
- **Robust Error Handling**: Automatic retry logic and failure notifications
- **Data Quality**: Built-in validation, testing, and monitoring

### Enterprise Storage & Connectivity
- **S3-Compatible Storage**: MinIO for data lakes and object storage
- **High-Performance Database**: PostgreSQL with connection pooling
- **External Integrations**: Connect to APIs, databases, cloud services
- **Multi-Format Support**: Handle CSV, JSON, Parquet, Avro, and more
- **Secure Connections**: Encrypted data transfer and storage

### Production Monitoring & Observability
- **Real-time Dashboards**: Grafana with pre-configured data source
- **Worker Health Monitoring**: Flower interface for Celery oversight
- **Metrics Collection**: Prometheus with Kubernetes integration
- **Log Aggregation**: Centralized logging via Kubernetes
- **Resource Tracking**: CPU, memory, and storage utilization

## 🔧 Advanced Configuration

### Custom DAG Development
```bash
# Method 1: Copy DAGs to running pods
kubectl cp my_dag.py airflow-webserver-xxx:/opt/airflow/dags/ -n data-platform

# Method 2: Use persistent volumes (recommended for production)
kubectl create configmap my-dags --from-file=dags/ -n data-platform
```

### Environment Configuration
```bash
# Update Airflow configuration
kubectl edit configmap airflow-config -n data-platform
kubectl rollout restart deployment/airflow-webserver -n data-platform

# Update resource limits
kubectl edit deployment airflow-worker -n data-platform
```

### Security Enhancement
```bash
# Regenerate security keys
./scripts/fix-airflow-secrets.sh

# Add TLS certificates for HTTPS
kubectl create secret tls airflow-tls --cert=cert.pem --key=key.pem -n data-platform

# Configure network policies (if supported)
kubectl apply -f network-policies.yaml
```

## 🚨 Troubleshooting

### Common Issues & Solutions

**Airflow Webserver Not Starting:**
```bash
# Most common issue - fix security keys
./scripts/fix-airflow-secrets.sh

# Check webserver logs
kubectl logs -l component=webserver -n data-platform

# Verify secrets
kubectl get secret airflow-secret -n data-platform -o yaml
```

**Services Not Accessible Externally:**
```bash
# Re-run external access setup
./scripts/expose-services.sh

# Check NodePort assignments
kubectl get svc -n data-platform

# Verify firewall/security group settings
```

**Worker Performance Issues:**
```bash
# Check worker resource usage
kubectl top pods -l component=worker -n data-platform

# Scale workers
kubectl scale deployment airflow-worker --replicas=4 -n data-platform

# Check Celery queues in Flower
```

**Database Connection Issues:**
```bash
# Check PostgreSQL status
kubectl logs postgres-primary-0 -n data-platform

# Test database connectivity
kubectl exec -it postgres-primary-0 -n data-platform -- psql -U postgres

# Verify database initialization
kubectl logs job/postgres-init -n data-platform
```

### Debug Commands
```bash
# Get all resources
kubectl get all -n data-platform

# Check system events
kubectl get events -n data-platform --sort-by='.lastTimestamp'

# Detailed pod information
kubectl describe pod <pod-name> -n data-platform

# Network debugging
kubectl exec -it <pod-name> -n data-platform -- nslookup <service-name>
```

## 🚀 Production Best Practices

### 1. Data Pipeline Development
1. **Start Simple**: Begin with basic DAGs and gradually add complexity
2. **Use Connections**: Configure external system connections in Airflow UI
3. **Implement Testing**: Add data quality checks and pipeline tests
4. **Monitor Performance**: Use Flower to track task execution
5. **Handle Failures**: Implement proper error handling and notifications

### 2. Storage Management
1. **Organize Buckets**: Create logical bucket structure in MinIO
2. **Set Lifecycle Policies**: Automate data archiving and cleanup
3. **Use Partitioning**: Organize data by date/type for better performance
4. **Monitor Usage**: Track storage consumption and costs
5. **Backup Strategy**: Implement regular backup procedures

### 3. Monitoring & Alerting
1. **Custom Dashboards**: Create business-specific monitoring dashboards
2. **Set Alerts**: Configure alerts for system and pipeline failures
3. **Performance Tuning**: Monitor resource usage and optimize
4. **Log Analysis**: Implement centralized log analysis
5. **Capacity Planning**: Track growth and plan scaling

### 4. Security & Compliance
1. **Access Control**: Implement proper RBAC and user management
2. **Data Encryption**: Ensure data encryption at rest and in transit
3. **Audit Logging**: Enable comprehensive audit trails
4. **Network Security**: Use network policies and firewalls
5. **Regular Updates**: Keep platform components updated

## 📈 Scaling for Production

### Horizontal Scaling
```bash
# Scale based on workload
kubectl scale deployment airflow-worker --replicas=6 -n data-platform
kubectl scale deployment airflow-webserver --replicas=2 -n data-platform

# Auto-scaling (requires metrics server)
kubectl autoscale deployment airflow-worker --cpu-percent=70 --min=2 --max=10 -n data-platform
```

### Vertical Scaling
```bash
# Increase worker resources
kubectl patch deployment airflow-worker -n data-platform -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "airflow-worker",
          "resources": {
            "requests": {"memory": "2Gi", "cpu": "1000m"},
            "limits": {"memory": "4Gi", "cpu": "2000m"}
          }
        }]
      }
    }
  }
}'
```

### Storage Scaling
```bash
# Expand persistent volumes (if supported by storage class)
kubectl patch pvc postgres-data-postgres-primary-0 -n data-platform -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

## 🎉 Success!

Your production Kubernetes Data Platform is ready with:

✅ **Apache Airflow 2.8.1** - Latest features and Python 3.11 support
✅ **CeleryExecutor** - Distributed task processing across workers
✅ **Production Security** - Auto-generated secure keys and secrets
✅ **External Access** - Team collaboration via NodePort services
✅ **Complete Monitoring** - Prometheus, Grafana, and Flower monitoring
✅ **Enterprise Storage** - S3-compatible MinIO object storage
✅ **High Availability** - Robust PostgreSQL and Redis infrastructure
✅ **Auto-scaling Ready** - Horizontal and vertical scaling capabilities

**🌟 Start building amazing data pipelines with your enterprise-grade platform!** 🚀📊💫

---

**Platform Version**: 3.0 Production Ready
**Airflow Version**: 2.8.1 with Python 3.11
**Architecture**: CeleryExecutor with distributed workers
**Security**: Production-grade with auto-generated secrets
**Access**: External NodePort + Local port-forwarding support
