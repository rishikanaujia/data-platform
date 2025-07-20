#!/bin/bash
# Simple Fixed Setup Script for Kubernetes Data Platform

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Print functions
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

# Project configuration
PROJECT_NAME="kubernetes-data-platform"
PROJECT_DIR=$(pwd)/$PROJECT_NAME

print_header "Kubernetes Data Platform - Simple Setup"

# Detect Kubernetes environment
detect_k8s_env() {
    if command -v microk8s &> /dev/null; then
        K8S_TYPE="microk8s"
        STORAGE_CLASS="microk8s-hostpath"
        print_info "Detected MicroK8s environment"
    elif kubectl get nodes 2>/dev/null | grep -q minikube; then
        K8S_TYPE="minikube"
        STORAGE_CLASS="standard"
        print_info "Detected Minikube environment"
    else
        K8S_TYPE="generic"
        STORAGE_CLASS="standard"
        print_info "Using generic Kubernetes configuration"
    fi
}

# Create project structure
create_project_structure() {
    print_header "Creating Project Structure"

    if [ -d "$PROJECT_DIR" ]; then
        print_warning "Directory $PROJECT_DIR already exists"
        read -p "Remove existing directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$PROJECT_DIR"
            print_success "Removed existing directory"
        else
            print_error "Cannot continue with existing directory"
            exit 1
        fi
    fi

    mkdir -p "$PROJECT_DIR"/{deployment,scripts,docs}
    cd "$PROJECT_DIR"

    print_success "Created project directory: $PROJECT_DIR"
}

# Create all deployment files in a single function to avoid complexity
create_all_deployments() {
    print_header "Creating All Deployment Files"

    # Create 01-postgres-ha.yaml
    print_info "Creating PostgreSQL configuration..."
    cat > deployment/01-postgres-ha.yaml << EOF
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
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: $STORAGE_CLASS
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
          value: "password123"
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

          echo "Databases created successfully!"
      restartPolicy: OnFailure
EOF

    # Create remaining deployment files
    print_info "Creating Redis configuration..."
    cat > deployment/02-redis.yaml << EOF
# Redis Configuration
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
        args: ["--requirepass", "redispassword123"]
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
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
  storageClassName: $STORAGE_CLASS
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

    print_info "Creating Prometheus configuration..."
    cat > deployment/03-prometheus.yaml << EOF
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
    scrape_configs:
    - job_name: 'prometheus'
      static_configs:
      - targets: ['localhost:9090']

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
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --storage.tsdb.retention.time=15d
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
  storageClassName: $STORAGE_CLASS
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

    print_info "Creating Grafana configuration..."
    cat > deployment/04-grafana.yaml << EOF
# Grafana Configuration
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
          value: "admin123"
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
  storageClassName: $STORAGE_CLASS
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

    print_info "Creating Airflow configuration..."
    cat > deployment/05-airflow.yaml << EOF
# Fixed Apache Airflow 2.8.1 Configuration - Removed Duplicate Sections
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-config
  namespace: data-platform
data:
  airflow.cfg: |
    [core]
    dags_folder = /opt/airflow/dags
    hostname_callable = airflow.utils.net.get_host_ip_address
    default_timezone = utc
    executor = CeleryExecutor
    parallelism = 32
    max_active_tasks_per_dag = 16
    dags_are_paused_at_creation = True
    max_active_runs_per_dag = 16
    load_examples = False
    plugins_folder = /opt/airflow/plugins
    donot_pickle = False
    dagbag_import_timeout = 30
    task_runner = StandardTaskRunner
    default_impersonation =
    security =
    unit_test_mode = False
    enable_xcom_pickling = False
    killed_task_cleanup_time = 60
    dag_discovery_safe_mode = True
    default_task_retries = 0
    min_serialized_dag_update_interval = 30
    min_serialized_dag_fetch_interval = 10
    max_serialized_dag_update_interval = 180
    compress_serialized_dags = False

    [database]
    sql_alchemy_conn = postgresql+psycopg2://postgres:password123@postgres-primary:5432/airflow
    sql_alchemy_pool_size = 10
    sql_alchemy_max_overflow = 20
    sql_alchemy_pool_recycle = 1800
    sql_alchemy_pool_pre_ping = True
    sql_alchemy_schema =

    [celery]
    broker_url = redis://:redispassword123@redis:6379/1
    result_backend = redis://:redispassword123@redis:6379/1
    flower_host = 0.0.0.0
    flower_url_prefix =
    flower_port = 5555
    flower_basic_auth =
    default_queue = default
    sync =
    celery_app_name = airflow.executors.celery_executor
    worker_concurrency = 16
    worker_log_server_port = 8793
    broker_transport_options = {"visibility_timeout": 21600}
    event_buffer_size = 1000
    worker_enable_remote_control = true
    result_expires = 3600
    task_track_started = True
    task_publish_retry = True
    worker_prefetch_multiplier = 1

    [operators]
    default_owner = airflow
    default_cpus = 1
    default_ram = 512
    default_disk = 512
    default_gpus = 0
    allow_illegal_arguments = False

    [webserver]
    base_url = http://localhost:8080
    default_ui_timezone = UTC
    web_server_host = 0.0.0.0
    web_server_port = 8080
    web_server_ssl_cert =
    web_server_ssl_key =
    web_server_master_timeout = 120
    web_server_worker_timeout = 120
    worker_refresh_batch_size = 1
    worker_refresh_interval = 6000
    secret_key = temporary_key
    workers = 4
    worker_class = sync
    access_logfile = -
    error_logfile = -
    expose_config = False
    authenticate = False
    filter_by_owner = False
    owner_mode = user
    dag_default_view = tree
    dag_orientation = LR
    demo_mode = False
    log_fetch_timeout_sec = 5
    hide_paused_dags_by_default = False
    page_size = 100
    navbar_color = #fff
    default_dag_run_display_number = 25
    enable_proxy_fix = False
    proxy_fix_x_for = 1
    proxy_fix_x_proto = 1
    proxy_fix_x_host = 1
    proxy_fix_x_port = 1
    proxy_fix_x_prefix = 1
    cookie_secure = False
    cookie_samesite = Lax
    default_wrap = False
    x_frame_enabled = True
    show_recent_stats_for_completed_runs = True
    update_fab_perms = True

    [email]
    email_backend = airflow.utils.email.send_email_smtp
    email_conn_id = smtp_default
    default_email_on_retry = True
    default_email_on_failure = True

    [smtp]
    smtp_host = localhost
    smtp_starttls = True
    smtp_ssl = False
    smtp_user =
    smtp_password =
    smtp_port = 587
    smtp_mail_from = airflow@example.com
    smtp_timeout = 30
    smtp_retry_limit = 5

    [logging]
    base_log_folder = /opt/airflow/logs
    remote_logging = False
    remote_log_conn_id =
    remote_base_log_folder =
    encrypt_s3_logs = False
    logging_level = INFO
    fab_logging_level = WARN
    logging_config_class =
    colored_console_log = True
    colored_log_format = [%%(blue)s%%(asctime)s%%(reset)s] {{%%(blue)s%%(filename)s:%%(reset)s%%(lineno)d}} %%(log_color)s%%(levelname)s%%(reset)s - %%(log_color)s%%(message)s%%(reset)s
    colored_formatter_class = airflow.utils.log.colored_log.CustomTTYColoredFormatter
    log_format = [%%(asctime)s] {{%%(filename)s:%%(lineno)d}} %%(levelname)s - %%(message)s
    simple_log_format = %%(asctime)s %%(levelname)s - %%(message)s
    task_log_prefix_template =
    log_filename_template = {{ ti.dag_id }}/{{ ti.task_id }}/{{ ts }}/{{ try_number }}.log
    log_processor_filename_template = {{ filename }}.log
    dag_processor_manager_log_location = /opt/airflow/logs/dag_processor_manager/dag_processor_manager.log
    task_log_reader = task

    [metrics]
    statsd_on = False
    statsd_host = localhost
    statsd_port = 8125
    statsd_prefix = airflow
    statsd_allow_list =
    stat_name_handler =
    statsd_datadog_enabled = False
    statsd_datadog_tags =
    statsd_custom_client_path =

    [secrets]
    backend =
    backend_kwargs =

    [cli]
    api_client = airflow.api.client.json_client
    endpoint_url = http://localhost:8080

    [debug]
    fail_fast = False

    [api]
    enable_experimental_api = False
    auth_backends = airflow.api.auth.backend.basic_auth,airflow.api.auth.backend.session
    maximum_page_limit = 100
    fallback_page_limit = 100

    [admin]
    hide_sensitive_variable_fields = True
    sensitive_variable_fields =

---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-secret
  namespace: data-platform
type: Opaque
data:
  fernet-key: Wm5ldF9rZXlfaGVyZV9iYXNlNjRfZW5jb2RlZA==
  webserver-secret-key: dGVtcG9yYXJ5X2tleQ==

---
apiVersion: batch/v1
kind: Job
metadata:
  name: airflow-db-init-fixed
  namespace: data-platform
spec:
  template:
    spec:
      initContainers:
      - name: wait-for-postgres
        image: busybox:1.35
        command:
        - /bin/sh
        - -c
        - |
          echo "Waiting for PostgreSQL to be ready..."
          until nc -z postgres-primary 5432; do
            echo "PostgreSQL not ready, waiting..."
            sleep 5
          done
          echo "PostgreSQL is ready!"
      containers:
      - name: airflow-db-init
        image: apache/airflow:2.8.1-python3.11
        command:
        - /bin/bash
        - -c
        - |
          # Initialize database
          airflow db init

          # Create admin user
          airflow users create \
            --username admin \
            --firstname Admin \
            --lastname User \
            --role Admin \
            --email admin@dataplatform.local \
            --password admin123
        env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "CeleryExecutor"
        - name: AIRFLOW__CORE__LOAD_EXAMPLES
          value: "False"
        volumeMounts:
        - name: airflow-config
          mountPath: /opt/airflow/airflow.cfg
          subPath: airflow.cfg
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: airflow-config
        configMap:
          name: airflow-config
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
        image: apache/airflow:2.8.1-python3.11
        command:
        - /bin/bash
        - -c
        - |
          # Start webserver
          airflow webserver --port 8080
        env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "CeleryExecutor"
        - name: AIRFLOW__CORE__LOAD_EXAMPLES
          value: "False"
        ports:
        - containerPort: 8080
          name: webserver
        volumeMounts:
        - name: airflow-config
          mountPath: /opt/airflow/airflow.cfg
          subPath: airflow.cfg
        - name: airflow-logs
          mountPath: /opt/airflow/logs
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 120
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
      volumes:
      - name: airflow-config
        configMap:
          name: airflow-config
      - name: airflow-logs
        persistentVolumeClaim:
          claimName: airflow-logs-pvc

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
        image: apache/airflow:2.8.1-python3.11
        command:
        - /bin/bash
        - -c
        - |
          # Start scheduler
          airflow scheduler
        env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "CeleryExecutor"
        - name: AIRFLOW__CORE__LOAD_EXAMPLES
          value: "False"
        volumeMounts:
        - name: airflow-config
          mountPath: /opt/airflow/airflow.cfg
          subPath: airflow.cfg
        - name: airflow-logs
          mountPath: /opt/airflow/logs
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
            - /bin/bash
            - -c
            - "pgrep -f 'airflow scheduler'"
          initialDelaySeconds: 120
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
      volumes:
      - name: airflow-config
        configMap:
          name: airflow-config
      - name: airflow-logs
        persistentVolumeClaim:
          claimName: airflow-logs-pvc

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-worker
  namespace: data-platform
spec:
  replicas: 2
  selector:
    matchLabels:
      app: airflow
      component: worker
  template:
    metadata:
      labels:
        app: airflow
        component: worker
    spec:
      containers:
      - name: airflow-worker
        image: apache/airflow:2.8.1-python3.11
        command:
        - /bin/bash
        - -c
        - |
          # Start celery worker
          airflow celery worker
        env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "CeleryExecutor"
        - name: AIRFLOW__CELERY__WORKER_CONCURRENCY
          value: "16"
        volumeMounts:
        - name: airflow-config
          mountPath: /opt/airflow/airflow.cfg
          subPath: airflow.cfg
        - name: airflow-logs
          mountPath: /opt/airflow/logs
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: airflow-config
        configMap:
          name: airflow-config
      - name: airflow-logs
        persistentVolumeClaim:
          claimName: airflow-logs-pvc

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-flower
  namespace: data-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow
      component: flower
  template:
    metadata:
      labels:
        app: airflow
        component: flower
    spec:
      containers:
      - name: airflow-flower
        image: apache/airflow:2.8.1-python3.11
        command:
        - /bin/bash
        - -c
        - |
          # Start flower
          airflow celery flower
        env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:password123@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:redispassword123@redis:6379/1"
        - name: AIRFLOW__CELERY__FLOWER_HOST
          value: "0.0.0.0"
        - name: AIRFLOW__CELERY__FLOWER_PORT
          value: "5555"
        ports:
        - containerPort: 5555
          name: flower
        volumeMounts:
        - name: airflow-config
          mountPath: /opt/airflow/airflow.cfg
          subPath: airflow.cfg
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
            port: 5555
          initialDelaySeconds: 120
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 5555
          initialDelaySeconds: 60
          periodSeconds: 10
      volumes:
      - name: airflow-config
        configMap:
          name: airflow-config

---
# Fixed Persistent Volume Claims for MicroK8s
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: airflow-logs-pvc
  namespace: data-platform
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: microk8s-hostpath
  resources:
    requests:
      storage: 10Gi

---
# Services
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
    name: webserver
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: airflow-flower
  namespace: data-platform
spec:
  selector:
    app: airflow
    component: flower
  ports:
  - port: 5555
    targetPort: 5555
    name: flower
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: airflow-worker
  namespace: data-platform
spec:
  selector:
    app: airflow
    component: worker
  ports:
  - port: 8793
    targetPort: 8793
    name: worker-log
  clusterIP: None
EOF

    print_info "Creating MinIO configuration..."
    cat > deployment/06-minio.yaml << EOF
# MinIO Configuration
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
          value: "minioadmin"
        - name: MINIO_ROOT_PASSWORD
          value: "minioadmin123"
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
  storageClassName: $STORAGE_CLASS
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
EOF

    print_success "All deployment files created!"
}

# Create management scripts
create_management_scripts() {
    print_header "Creating Management Scripts"

    # setup-environment.sh
    print_info "Creating environment setup script..."
    cat > scripts/setup-environment.sh << 'EOF'
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
EOF

    # deploy.sh
    print_info "Creating deployment script..."
    cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
# Deployment Script for Kubernetes Data Platform

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}

    print_status "Waiting for $deployment to be ready..."
    if kubectl wait --for=condition=available deployment/$deployment -n $namespace --timeout=${timeout}s 2>/dev/null; then
        print_success "$deployment is ready!"
        return 0
    else
        print_error "$deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

wait_for_statefulset() {
    local statefulset=$1
    local namespace=$2
    local timeout=${3:-300}

    print_status "Waiting for $statefulset to be ready..."
    if kubectl wait --for=condition=ready pod -l app=$statefulset -n $namespace --timeout=${timeout}s 2>/dev/null; then
        print_success "$statefulset is ready!"
        return 0
    else
        print_error "$statefulset failed to become ready within ${timeout}s"
        return 1
    fi
}

wait_for_job() {
    local job=$1
    local namespace=$2
    local timeout=${3:-300}

    print_status "Waiting for job $job to complete..."
    if kubectl wait --for=condition=complete job/$job -n $namespace --timeout=${timeout}s 2>/dev/null; then
        print_success "Job $job completed!"
        return 0
    else
        print_error "Job $job did not complete within ${timeout}s"
        return 1
    fi
}

echo "🚀 Deploying Kubernetes Data Platform"
echo "====================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not available. Please install kubectl first."
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_success "Connected to Kubernetes cluster"

# Deploy in order
print_status "Step 1: Deploying PostgreSQL..."
kubectl apply -f deployment/01-postgres-ha.yaml
wait_for_statefulset "postgres" "data-platform" 600
wait_for_job "postgres-init" "data-platform" 300

print_status "Step 2: Deploying Redis..."
kubectl apply -f deployment/02-redis.yaml
wait_for_deployment "redis-master" "data-platform" 300

print_status "Step 3: Deploying Monitoring..."
kubectl apply -f deployment/03-prometheus.yaml
kubectl apply -f deployment/04-grafana.yaml
wait_for_deployment "prometheus" "data-platform" 300
wait_for_deployment "grafana" "data-platform" 300

print_status "Step 4: Deploying Airflow..."
kubectl apply -f deployment/05-airflow.yaml
wait_for_job "airflow-db-init" "data-platform" 600
wait_for_deployment "airflow-webserver" "data-platform" 600
wait_for_deployment "airflow-scheduler" "data-platform" 300
wait_for_deployment "airflow-worker" "data-platform" 300
wait_for_deployment "airflow-flower" "data-platform" 300

print_status "Step 5: Deploying MinIO..."
kubectl apply -f deployment/06-minio.yaml
wait_for_deployment "minio" "data-platform" 300

print_success "🎉 Data Platform deployment completed!"
echo ""
print_status "Next steps:"
echo "  1. Run './scripts/check-health.sh' to verify all services"
echo "  2. Run './scripts/port-forward.sh' to access services"
echo ""
print_status "Services will be available at:"
echo "  📊 Grafana:    http://localhost:3000 (admin/admin123)"
echo "  ⚙️  Airflow:    http://localhost:8080 (admin/admin123)"
echo "  🌸 Flower:     http://localhost:5555 (Celery monitoring)"
echo "  💾 MinIO:      http://localhost:9001 (minioadmin/minioadmin123)"
echo "  🔍 Prometheus: http://localhost:9090"
EOF

    # check-health.sh
    print_info "Creating health check script..."
    cat > scripts/check-health.sh << 'EOF'
#!/bin/bash
# Health Check Script

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "🏥 Data Platform Health Check"
echo "============================"

# Check if we can connect to cluster
if ! kubectl cluster-info &>/dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check namespace
if kubectl get namespace data-platform &>/dev/null; then
    print_success "Namespace 'data-platform' exists"
else
    print_error "Namespace 'data-platform' not found"
    exit 1
fi

# Check pods
echo ""
print_info "Pod Status:"
kubectl get pods -n data-platform

# Count pod states
total_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | wc -l)
running_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Running" | wc -l)
pending_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Pending" | wc -l)
failed_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep -E "Error|CrashLoopBackOff|ImagePullBackOff" | wc -l)

echo ""
print_info "Pod Summary:"
echo "  Total: $total_pods"
echo "  Running: $running_pods"
if [ "$pending_pods" -gt 0 ]; then
    print_warning "Pending: $pending_pods"
fi
if [ "$failed_pods" -gt 0 ]; then
    print_error "Failed: $failed_pods"
fi

# Check services
echo ""
print_info "Services:"
kubectl get svc -n data-platform

# Overall status
echo ""
if [ "$running_pods" -gt 0 ] && [ "$failed_pods" -eq 0 ]; then
    print_success "Data Platform appears to be healthy!"
    echo ""
    print_info "To access services, run: ./scripts/port-forward.sh"
else
    print_warning "Data Platform has some issues that need attention"
fi
EOF

    # port-forward.sh
    print_info "Creating port-forward script..."
    cat > scripts/port-forward.sh << 'EOF'
#!/bin/bash
# Port Forward Script for Easy Access

echo "🌐 Starting port-forwards for Data Platform services..."
echo "======================================================="

# Function to start port-forward in background
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local namespace=${4:-data-platform}

    echo "Starting $service on localhost:$local_port"
    kubectl port-forward svc/$service $local_port:$remote_port -n $namespace &
    sleep 2
}

# Kill any existing port-forwards
echo "Stopping any existing port-forwards..."
pkill -f "kubectl port-forward" || true
sleep 2

# Start all port-forwards
start_port_forward "grafana" 3000 3000
start_port_forward "airflow-webserver" 8080 8080
start_port_forward "airflow-flower" 5555 5555
start_port_forward "minio-console" 9001 9001
start_port_forward "prometheus" 9090 9090

echo ""
echo "✅ Port-forwards started!"
echo ""
echo "Access your services at:"
echo "  🔍 Grafana (admin/admin123):     http://localhost:3000"
echo "  ⚙️  Airflow (admin/admin123):     http://localhost:8080"
echo "  🌸 Flower (Celery Monitor):      http://localhost:5555"
echo "  💾 MinIO (minioadmin/minioadmin123): http://localhost:9001"
echo "  📈 Prometheus:                   http://localhost:9090"
echo ""
echo "Press Ctrl+C to stop all port-forwards"

# Wait for Ctrl+C
trap 'echo "Stopping port-forwards..."; jobs -p | xargs -r kill; exit 0' INT
wait
EOF

    chmod +x scripts/*.sh
    print_success "Management scripts created and made executable"
}

# Create documentation
create_documentation() {
    print_header "Creating Documentation"

    cat > README.md << 'EOF'
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
EOF

    print_success "Documentation created"
}

# Main execution
main() {
    detect_k8s_env
    create_project_structure
    create_all_deployments
    create_management_scripts
    create_documentation

    print_header "🎉 Setup Complete!"

    print_success "Project created successfully at: $PROJECT_DIR"
    echo ""
    print_info "📁 Project structure:"
    echo "kubernetes-data-platform/"
    echo "├── deployment/          # Kubernetes YAML files"
    echo "├── scripts/            # Management scripts"
    echo "└── README.md           # Documentation"

    echo ""
    print_info "🚀 Next steps:"
    echo "  1. cd $PROJECT_DIR"
    echo "  2. ./scripts/setup-environment.sh"
    echo "  3. ./scripts/deploy.sh"
    echo "  4. ./scripts/check-health.sh"
    echo "  5. ./scripts/port-forward.sh"

    echo ""
    print_info "🔧 Environment detected: $K8S_TYPE"
    print_info "💾 Storage class configured: $STORAGE_CLASS"

    echo ""
    print_success "🎊 Your Kubernetes Data Platform is ready to deploy!"

    # Ask if user wants to change to project directory
    echo ""
    read -p "Change to project directory now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Run: cd $PROJECT_DIR"
        echo "Then: ./scripts/setup-environment.sh"
    fi
}

# Run main function
main "$@"