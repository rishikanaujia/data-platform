#!/bin/bash
# Deployment Files Generator
# This script creates all Kubernetes deployment YAML files

STORAGE_CLASS=${1:-"standard"}

# Include utility functions
source ../utils/functions.sh

create_deployment_files() {
    print_header "Creating Deployment Files"

    # 01-postgres-ha.yaml
    print_info "Creating PostgreSQL HA configuration..."
    cat > ../deployment/01-postgres-ha.yaml << 'EOF'
# PostgreSQL High Availability Configuration
apiVersion: v1
kind: Namespace
metadata:
  name: data-platform
  labels:
    name: data-platform

---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: data-platform
type: Opaque
data:
  password: cGFzc3dvcmQxMjM=  # password123
  replication-password: cmVwbGljYXRvcjEyMw==  # replicator123

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: data-platform
data:
  postgresql.conf: |
    max_connections = 200
    shared_buffers = 256MB
    effective_cache_size = 1GB
    maintenance_work_mem = 64MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 1.1
    effective_io_concurrency = 200
    work_mem = 4MB
    min_wal_size = 1GB
    max_wal_size = 4GB
    hot_standby = on
    wal_level = replica
    max_wal_senders = 3
    wal_keep_segments = 8
    synchronous_commit = on

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-primary
  namespace: data-platform
spec:
  serviceName: postgres-primary
  replicas: 1
  selector:
    matchLabels:
      app: postgres
      role: primary
  template:
    metadata:
      labels:
        app: postgres
        role: primary
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: "platform_db"
        - name: POSTGRES_USER
          value: "postgres"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
          name: postgres
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        command:
        - postgres
        - -c
        - config_file=/etc/postgresql/postgresql.conf
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: STORAGE_CLASS_PLACEHOLDER
      resources:
        requests:
          storage: 50Gi

---
apiVersion: v1
kind: Service
metadata:
  name: postgres-primary
  namespace: data-platform
spec:
  selector:
    app: postgres
    role: primary
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP

---
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-init
  namespace: data-platform
spec:
  template:
    spec:
      containers:
      - name: postgres-init
        image: postgres:15-alpine
        env:
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        command:
        - /bin/bash
        - -c
        - |
          until pg_isready -h postgres-primary -p 5432 -U postgres; do
            echo "Waiting for PostgreSQL..."
            sleep 5
          done

          psql -h postgres-primary -U postgres -c "CREATE DATABASE airflow;" || true
          psql -h postgres-primary -U postgres -c "CREATE DATABASE superset;" || true
          psql -h postgres-primary -U postgres -c "CREATE DATABASE grafana;" || true
          psql -h postgres-primary -U postgres -c "CREATE DATABASE hive_metastore;" || true

          echo "Databases created successfully!"
      restartPolicy: OnFailure
EOF

    # 02-redis-ha.yaml
    print_info "Creating Redis configuration..."
    cat > ../deployment/02-redis-ha.yaml << 'EOF'
# Redis Configuration
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
  namespace: data-platform
type: Opaque
data:
  password: cmVkaXNwYXNzd29yZDEyMw==  # redispassword123

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: data-platform
data:
  redis.conf: |
    bind 0.0.0.0
    port 6379
    tcp-backlog 511
    timeout 0
    tcp-keepalive 300
    daemonize no
    supervised no
    pidfile /var/run/redis_6379.pid
    loglevel notice
    logfile ""
    databases 16
    always-show-logo yes
    save 900 1
    save 300 10
    save 60 10000
    stop-writes-on-bgsave-error yes
    rdbcompression yes
    rdbchecksum yes
    dbfilename dump.rdb
    dir ./
    maxmemory-policy allkeys-lru
    requirepass redispassword123
    appendonly yes
    appendfilename "appendonly.aof"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-master
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
      role: master
  template:
    metadata:
      labels:
        app: redis
        role: master
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command: ["redis-server"]
        args: ["/etc/redis/redis.conf"]
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - name: redis-data
          mountPath: /data
        - name: redis-config
          mountPath: /etc/redis
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - redis-cli
            - -a
            - redispassword123
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
      - name: redis-data
        persistentVolumeClaim:
          claimName: redis-data-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data-pvc
  namespace: data-platform
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: STORAGE_CLASS_PLACEHOLDER
  resources:
    requests:
      storage: 10Gi

---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: data-platform
spec:
  selector:
    app: redis
    role: master
  ports:
  - port: 6379
    targetPort: 6379
  type: ClusterIP
EOF

    # 03-openldap.yaml
    print_info "Creating OpenLDAP configuration..."
    cat > ../deployment/03-openldap.yaml << 'EOF'
# OpenLDAP Configuration
apiVersion: v1
kind: Secret
metadata:
  name: ldap-secret
  namespace: data-platform
type: Opaque
data:
  admin-password: YWRtaW4xMjM=  # admin123

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openldap
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openldap
  template:
    metadata:
      labels:
        app: openldap
    spec:
      containers:
      - name: openldap
        image: osixia/openldap:1.5.0
        env:
        - name: LDAP_ORGANISATION
          value: "Data Platform"
        - name: LDAP_DOMAIN
          value: "dataplatform.local"
        - name: LDAP_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ldap-secret
              key: admin-password
        ports:
        - containerPort: 389
          name: ldap
        - containerPort: 636
          name: ldaps
        volumeMounts:
        - name: ldap-data
          mountPath: /var/lib/ldap
        - name: ldap-config
          mountPath: /etc/ldap/slapd.d
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: ldap-data
        persistentVolumeClaim:
          claimName: ldap-data-pvc
      - name: ldap-config
        persistentVolumeClaim:
          claimName: ldap-config-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ldap-data-pvc
  namespace: data-platform
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: STORAGE_CLASS_PLACEHOLDER
  resources:
    requests:
      storage: 5Gi

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ldap-config-pvc
  namespace: data-platform
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: STORAGE_CLASS_PLACEHOLDER
  resources:
    requests:
      storage: 1Gi

---
apiVersion: v1
kind: Service
metadata:
  name: openldap
  namespace: data-platform
spec:
  selector:
    app: openldap
  ports:
  - port: 389
    targetPort: 389
    name: ldap
  - port: 636
    targetPort: 636
    name: ldaps
  type: ClusterIP
EOF

    # 04-prometheus.yaml
    print_info "Creating Prometheus configuration..."
    cat > ../deployment/04-prometheus.yaml << 'EOF'
# Prometheus Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: data-platform
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
    - job_name: 'prometheus'
      static_configs:
      - targets: ['localhost:9090']

    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --web.console.libraries=/usr/share/prometheus/console_libraries
        - --web.console.templates=/usr/share/prometheus/consoles
        - --storage.tsdb.retention.time=15d
        - --web.enable-lifecycle
        ports:
        - containerPort: 9090
          name: web
        volumeMounts:
        - name: prometheus-data
          mountPath: /prometheus
        - name: prometheus-config
          mountPath: /etc/prometheus
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-data
        persistentVolumeClaim:
          claimName: prometheus-data-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-data-pvc
  namespace: data-platform
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: STORAGE_CLASS_PLACEHOLDER
  resources:
    requests:
      storage: 20Gi

---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: data-platform
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP
EOF

    print_success "Core infrastructure deployment files created!"
}

# Create remaining deployment files
create_remaining_deployments() {
    print_header "Creating Remaining Deployment Files"

    # Continue with other deployment files...
    # This function will be continued in the next script file
    print_info "Creating remaining deployment configurations..."

    # Call the second deployment script
    bash create-deployments-part2.sh "$STORAGE_CLASS"
}

# Execute main function
create_deployment_files
create_remaining_deployments

print_success "All deployment files created successfully!"