#!/bin/bash
# Deployment Files Generator Part 2
# This script creates the remaining Kubernetes deployment YAML files

STORAGE_CLASS=${1:-"standard"}

# Include utility functions
source ../utils/functions.sh

create_monitoring_deployments() {
    print_info "Creating Grafana configuration..."
    cat > ../deployment/05-grafana.yaml << 'EOF'
# Grafana Configuration
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secret
  namespace: data-platform
type: Opaque
data:
  admin-password: YWRtaW4xMjM=  # admin123

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: data-platform
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus:9090
      isDefault: true

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secret
              key: admin-password
        - name: GF_DATABASE_TYPE
          value: "postgres"
        - name: GF_DATABASE_HOST
          value: "postgres-primary:5432"
        - name: GF_DATABASE_NAME
          value: "grafana"
        - name: GF_DATABASE_USER
          value: "postgres"
        - name: GF_DATABASE_PASSWORD
          value: "password123"
        ports:
        - containerPort: 3000
          name: grafana
        volumeMounts:
        - name: grafana-data
          mountPath: /var/lib/grafana
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
      - name: grafana-data
        persistentVolumeClaim:
          claimName: grafana-data-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-data-pvc
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
kind: Service
metadata:
  name: grafana
  namespace: data-platform
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
EOF
}

create_airflow_deployment() {
    print_info "Creating Airflow configuration..."
    cat > ../deployment/06-airflow.yaml << 'EOF'
# Apache Airflow Configuration
apiVersion: v1
kind: Secret
metadata:
  name: airflow-secret
  namespace: data-platform
type: Opaque
data:
  fernet-key: Wm5ldF9rZXlfaGVyZV9iYXNlNjRfZW5jb2RlZA==

---
apiVersion: batch/v1
kind: Job
metadata:
  name: airflow-db-init
  namespace: data-platform
spec:
  template:
    spec:
      containers:
      - name: airflow-db-init
        image: apache/airflow:2.7.1-python3.10
        command:
        - /bin/bash
        - -c
        - |
          airflow db init
          airflow users create \
            --username admin \
            --firstname Admin \
            --lastname User \
            --role Admin \
            --email admin@dataplatform.local \
            --password admin123
        env:
        - name: AIRFLOW__CORE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
      restartPolicy: OnFailure

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-webserver
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow
      component: webserver
  template:
    metadata:
      labels:
        app: airflow
        component: webserver
    spec:
      containers:
      - name: airflow-webserver
        image: apache/airflow:2.7.1-python3.10
        command: ["airflow", "webserver"]
        env:
        - name: AIRFLOW__CORE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/airflow"
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        ports:
        - containerPort: 8080
          name: webserver
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-scheduler
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow
      component: scheduler
  template:
    metadata:
      labels:
        app: airflow
        component: scheduler
    spec:
      containers:
      - name: airflow-scheduler
        image: apache/airflow:2.7.1-python3.10
        command: ["airflow", "scheduler"]
        env:
        - name: AIRFLOW__CORE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/airflow"
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"

---
apiVersion: v1
kind: Service
metadata:
  name: airflow-webserver
  namespace: data-platform
spec:
  selector:
    app: airflow
    component: webserver
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
EOF
}

create_superset_deployment() {
    print_info "Creating Superset configuration..."
    cat > ../deployment/07-superset.yaml << 'EOF'
# Apache Superset Configuration
apiVersion: v1
kind: Secret
metadata:
  name: superset-secret
  namespace: data-platform
type: Opaque
data:
  secret-key: c3VwZXJzZXRfc2VjcmV0X2tleV8xMjM=

---
apiVersion: batch/v1
kind: Job
metadata:
  name: superset-init
  namespace: data-platform
spec:
  template:
    spec:
      containers:
      - name: superset-init
        image: apache/superset:3.0.0
        command:
        - /bin/bash
        - -c
        - |
          superset db upgrade
          superset fab create-admin \
            --username admin \
            --firstname Admin \
            --lastname User \
            --email admin@dataplatform.local \
            --password admin123
          superset init
        env:
        - name: DATABASE_URL
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/superset"
        - name: SUPERSET_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: superset-secret
              key: secret-key
      restartPolicy: OnFailure

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: superset
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: superset
  template:
    metadata:
      labels:
        app: superset
    spec:
      containers:
      - name: superset
        image: apache/superset:3.0.0
        command: ["gunicorn", "--bind", "0.0.0.0:8088", "superset.app:create_app()"]
        env:
        - name: DATABASE_URL
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/superset"
        - name: SUPERSET_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: superset-secret
              key: secret-key
        ports:
        - containerPort: 8088
          name: web
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"

---
apiVersion: v1
kind: Service
metadata:
  name: superset
  namespace: data-platform
spec:
  selector:
    app: superset
  ports:
  - port: 8088
    targetPort: 8088
  type: ClusterIP
EOF
}

create_minio_deployment() {
    print_info "Creating MinIO configuration..."
    cat > ../deployment/08-minio.yaml << 'EOF'
# MinIO Configuration
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
  namespace: data-platform
type: Opaque
data:
  root-user: bWluaW9hZG1pbg==  # minioadmin
  root-password: bWluaW9hZG1pbjEyMw==  # minioadmin123

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        command:
        - /bin/bash
        - -c
        args:
        - minio server /data --console-address ":9001"
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: minio-secret
              key: root-user
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-secret
              key: root-password
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: minio-data
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 20
      volumes:
      - name: minio-data
        persistentVolumeClaim:
          claimName: minio-data-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-data-pvc
  namespace: data-platform
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: STORAGE_CLASS_PLACEHOLDER
  resources:
    requests:
      storage: 50Gi

---
apiVersion: v1
kind: Service
metadata:
  name: minio-api
  namespace: data-platform
spec:
  selector:
    app: minio
  ports:
  - port: 9000
    targetPort: 9000
    name: api
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: minio-console
  namespace: data-platform
spec:
  selector:
    app: minio
  ports:
  - port: 9001
    targetPort: 9001
    name: console
  type: ClusterIP

---
# MinIO Setup Job
apiVersion: batch/v1
kind: Job
metadata:
  name: minio-setup
  namespace: data-platform
spec:
  template:
    spec:
      containers:
      - name: mc
        image: minio/mc:latest
        command:
        - /bin/bash
        - -c
        - |
          # Wait for MinIO to be ready
          until mc alias set myminio http://minio-api:9000 minioadmin minioadmin123; do
            echo "Waiting for MinIO to be ready..."
            sleep 5
          done

          # Create buckets for data lake
          mc mb myminio/warehouse --ignore-existing
          mc mb myminio/lakehouse --ignore-existing
          mc mb myminio/datalake --ignore-existing
          mc mb myminio/bronze --ignore-existing
          mc mb myminio/silver --ignore-existing
          mc mb myminio/gold --ignore-existing
          mc mb myminio/backups --ignore-existing

          echo "MinIO setup completed successfully!"
      restartPolicy: OnFailure
EOF
}

create_trino_deployment() {
    print_info "Creating Trino configuration..."
    cat > ../deployment/09-trino-iceberg.yaml << 'EOF'
# Trino with Iceberg Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-config
  namespace: data-platform
data:
  config.properties: |
    coordinator=true
    node-scheduler.include-coordinator=false
    http-server.http.port=8080
    discovery.uri=http://trino-coordinator:8080
    query.max-memory=2GB
    query.max-memory-per-node=1GB
    discovery-server.enabled=true

  node.properties: |
    node.environment=production
    node.id=coordinator
    node.data-dir=/data/trino

  jvm.config: |
    -server
    -Xmx2G
    -XX:+UseG1GC
    -XX:G1HeapRegionSize=32M
    -XX:+UseGCOverheadLimit
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:+ExitOnOutOfMemoryError
    -Djdk.attach.allowAttachSelf=true

  log.properties: |
    io.trino=INFO

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trino-coordinator
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trino
      component: coordinator
  template:
    metadata:
      labels:
        app: trino
        component: coordinator
    spec:
      containers:
      - name: trino
        image: trinodb/trino:latest
        env:
        - name: TRINO_ENVIRONMENT
          value: "production"
        ports:
        - containerPort: 8080
          name: http
        volumeMounts:
        - name: trino-config
          mountPath: /etc/trino
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /v1/info
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /v1/info
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: trino-config
        configMap:
          name: trino-config

---
apiVersion: v1
kind: Service
metadata:
  name: trino-coordinator
  namespace: data-platform
spec:
  selector:
    app: trino
    component: coordinator
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
EOF

    # Create Kafka deployment in a separate function for better organization
    create_kafka_deployment
}

create_kafka_deployment() {
    print_info "Creating Kafka configuration..."
    cat > ../deployment/10-kafka.yaml << 'EOF'
# Kafka Configuration
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zookeeper
  namespace: data-platform
spec:
  serviceName: zookeeper
  replicas: 1
  selector:
    matchLabels:
      app: zookeeper
  template:
    metadata:
      labels:
        app: zookeeper
    spec:
      containers:
      - name: zookeeper
        image: confluentinc/cp-zookeeper:latest
        env:
        - name: ZOOKEEPER_CLIENT_PORT
          value: "2181"
        - name: ZOOKEEPER_TICK_TIME
          value: "2000"
        ports:
        - containerPort: 2181
          name: client
        volumeMounts:
        - name: zookeeper-data
          mountPath: /var/lib/zookeeper/data
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          exec:
            command: ["/bin/bash", "-c", "echo ruok | nc localhost 2181"]
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["/bin/bash", "-c", "echo ruok | nc localhost 2181"]
          initialDelaySeconds: 30
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: zookeeper-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: STORAGE_CLASS_PLACEHOLDER
      resources:
        requests:
          storage: 10Gi

---
apiVersion: v1
kind: Service
metadata:
  name: zookeeper
  namespace: data-platform
spec:
  selector:
    app: zookeeper
  ports:
  - port: 2181
    targetPort: 2181
  clusterIP: None

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  namespace: data-platform
spec:
  serviceName: kafka
  replicas: 1
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      containers:
      - name: kafka
        image: confluentinc/cp-kafka:latest
        env:
        - name: KAFKA_BROKER_ID
          value: "1"
        - name: KAFKA_ZOOKEEPER_CONNECT
          value: "zookeeper:2181"
        - name: KAFKA_LISTENERS
          value: "PLAINTEXT://0.0.0.0:9092"
        - name: KAFKA_ADVERTISED_LISTENERS
          value: "PLAINTEXT://kafka:9092"
        - name: KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
          value: "1"
        - name: KAFKA_AUTO_CREATE_TOPICS_ENABLE
          value: "true"
        ports:
        - containerPort: 9092
          name: kafka
        volumeMounts:
        - name: kafka-data
          mountPath: /var/lib/kafka/data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command: ["/bin/bash", "-c", "kafka-broker-api-versions --bootstrap-server localhost:9092"]
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          exec:
            command: ["/bin/bash", "-c", "kafka-broker-api-versions --bootstrap-server localhost:9092"]
          initialDelaySeconds: 60
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: kafka-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: STORAGE_CLASS_PLACEHOLDER
      resources:
        requests:
          storage: 20Gi

---
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: data-platform
spec:
  selector:
    app: kafka
  ports:
  - port: 9092
    targetPort: 9092
  clusterIP: None

---
# Kafka Topics Creation Job
apiVersion: batch/v1
kind: Job
metadata:
  name: kafka-topics-setup
  namespace: data-platform
spec:
  template:
    spec:
      containers:
      - name: kafka-topics
        image: confluentinc/cp-kafka:latest
        command:
        - /bin/bash
        - -c
        - |
          # Wait for Kafka to be ready
          until kafka-broker-api-versions --bootstrap-server kafka:9092; do
            echo "Waiting for Kafka..."
            sleep 10
          done

          # Create topics for data platform
          kafka-topics --create --topic events --bootstrap-server kafka:9092 --partitions 3 --replication-factor 1 --if-not-exists
          kafka-topics --create --topic metrics --bootstrap-server kafka:9092 --partitions 3 --replication-factor 1 --if-not-exists
          kafka-topics --create --topic logs --bootstrap-server kafka:9092 --partitions 3 --replication-factor 1 --if-not-exists
          kafka-topics --create --topic airflow-events --bootstrap-server kafka:9092 --partitions 3 --replication-factor 1 --if-not-exists

          # List created topics
          kafka-topics --list --bootstrap-server kafka:9092

          echo "Kafka topics created successfully!"
      restartPolicy: OnFailure
EOF

    # Create the final deployment files
    create_file_services_deployment
}

create_file_services_deployment() {
    print_info "Creating SFTP and File Browser configuration..."
    cat > ../deployment/11-sftp-filebrowser.yaml << 'EOF'
# SFTP and File Browser Configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sftp-server
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sftp-server
  template:
    metadata:
      labels:
        app: sftp-server
    spec:
      containers:
      - name: sftp
        image: atmoz/sftp:alpine
        env:
        - name: SFTP_USERS
          value: "sftpuser:sftppass123:1001:1001:/home/sftpuser datauser:datapass123:1002:1002:/home/datauser"
        ports:
        - containerPort: 22
          name: sftp
        volumeMounts:
        - name: sftp-data
          mountPath: /home
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          capabilities:
            add: ["SYS_ADMIN"]
      volumes:
      - name: sftp-data
        persistentVolumeClaim:
          claimName: sftp-data-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sftp-data-pvc
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
  name: sftp-server
  namespace: data-platform
spec:
  selector:
    app: sftp-server
  ports:
  - port: 22
    targetPort: 22
  type: ClusterIP

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filebrowser
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: filebrowser
  template:
    metadata:
      labels:
        app: filebrowser
    spec:
      containers:
      - name: filebrowser
        image: filebrowser/filebrowser:latest
        ports:
        - containerPort: 8080
          name: web
        volumeMounts:
        - name: filebrowser-data
          mountPath: /srv
        - name: filebrowser-db
          mountPath: /database
        env:
        - name: FB_DATABASE
          value: "/database/filebrowser.db"
        - name: FB_ROOT
          value: "/srv"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: filebrowser-data
        persistentVolumeClaim:
          claimName: filebrowser-data-pvc
      - name: filebrowser-db
        persistentVolumeClaim:
          claimName: filebrowser-db-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: filebrowser-data-pvc
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
kind: PersistentVolumeClaim
metadata:
  name: filebrowser-db-pvc
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
  name: filebrowser
  namespace: data-platform
spec:
  selector:
    app: filebrowser
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
EOF

    # Create the final ingress and monitoring deployment
    create_ingress_monitoring_deployment
}

create_ingress_monitoring_deployment() {
    print_info "Creating Ingress and Monitoring configuration..."
    cat > ../deployment/12-ingress-monitoring.yaml << 'EOF'
# Ingress and Additional Monitoring
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: data-platform-ingress
  namespace: data-platform
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: dataplatform.local
    http:
      paths:
      - path: /grafana
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
      - path: /airflow
        pathType: Prefix
        backend:
          service:
            name: airflow-webserver
            port:
              number: 8080
      - path: /superset
        pathType: Prefix
        backend:
          service:
            name: superset
            port:
              number: 8088
      - path: /minio
        pathType: Prefix
        backend:
          service:
            name: minio-console
            port:
              number: 9001
      - path: /files
        pathType: Prefix
        backend:
          service:
            name: filebrowser
            port:
              number: 8080

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:latest
        args:
        - --config.file=/etc/alertmanager/alertmanager.yml
        - --storage.path=/alertmanager
        - --web.external-url=http://alertmanager:9093
        ports:
        - containerPort: 9093
          name: web
        volumeMounts:
        - name: alertmanager-config
          mountPath: /etc/alertmanager
        - name: alertmanager-data
          mountPath: /alertmanager
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9093
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9093
          initialDelaySeconds: 30
          periodSeconds: 5
      volumes:
      - name: alertmanager-config
        configMap:
          name: alertmanager-config
      - name: alertmanager-data
        persistentVolumeClaim:
          claimName: alertmanager-data-pvc

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: data-platform
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'localhost:587'
      smtp_from: 'alerts@dataplatform.local'

    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'

    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://webhook-receiver:5000/webhook'
        send_resolved: true

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: alertmanager-data-pvc
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
kind: Service
metadata:
  name: alertmanager
  namespace: data-platform
spec:
  selector:
    app: alertmanager
  ports:
  - port: 9093
    targetPort: 9093
  type: ClusterIP
EOF
}

# Execute all deployment creation functions
create_monitoring_deployments
create_airflow_deployment
create_superset_deployment
create_minio_deployment
create_trino_deployment

print_success "All deployment files created successfully!"