# Kubernetes Data Platform

A simple, production-ready data platform deployed on Kubernetes.

## 🏗️ Architecture

### Core Services
- **PostgreSQL**: Primary database
- **Redis**: Caching layer
- **Apache Airflow**: Workflow orchestration
- **MinIO**: S3-compatible object storage
- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and visualization

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster with kubectl access
- 8GB+ RAM, 4+ CPU cores, 50GB+ storage

### 1. Setup Environment
```bash
./scripts/setup-environment.sh
```

### 2. Deploy Platform
```bash
./scripts/deploy.sh
```

### 3. Verify Deployment
```bash
./scripts/check-health.sh
```

### 4. Access Services
```bash
./scripts/port-forward.sh
```

## 🔐 Access Information

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | http://localhost:3000 | admin / admin123 |
| **Airflow** | http://localhost:8080 | admin / admin123 |
| **Flower** | http://localhost:5555 | - |
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin123 |
| **Prometheus** | http://localhost:9090 | - |

📋 Summary of Required Changes:
✅ Airflow 2.8.1 YAML - Already implemented
🔧 deploy.sh - Add worker and flower wait commands
🔧 port-forward.sh - Add flower port-forward
🔧 Display URLs - Add Flower to service lists
📖 README.md - Add Flower to documentation (optional)
🎯 What You Get After These Updates:

Advanced Airflow 2.8.1 with CeleryExecutor
High Availability with multiple replicas
Flower Monitoring for Celery workers
Production-ready configuration
Scalable architecture with 3 workers

## 🛠️ Management

### Check Status
```bash
./scripts/check-health.sh
```

### View Logs
```bash
kubectl logs <pod-name> -n data-platform
```

### Scale Services
```bash
kubectl scale deployment <service> --replicas=2 -n data-platform
```

---

**🎉 Enjoy your Kubernetes Data Platform!**
