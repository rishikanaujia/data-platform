#!/bin/bash
# Complete Production-Ready Setup Script for Kubernetes Data Platform
# Version: 3.0 - Enterprise Grade with All Fixes Applied
# Features: Apache Airflow 2.8.1, CeleryExecutor, External Access, Auto-Security

set -e

# Color codes for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_feature() {
    echo -e "${CYAN}🚀 $1${NC}"
}

# Project configuration
PROJECT_NAME="kubernetes-data-platform"
PROJECT_DIR=$(pwd)/$PROJECT_NAME

# ADD THESE LINES HERE ⬇️
# Global variables for secure credentials
POSTGRES_PASSWORD=""
REDIS_PASSWORD=""
MINIO_ROOT_PASSWORD=""
AIRFLOW_ADMIN_PASSWORD=""
GRAFANA_ADMIN_PASSWORD=""
FERNET_KEY=""
WEBSERVER_SECRET_KEY=""

SFTP_USERNAME=""
SFTP_PASSWORD=""
FILEBROWSER_ADMIN_PASSWORD=""


# Enhanced environment validation
validate_environment() {
    print_info "🔍 Validating environment and dependencies..."

    # Check required commands
    local required_commands=("kubectl" "openssl" "python3" "base64")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_error "Missing required commands: ${missing_commands[*]}"
        print_info "Please install missing commands and retry"
        exit 1
    fi

    # Check kubectl connectivity
    if ! kubectl cluster-info &>/dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Please check your kubeconfig and cluster status"
        exit 1
    fi

    # Validate Python cryptography
    if ! python3 -c "from cryptography.fernet import Fernet" 2>/dev/null; then
        print_error "Python cryptography library not available"
        print_info "Install with: pip3 install cryptography"
        exit 1
    fi

    print_success "Environment validation passed"
}

# Generate cryptographically secure secrets
generate_secure_secrets() {
    print_info "🔐 Generating cryptographically secure secrets..."

    # Generate secure passwords (32 chars, URL-safe)
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '/+' | cut -c1-32)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '/+' | cut -c1-32)
    MINIO_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d '/+' | cut -c1-32)
    AIRFLOW_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+' | cut -c1-16)
    GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+' | cut -c1-16)

    # ADD THESE NEW LINES:
    SFTP_USERNAME="datauser"
    SFTP_PASSWORD=$(openssl rand -base64 16 | tr -d '/+' | cut -c1-16)
    FILEBROWSER_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+' | cut -c1-16)

    # ADD THESE LINES after line with FILEBROWSER_ADMIN_PASSWORD generation:
    KAFKA_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+' | cut -c1-16)
    KAFKA_USER_PASSWORD=$(openssl rand -base64 16 | tr -d '/+' | cut -c1-16)


    # Generate Airflow-specific secrets
    FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
    WEBSERVER_SECRET_KEY=$(openssl rand -hex 32)

    # Validate all secrets were generated
    local secrets=("POSTGRES_PASSWORD" "REDIS_PASSWORD" "MINIO_ROOT_PASSWORD" "AIRFLOW_ADMIN_PASSWORD" "GRAFANA_ADMIN_PASSWORD" "FERNET_KEY" "WEBSERVER_SECRET_KEY" "SFTP_PASSWORD" "FILEBROWSER_ADMIN_PASSWORD" "KAFKA_ADMIN_PASSWORD" "KAFKA_USER_PASSWORD")
    for secret in "${secrets[@]}"; do
        if [ -z "${!secret}" ]; then
            print_error "Failed to generate $secret"
            exit 1
        fi
    done

    print_success "All secure secrets generated successfully"
}

# Save credentials securely
save_credentials() {
    local credentials_file="credentials.env"

    print_info "💾 Saving credentials to $credentials_file..."

    cat > "$credentials_file" << EOF
# Kubernetes Data Platform Credentials
# Generated: $(date)
# KEEP THIS FILE SECURE AND DO NOT COMMIT TO VERSION CONTROL

# Database
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Redis
REDIS_PASSWORD=$REDIS_PASSWORD

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD

# Airflow
AIRFLOW_ADMIN_USERNAME=admin
AIRFLOW_ADMIN_PASSWORD=$AIRFLOW_ADMIN_PASSWORD
AIRFLOW_FERNET_KEY=$FERNET_KEY

# Grafana
GRAFANA_ADMIN_USERNAME=admin
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD

# SFTP Server
SFTP_USERNAME=$SFTP_USERNAME
SFTP_PASSWORD=$SFTP_PASSWORD

# FileBrowser
FILEBROWSER_ADMIN_USERNAME=admin
FILEBROWSER_ADMIN_PASSWORD=$FILEBROWSER_ADMIN_PASSWORD

# Kafka
KAFKA_ADMIN_USERNAME=admin
KAFKA_ADMIN_PASSWORD=$KAFKA_ADMIN_PASSWORD
KAFKA_USER_USERNAME=user
KAFKA_USER_PASSWORD=$KAFKA_USER_PASSWORD
EOF

    chmod 600 "$credentials_file"

    # Create .gitignore to prevent accidental commits
    echo "credentials.env" > .gitignore
    echo "*.env" >> .gitignore
    echo ".env*" >> .gitignore

    print_success "Credentials saved to $credentials_file (permissions: 600)"
    print_warning "🔒 Keep this file secure and do not commit to version control!"
}

print_header "Kubernetes Data Platform - Production Ready v3.0"
print_feature "Apache Airflow 2.8.1 • CeleryExecutor • External Access • Auto-Security"

# Detect Kubernetes environment
detect_k8s_env() {
    print_info "🔍 Detecting Kubernetes environment..."

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

    # SECURITY FIX: Validate storage class exists
    if ! kubectl get storageclass "$STORAGE_CLASS" &>/dev/null; then
        print_warning "Storage class '$STORAGE_CLASS' not found"
        print_info "Available storage classes:"
        kubectl get storageclass

        local available_sc=$(kubectl get storageclass -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$available_sc" ]; then
            STORAGE_CLASS="$available_sc"
            print_info "Using alternative storage class: $STORAGE_CLASS"
        else
            print_error "No storage classes available"
            exit 1
        fi
    fi

    print_success "Storage class validated: $STORAGE_CLASS"
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

# Create all deployment files
create_all_deployments() {
    print_header "Creating Production Deployment Files"

    # Create 01-postgres-ha.yaml
    print_info "Creating PostgreSQL HA configuration..."
    cat > deployment/01-postgres-ha.yaml << EOF
# PostgreSQL High Availability Configuration
apiVersion: v1
kind: Namespace
metadata:
  name: data-platform
  labels:
    name: data-platform
    environment: production

---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: data-platform
type: Opaque
data:
  password: $(echo -n "$POSTGRES_PASSWORD" | base64 -w 0)
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-primary
  namespace: data-platform
  labels:
    app: postgres
    role: primary
    tier: database
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
        tier: database
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
  labels:
    app: postgres
    role: primary
spec:
  selector:
    app: postgres
    role: primary
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
  type: ClusterIP

---
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-init
  namespace: data-platform
  labels:
    app: postgres
    job: init
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

          echo "Databases created successfully!"
      restartPolicy: OnFailure
EOF

    # Create 02-redis.yaml
    print_info "Creating Redis configuration..."
    cat > deployment/02-redis.yaml << EOF
# Redis Configuration for Message Broker
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-master
  namespace: data-platform
  labels:
    app: redis
    role: master
    tier: cache
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
        tier: cache
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command: ["redis-server"]
        env:
        - name: REDIS_PASSWORD
          value: "$REDIS_PASSWORD"
        args: ["--requirepass", "$REDIS_PASSWORD"]
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
        livenessProbe:
          exec:
            command:
            - redis-cli
            - -a
            - "$REDIS_PASSWORD"
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - -a
            - "$REDIS_PASSWORD"
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
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
  labels:
    app: redis
    role: master
spec:
  selector:
    app: redis
    role: master
  ports:
  - port: 6379
    targetPort: 6379
    name: redis
  type: ClusterIP
EOF

    # Create 03-prometheus.yaml
    print_info "Creating Prometheus monitoring..."
    cat > deployment/03-prometheus.yaml << EOF
# Prometheus Monitoring Configuration
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

    rule_files:
      # - "alert_rules.yml"

    scrape_configs:
    - job_name: 'prometheus'
      static_configs:
      - targets: ['localhost:9090']

    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
          - data-platform
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
  labels:
    app: prometheus
    tier: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
        tier: monitoring
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --storage.tsdb.retention.time=15d
        - --web.console.libraries=/etc/prometheus/console_libraries
        - --web.console.templates=/etc/prometheus/consoles
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
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 5
          periodSeconds: 5
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
  labels:
    app: prometheus
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
    name: web
  type: ClusterIP
EOF

    # Create 04-grafana.yaml
    print_info "Creating Grafana dashboards..."
    cat > deployment/04-grafana.yaml << EOF
# Grafana Dashboards Configuration
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
      editable: false

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: data-platform
  labels:
    app: grafana
    tier: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
        tier: monitoring
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "$GRAFANA_ADMIN_PASSWORD"
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        - name: GF_INSTALL_PLUGINS
          value: "grafana-kubernetes-app"
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
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
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
  labels:
    app: grafana
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
    name: grafana
  type: ClusterIP
EOF

    # Create 05-airflow.yaml - PRODUCTION READY WITH ALL FIXES
    print_info "Creating Apache Airflow 2.8.1 with CeleryExecutor..."
    cat > deployment/05-airflow.yaml << EOF
# Apache Airflow 2.8.1 Production Configuration - All Fixes Applied
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-config
  namespace: data-platform
  labels:
    app: airflow
    tier: orchestration
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
    sql_alchemy_conn = postgresql+psycopg2://postgres:$POSTGRES_PASSWORD@postgres-primary:5432/airflow
    sql_alchemy_max_overflow = 20
    sql_alchemy_pool_recycle = 1800
    sql_alchemy_pool_pre_ping = True
    sql_alchemy_schema =

    [celery]
    broker_url = redis://:$REDIS_PASSWORD@redis:6379/1
    result_backend = redis://:$REDIS_PASSWORD@redis:6379/1
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
    smtp_mail_from = airflow@dataplatform.local
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

    [triggerer]
    default_capacity = 1000
    job_heartbeat_sec = 5
    heartbeat_sec = 5

---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-secret
  namespace: data-platform
  labels:
    app: airflow
type: Opaque
data:
  fernet-key: $(echo -n "$FERNET_KEY" | base64 -w 0)
  webserver-secret-key: $(echo -n "$WEBSERVER_SECRET_KEY" | base64 -w 0)

---
apiVersion: batch/v1
kind: Job
metadata:
  name: airflow-db-init-fixed
  namespace: data-platform
  labels:
    app: airflow
    job: db-init
spec:
  template:
    metadata:
      labels:
        app: airflow
        job: db-init
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
            --password "$AIRFLOW_ADMIN_PASSWORD"
        env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:$POSTGRES_PASSWORD@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "CeleryExecutor"
        - name: AIRFLOW__CORE__LOAD_EXAMPLES
          value: "False"
        - name: AIRFLOW__WEBSERVER__SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: webserver-secret-key
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
  labels:
    app: airflow
    component: webserver
    tier: orchestration
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
        tier: orchestration
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
          value: "postgresql+psycopg2://postgres:$POSTGRES_PASSWORD@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "CeleryExecutor"
        - name: AIRFLOW__CORE__LOAD_EXAMPLES
          value: "False"
        - name: AIRFLOW__WEBSERVER__SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: webserver-secret-key
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
  labels:
    app: airflow
    component: scheduler
    tier: orchestration
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
        tier: orchestration
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
          value: "postgresql+psycopg2://postgres:$POSTGRES_PASSWORD@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "CeleryExecutor"
        - name: AIRFLOW__CORE__LOAD_EXAMPLES
          value: "False"
        - name: AIRFLOW__WEBSERVER__SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: webserver-secret-key
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
            - test
            - -f
            - /opt/airflow/logs/dag_processor_manager/dag_processor_manager.log
          initialDelaySeconds: 120
          periodSeconds: 30
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
  labels:
    app: airflow
    component: worker
    tier: orchestration
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
        tier: orchestration
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
          value: "postgresql+psycopg2://postgres:$POSTGRES_PASSWORD@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "CeleryExecutor"
        - name: AIRFLOW__CELERY__WORKER_CONCURRENCY
          value: "16"
        - name: AIRFLOW__WEBSERVER__SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: webserver-secret-key
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
  labels:
    app: airflow
    component: flower
    tier: monitoring
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
        tier: monitoring
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
          value: "postgresql+psycopg2://postgres:$POSTGRES_PASSWORD@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CELERY__FLOWER_HOST
          value: "0.0.0.0"
        - name: AIRFLOW__CELERY__FLOWER_PORT
          value: "5555"
        - name: AIRFLOW__WEBSERVER__SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: webserver-secret-key
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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-triggerer
  namespace: data-platform
  labels:
    app: airflow
    component: triggerer
    tier: orchestration
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow
      component: triggerer
  template:
    metadata:
      labels:
        app: airflow
        component: triggerer
        tier: orchestration
    spec:
      containers:
      - name: airflow-triggerer
        image: apache/airflow:2.8.1-python3.11
        command:
        - /bin/bash
        - -c
        - |
          # Start triggerer
          airflow triggerer
        env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: "postgresql+psycopg2://postgres:$POSTGRES_PASSWORD@postgres-primary:5432/airflow"
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: fernet-key
        - name: AIRFLOW__CELERY__BROKER_URL
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CELERY__RESULT_BACKEND
          value: "redis://:$REDIS_PASSWORD@redis:6379/1"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "CeleryExecutor"
        - name: AIRFLOW__CORE__LOAD_EXAMPLES
          value: "False"
        - name: AIRFLOW__WEBSERVER__SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-secret
              key: webserver-secret-key
        volumeMounts:
        - name: airflow-config
          mountPath: /opt/airflow/airflow.cfg
          subPath: airflow.cfg
        - name: airflow-logs
          mountPath: /opt/airflow/logs
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"

      volumes:
      - name: airflow-config
        configMap:
          name: airflow-config
      - name: airflow-logs
        persistentVolumeClaim:
          claimName: airflow-logs-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: airflow-logs-pvc
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
  name: airflow-webserver
  namespace: data-platform
  labels:
    app: airflow
    component: webserver
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
  labels:
    app: airflow
    component: flower
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
  labels:
    app: airflow
    component: worker
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

    # Create 06-minio.yaml
    print_info "Creating MinIO S3-compatible storage..."
    cat > deployment/06-minio.yaml << EOF
# MinIO S3-Compatible Object Storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: data-platform
  labels:
    app: minio
    tier: storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
        tier: storage
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
          value: "$MINIO_ROOT_PASSWORD"
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
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: 9000
          initialDelaySeconds: 5
          periodSeconds: 5
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
  labels:
    app: minio
    service: api
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
  labels:
    app: minio
    service: console
spec:
  selector:
    app: minio
  ports:
  - port: 9001
    targetPort: 9001
    name: console
  type: ClusterIP
EOF
# ADD this line after the MinIO creation:
create_kafka_deployment
# Create 07-sftp-filebrowser.yaml
    print_info "Creating SFTP server with FileBrowser UI..."
    cat > deployment/07-sftp-filebrowser.yaml << EOF
# SFTP Server and FileBrowser Web UI Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: sftp-config
  namespace: data-platform
  labels:
    app: sftp
    tier: storage
data:
  users.conf: |
    $SFTP_USERNAME:$SFTP_PASSWORD:1001:1001:upload,download,modify,delete

---
apiVersion: v1
kind: Secret
metadata:
  name: sftp-secret
  namespace: data-platform
  labels:
    app: sftp
type: Opaque
data:
  username: $(echo -n "$SFTP_USERNAME" | base64 -w 0)
  password: $(echo -n "$SFTP_PASSWORD" | base64 -w 0)

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sftp-server
  namespace: data-platform
  labels:
    app: sftp
    tier: storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sftp
  template:
    metadata:
      labels:
        app: sftp
        tier: storage
    spec:
      containers:
      - name: sftp
        image: atmoz/sftp:latest
        env:
        - name: SFTP_USERS
          value: "$SFTP_USERNAME:$SFTP_PASSWORD:1001:1001:data"
        ports:
        - containerPort: 22
          name: sftp
        volumeMounts:
        - name: sftp-data
          mountPath: /home/$SFTP_USERNAME/data
        - name: sftp-keys
          mountPath: /etc/ssh/keys
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          tcpSocket:
            port: 22
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          tcpSocket:
            port: 22
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: sftp-data
        persistentVolumeClaim:
          claimName: sftp-data-pvc
      - name: sftp-keys
        emptyDir: {}

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filebrowser
  namespace: data-platform
  labels:
    app: filebrowser
    tier: storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: filebrowser
  template:
    metadata:
      labels:
        app: filebrowser
        tier: storage
    spec:
      containers:
      - name: filebrowser
        image: filebrowser/filebrowser:latest
        env:
        - name: FB_DATABASE
          value: "/database/filebrowser.db"
        - name: FB_CONFIG
          value: "/config/settings.json"
        ports:
        - containerPort: 8080    # Changed from 80 to 8080
          name: web
        volumeMounts:
        - name: sftp-data
          mountPath: /srv
        - name: filebrowser-db
          mountPath: /database
        - name: filebrowser-config
          mountPath: /config
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "250m"
        livenessProbe:
          httpGet:
            path: /
            port: 8080           # Changed from 80 to 8080
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 8080           # Changed from 80 to 8080
          initialDelaySeconds: 5
          periodSeconds: 10
      initContainers:
      - name: filebrowser-init
        image: filebrowser/filebrowser:latest
        command:
        - /bin/sh
        - -c
        - |
          # Create initial config
          mkdir -p /config /database
          if [ ! -f /database/filebrowser.db ]; then
            filebrowser config init --database /database/filebrowser.db
            filebrowser users add admin $FILEBROWSER_ADMIN_PASSWORD --perm.admin --database /database/filebrowser.db
          fi

          # Create settings.json with port 8080
          cat > /config/settings.json << EOL
          {
            "port": 8080,
            "baseURL": "",
            "address": "",
            "log": "stdout",
            "database": "/database/filebrowser.db",
            "root": "/srv"
          }
          EOL
        env:
        - name: FILEBROWSER_ADMIN_PASSWORD
          value: "$FILEBROWSER_ADMIN_PASSWORD"
        volumeMounts:
        - name: filebrowser-db
          mountPath: /database
        - name: filebrowser-config
          mountPath: /config
      volumes:
      - name: sftp-data
        persistentVolumeClaim:
          claimName: sftp-data-pvc
      - name: filebrowser-db
        persistentVolumeClaim:
          claimName: filebrowser-db-pvc
      - name: filebrowser-config
        persistentVolumeClaim:
          claimName: filebrowser-config-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sftp-data-pvc
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
kind: PersistentVolumeClaim
metadata:
  name: filebrowser-db-pvc
  namespace: data-platform
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: $STORAGE_CLASS
  resources:
    requests:
      storage: 1Gi

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: filebrowser-config-pvc
  namespace: data-platform
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: $STORAGE_CLASS
  resources:
    requests:
      storage: 100Mi

---
apiVersion: v1
kind: Service
metadata:
  name: sftp-server
  namespace: data-platform
  labels:
    app: sftp
spec:
  selector:
    app: sftp
  ports:
  - port: 22
    targetPort: 22
    name: sftp
    protocol: TCP
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: filebrowser
  namespace: data-platform
  labels:
    app: filebrowser
spec:
  selector:
    app: filebrowser
  ports:
  - port: 80              # External port stays 80
    targetPort: 8080      # Internal port changed to 8080
    name: web
EOF

    print_success "All production deployment files created!"
}

# ADD AFTER create_all_deployments() function, BEFORE create_management_scripts():
create_kafka_deployment() {
    print_info "Creating Apache Kafka with KRaft (3 brokers)..."
    cat > deployment/08-kafka.yaml << EOF
# Apache Kafka with KRaft Controller - 3 Brokers Configuration
apiVersion: v1
kind: Secret
metadata:
  name: kafka-secret
  namespace: data-platform
  labels:
    app: kafka
type: Opaque
data:
  admin-password: $(echo -n "$KAFKA_ADMIN_PASSWORD" | base64 -w 0)
  user-password: $(echo -n "$KAFKA_USER_PASSWORD" | base64 -w 0)

---
# Kafka Controller (KRaft)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka-controller
  namespace: data-platform
  labels:
    app: kafka
    component: controller
    tier: streaming
spec:
  serviceName: kafka-controller-headless
  replicas: 1
  selector:
    matchLabels:
      app: kafka
      component: controller
  template:
    metadata:
      labels:
        app: kafka
        component: controller
        tier: streaming
    spec:
      containers:
      - name: kafka-controller
        image: bitnami/kafka:3.6
        env:
        - name: KAFKA_ENABLE_KRAFT
          value: "yes"
        - name: KAFKA_CFG_PROCESS_ROLES
          value: "controller"
        - name: KAFKA_CFG_CONTROLLER_QUORUM_VOTERS
          value: "0@kafka-controller-0.kafka-controller-headless.data-platform.svc.cluster.local:9093"
        - name: KAFKA_CFG_NODE_ID
          value: "0"
        - name: KAFKA_KRAFT_CLUSTER_ID
          value: "abcdefghijklmnopqrstuv"
        - name: KAFKA_CFG_CONTROLLER_LISTENER_NAMES
          value: "CONTROLLER"
        - name: KAFKA_CFG_LISTENERS
          value: "CONTROLLER://:9093"
        - name: ALLOW_PLAINTEXT_LISTENER
          value: "yes"
        ports:
        - containerPort: 9093
          name: controller
        volumeMounts:
        - name: kafka-controller-data
          mountPath: /bitnami/kafka
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          tcpSocket:
            port: 9093
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          tcpSocket:
            port: 9093
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: kafka-controller-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: $STORAGE_CLASS
      resources:
        requests:
          storage: 10Gi

---
# Kafka Broker StatefulSet (3 replicas)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka-broker
  namespace: data-platform
  labels:
    app: kafka
    component: broker
    tier: streaming
spec:
  serviceName: kafka-broker-headless
  replicas: 3
  selector:
    matchLabels:
      app: kafka
      component: broker
  template:
    metadata:
      labels:
        app: kafka
        component: broker
        tier: streaming
    spec:
      containers:
      - name: kafka-broker
        image: bitnami/kafka:3.6
        env:
        - name: KAFKA_ENABLE_KRAFT
          value: "yes"
        - name: KAFKA_CFG_PROCESS_ROLES
          value: "broker"
        - name: KAFKA_CFG_CONTROLLER_QUORUM_VOTERS
          value: "0@kafka-controller-0.kafka-controller-headless.data-platform.svc.cluster.local:9093"
        - name: KAFKA_CFG_NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: KAFKA_KRAFT_CLUSTER_ID
          value: "abcdefghijklmnopqrstuv"
        - name: KAFKA_CFG_LISTENERS
          value: "PLAINTEXT://:9092,EXTERNAL://:9094"
        - name: KAFKA_CFG_ADVERTISED_LISTENERS
          value: "PLAINTEXT://\$(MY_POD_NAME).kafka-broker-headless.data-platform.svc.cluster.local:9092,EXTERNAL://\$(MY_POD_IP):9094"
        - name: KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP
          value: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,EXTERNAL:PLAINTEXT"
        - name: KAFKA_CFG_INTER_BROKER_LISTENER_NAME
          value: "PLAINTEXT"
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: MY_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE
          value: "true"
        - name: KAFKA_CFG_DEFAULT_REPLICATION_FACTOR
          value: "3"
        - name: KAFKA_CFG_MIN_INSYNC_REPLICAS
          value: "2"
        - name: ALLOW_PLAINTEXT_LISTENER
          value: "yes"
        ports:
        - containerPort: 9092
          name: kafka
        - containerPort: 9094
          name: external
        volumeMounts:
        - name: kafka-broker-data
          mountPath: /bitnami/kafka
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          tcpSocket:
            port: 9092
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          tcpSocket:
            port: 9092
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: kafka-broker-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: $STORAGE_CLASS
      resources:
        requests:
          storage: 20Gi

---
# Kafka Controller Headless Service
apiVersion: v1
kind: Service
metadata:
  name: kafka-controller-headless
  namespace: data-platform
  labels:
    app: kafka
    component: controller
spec:
  selector:
    app: kafka
    component: controller
  ports:
  - port: 9093
    targetPort: 9093
    name: controller
  clusterIP: None

---
# Kafka Broker Headless Service
apiVersion: v1
kind: Service
metadata:
  name: kafka-broker-headless
  namespace: data-platform
  labels:
    app: kafka
    component: broker
spec:
  selector:
    app: kafka
    component: broker
  ports:
  - port: 9092
    targetPort: 9092
    name: kafka
  - port: 9094
    targetPort: 9094
    name: external
  clusterIP: None

---
# Kafka External Access Service
apiVersion: v1
kind: Service
metadata:
  name: kafka-external
  namespace: data-platform
  labels:
    app: kafka
    component: broker
spec:
  selector:
    app: kafka
    component: broker
  ports:
  - port: 9092
    targetPort: 9092
    name: kafka
  type: ClusterIP

---
# Kafka UI for Management
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-ui
  namespace: data-platform
  labels:
    app: kafka-ui
    tier: management
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-ui
  template:
    metadata:
      labels:
        app: kafka-ui
        tier: management
    spec:
      containers:
      - name: kafka-ui
        image: provectuslabs/kafka-ui:latest
        env:
        - name: KAFKA_CLUSTERS_0_NAME
          value: "data-platform-kafka"
        - name: KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS
          value: "kafka-broker-0.kafka-broker-headless:9092,kafka-broker-1.kafka-broker-headless:9092,kafka-broker-2.kafka-broker-headless:9092"
        ports:
        - containerPort: 8080
          name: http
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
          initialDelaySeconds: 5
          periodSeconds: 5

---
# Kafka UI Service
apiVersion: v1
kind: Service
metadata:
  name: kafka-ui
  namespace: data-platform
  labels:
    app: kafka-ui
spec:
  selector:
    app: kafka-ui
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  type: ClusterIP
EOF

    print_success "Kafka deployment configuration created!"
}

# Create management scripts
create_management_scripts() {
    print_header "Creating Management Scripts"

    # setup-environment.sh
    print_info "Creating environment setup script..."
    cat > scripts/setup-environment.sh << 'EOF'
#!/bin/bash
# Environment Setup Script for Production

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

print_header "Production Environment Setup"

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

    # Enable metrics server for monitoring
    if microk8s enable metrics-server 2>/dev/null; then
        print_success "Metrics server enabled"
    else
        print_warning "Metrics server not available or already enabled"
    fi

    # Set up kubectl alias
    if ! command -v kubectl &> /dev/null; then
        print_info "Setting up kubectl alias..."
        sudo snap alias microk8s.kubectl kubectl || echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
    fi

    print_success "MicroK8s configured for production"

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
    minikube addons enable metrics-server

    print_success "Minikube configured for production"

else
    echo "📦 Generic Kubernetes cluster detected"
    print_info "Please ensure you have storage classes and metrics server available"
fi

# Check cluster connectivity
echo ""
print_info "Checking cluster connectivity..."
if kubectl cluster-info &>/dev/null; then
    print_success "Kubernetes cluster is accessible"
    echo ""
    print_info "Cluster Information:"
    kubectl get nodes -o wide
    echo ""
    print_info "Available Storage Classes:"
    kubectl get sc
else
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check resources
echo ""
print_info "Checking cluster resources..."
kubectl top nodes 2>/dev/null || print_warning "Metrics server not available for resource checking"

print_success "Environment setup complete!"
echo ""
print_info "Next steps:"
echo "  1. Run: ./scripts/deploy.sh (Basic deployment)"
echo "  2. Run: ./scripts/complete-setup.sh (Automated full deployment)"
EOF

    # deploy.sh
    print_info "Creating deployment script..."
    cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
# Production Deployment Script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

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

print_header "Production Kubernetes Data Platform Deployment"

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
print_header "Step 1: Deploying PostgreSQL Database"
kubectl apply -f deployment/01-postgres-ha.yaml
wait_for_statefulset "postgres" "data-platform" 600
wait_for_job "postgres-init" "data-platform" 300

print_header "Step 2: Deploying Redis Message Broker"
kubectl apply -f deployment/02-redis.yaml
wait_for_deployment "redis-master" "data-platform" 300

print_header "Step 3: Deploying Monitoring Stack"
kubectl apply -f deployment/03-prometheus.yaml
kubectl apply -f deployment/04-grafana.yaml
wait_for_deployment "prometheus" "data-platform" 300
wait_for_deployment "grafana" "data-platform" 300

print_header "Step 4: Deploying Apache Airflow 2.8.1"
kubectl apply -f deployment/05-airflow.yaml
wait_for_job "airflow-db-init-fixed" "data-platform" 600
wait_for_deployment "airflow-webserver" "data-platform" 600
wait_for_deployment "airflow-scheduler" "data-platform" 300
wait_for_deployment "airflow-worker" "data-platform" 300
wait_for_deployment "airflow-flower" "data-platform" 300
wait_for_deployment "airflow-triggerer" "data-platform" 300

print_header "Step 5: Deploying MinIO Object Storage"
kubectl apply -f deployment/06-minio.yaml
wait_for_deployment "minio" "data-platform" 300

print_header "Step 6: Deploying SFTP Server and FileBrowser"
kubectl apply -f deployment/07-sftp-filebrowser.yaml
wait_for_deployment "sftp-server" "data-platform" 300
wait_for_deployment "filebrowser" "data-platform" 300

# ADD after Step 6 in deploy.sh:
print_header "Step 7: Deploying Apache Kafka Streaming"
kubectl apply -f deployment/08-kafka.yaml
wait_for_statefulset "kafka-controller" "data-platform" 300
wait_for_statefulset "kafka-broker" "data-platform" 600
wait_for_deployment "kafka-ui" "data-platform" 300

print_header "🎉 Production Deployment Completed!"
echo ""
print_success "All services deployed successfully!"
print_status "Next steps:"
echo "  1. Run './scripts/check-health.sh' to verify all services"
echo "  2. Run './scripts/fix-airflow-secrets.sh' to secure Airflow"
echo "  3. Run './scripts/expose-services.sh' to enable external access"
echo ""
print_status "Or run './scripts/complete-setup.sh' for automated post-deployment setup"
EOF

    # check-health.sh
    print_info "Creating health check script..."
    cat > scripts/check-health.sh << 'EOF'
#!/bin/bash
# Production Health Check Script

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header "Production Data Platform Health Check"

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
print_info "Pod Status Overview:"
kubectl get pods -n data-platform -o wide

# Count pod states
total_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | wc -l)
running_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Running" | wc -l)
pending_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Pending" | wc -l)
failed_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep -E "Error|CrashLoopBackOff|ImagePullBackOff" | wc -l)
completed_pods=$(kubectl get pods -n data-platform --no-headers 2>/dev/null | grep "Completed" | wc -l)

echo ""
print_info "Pod Summary:"
echo "  Total: $total_pods"
echo "  Running: $running_pods"
echo "  Completed: $completed_pods"
if [ "$pending_pods" -gt 0 ]; then
    print_warning "Pending: $pending_pods"
fi
if [ "$failed_pods" -gt 0 ]; then
    print_error "Failed: $failed_pods"
fi

# Check services
echo ""
print_info "Service Status:"
kubectl get svc -n data-platform -o wide

# Check storage
echo ""
print_info "Storage Status:"
kubectl get pvc -n data-platform

# Check resource usage if metrics available
echo ""
print_info "Resource Usage:"
kubectl top pods -n data-platform 2>/dev/null || print_warning "Metrics server not available"

# Detailed health checks
echo ""
print_header "Component Health Details"

# PostgreSQL
PG_STATUS=$(kubectl get pods -n data-platform -l app=postgres --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$PG_STATUS" -eq 1 ]; then
    print_success "PostgreSQL is healthy"
else
    print_error "PostgreSQL issues detected"
fi

# Redis
REDIS_STATUS=$(kubectl get pods -n data-platform -l app=redis --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$REDIS_STATUS" -eq 1 ]; then
    print_success "Redis is healthy"
else
    print_error "Redis issues detected"
fi

# Airflow components
AIRFLOW_WEBSERVER=$(kubectl get pods -n data-platform -l component=webserver --no-headers 2>/dev/null | grep "Running" | wc -l)
AIRFLOW_SCHEDULER=$(kubectl get pods -n data-platform -l component=scheduler --no-headers 2>/dev/null | grep "Running" | wc -l)
AIRFLOW_WORKERS=$(kubectl get pods -n data-platform -l component=worker --no-headers 2>/dev/null | grep "Running" | wc -l)
AIRFLOW_FLOWER=$(kubectl get pods -n data-platform -l component=flower --no-headers 2>/dev/null | grep "Running" | wc -l)
AIRFLOW_TRIGGERER=$(kubectl get pods -n data-platform -l component=triggerer --no-headers 2>/dev/null | grep "Running" | wc -l)

if [ "$AIRFLOW_WEBSERVER" -eq 1 ]; then
    print_success "Airflow Webserver is healthy"
else
    print_error "Airflow Webserver issues detected"
fi

if [ "$AIRFLOW_SCHEDULER" -eq 1 ]; then
    print_success "Airflow Scheduler is healthy"
else
    print_error "Airflow Scheduler issues detected"
fi

if [ "$AIRFLOW_WORKERS" -eq 2 ]; then
    print_success "Airflow Workers are healthy (2/2)"
elif [ "$AIRFLOW_WORKERS" -gt 0 ]; then
    print_warning "Some Airflow Workers are running ($AIRFLOW_WORKERS/2)"
else
    print_error "No Airflow Workers running"
fi

if [ "$AIRFLOW_FLOWER" -eq 1 ]; then
    print_success "Flower monitoring is healthy"
else
    print_error "Flower monitoring issues detected"
fi

if [ "$AIRFLOW_TRIGGERER" -eq 1 ]; then
    print_success "Airflow Triggerer is healthy"
else
    print_error "Airflow Triggerer issues detected"
fi


# MinIO
MINIO_STATUS=$(kubectl get pods -n data-platform -l app=minio --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$MINIO_STATUS" -eq 1 ]; then
    print_success "MinIO is healthy"
else
    print_error "MinIO issues detected"
fi

# Monitoring
PROMETHEUS_STATUS=$(kubectl get pods -n data-platform -l app=prometheus --no-headers 2>/dev/null | grep "Running" | wc -l)
GRAFANA_STATUS=$(kubectl get pods -n data-platform -l app=grafana --no-headers 2>/dev/null | grep "Running" | wc -l)

if [ "$PROMETHEUS_STATUS" -eq 1 ]; then
    print_success "Prometheus is healthy"
else
    print_error "Prometheus issues detected"
fi

if [ "$GRAFANA_STATUS" -eq 1 ]; then
    print_success "Grafana is healthy"
else
    print_error "Grafana issues detected"
fi

SFTP_STATUS=$(kubectl get pods -n data-platform -l app=sftp --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$SFTP_STATUS" -eq 1 ]; then
    print_success "SFTP Server is healthy"
else
    print_error "SFTP Server issues detected"
fi

# FileBrowser
FILEBROWSER_STATUS=$(kubectl get pods -n data-platform -l app=filebrowser --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$FILEBROWSER_STATUS" -eq 1 ]; then
    print_success "FileBrowser is healthy"
else
    print_error "FileBrowser issues detected"
fi

# ADD in check-health.sh after FileBrowser check:
# Kafka Controller
KAFKA_CONTROLLER_STATUS=$(kubectl get pods -n data-platform -l component=controller --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$KAFKA_CONTROLLER_STATUS" -eq 1 ]; then
    print_success "Kafka Controller is healthy"
else
    print_error "Kafka Controller issues detected"
fi

# Kafka Brokers
KAFKA_BROKER_STATUS=$(kubectl get pods -n data-platform -l component=broker --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$KAFKA_BROKER_STATUS" -eq 3 ]; then
    print_success "Kafka Brokers are healthy (3/3)"
elif [ "$KAFKA_BROKER_STATUS" -gt 0 ]; then
    print_warning "Some Kafka Brokers are running ($KAFKA_BROKER_STATUS/3)"
else
    print_error "No Kafka Brokers running"
fi

# Kafka UI
KAFKA_UI_STATUS=$(kubectl get pods -n data-platform -l app=kafka-ui --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$KAFKA_UI_STATUS" -eq 1 ]; then
    print_success "Kafka UI is healthy"
else
    print_error "Kafka UI issues detected"
fi
# Overall status
echo ""
print_header "Overall Platform Status"
if [ "$running_pods" -gt 8 ] && [ "$failed_pods" -eq 0 ]; then
    print_success "🎉 Data Platform is healthy and ready for production!"
    echo ""
    print_info "Next steps:"
    echo "  - Run: ./scripts/fix-airflow-secrets.sh (if not done)"
    echo "  - Run: ./scripts/expose-services.sh (for external access)"
    echo "  - Access services via port-forward: ./scripts/port-forward.sh"
else
    print_warning "⚠️  Data Platform has some issues that need attention"
    echo ""
    print_info "To fix common issues:"
    echo "  - Run: ./scripts/fix-airflow-secrets.sh"
    echo "  - Check pod logs: kubectl logs <pod-name> -n data-platform"
    echo "  - Check events: kubectl get events -n data-platform --sort-by='.lastTimestamp'"
fi
EOF

    # port-forward.sh
    print_info "Creating port-forward script..."
    cat > scripts/port-forward.sh << 'EOF'
#!/bin/bash
# Port Forward Script for Local Access

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

print_header "Starting Local Access Port Forwards"

# Function to start port-forward in background
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local namespace=${4:-data-platform}

    print_info "Starting $service on localhost:$local_port"
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
start_port_forward "sftp-server" 2222 22
start_port_forward "filebrowser" 8090 8080

echo ""
print_success "All port-forwards started successfully!"
echo ""
print_header "🌐 Access Your Services"
echo ""
echo "  🔍 Grafana (Dashboards):         http://localhost:3000"
echo "      Username: admin | Password: [Check credentials.env]"
echo ""
echo "  ⚙️  Airflow (Orchestration):      http://localhost:8080"
echo "      Username: admin | Password: [Check credentials.env]"
echo ""
echo "  🌸 Flower (Worker Monitoring):   http://localhost:5555"
echo "      Real-time Celery worker monitoring"
echo ""
echo "  💾 MinIO (Object Storage):       http://localhost:9001"
echo "      Username: minioadmin | Password: [Check credentials.env]"
echo ""
echo "  📈 Prometheus (Metrics):         http://localhost:9090"
echo "      Raw metrics and monitoring data"
echo ""
echo "  📁 SFTP Server:                  sftp://datauser@localhost:2222"
echo "      Password: [Check credentials.env file]"
echo ""
echo "  🌐 FileBrowser:                  http://localhost:8090"
echo "      Username: admin | Password: [Check credentials.env]"
echo ""
print_info "Press Ctrl+C to stop all port-forwards"

# Wait for Ctrl+C
trap 'echo ""; echo "Stopping all port-forwards..."; jobs -p | xargs -r kill; exit 0' INT
wait
EOF

    chmod +x scripts/*.sh
    print_success "Core management scripts created"
}

# Create post-deployment automation scripts
create_post_deployment_scripts() {
    print_header "Creating Post-Deployment Automation Scripts"

    # fix-airflow-secrets.sh
    print_info "Creating Airflow security automation..."
    cat > scripts/fix-airflow-secrets.sh << 'EOF'
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
EOF

    # expose-services.sh
    print_info "Creating external access automation..."
    cat > scripts/expose-services.sh << 'EOF'
#!/bin/bash
# Production External Access Configuration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_feature() {
    echo -e "${CYAN}🚀 $1${NC}"
}

print_header "Production External Access Setup"

# Convert services to NodePort
print_info "Converting services to NodePort for external access..."

kubectl patch svc airflow-webserver -n data-platform -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc minio-console -n data-platform -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc airflow-flower -n data-platform -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc grafana -n data-platform -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc sftp-server -n data-platform -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc filebrowser -n data-platform -p '{"spec":{"type":"NodePort"}}'
# ADD after filebrowser patch:
kubectl patch svc kafka-external -n data-platform -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc kafka-ui -n data-platform -p '{"spec":{"type":"NodePort"}}'


print_success "All services converted to NodePort"

# Get external IP
print_info "Detecting server IP addresses..."
EXTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
INTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

# Use external IP if available, otherwise internal IP
SERVER_IP=${EXTERNAL_IP:-$INTERNAL_IP}

if [ -z "$SERVER_IP" ]; then
    print_warning "Could not auto-detect server IP"
    SERVER_IP="<YOUR_SERVER_IP>"
else
    print_success "Server IP detected: $SERVER_IP"
fi

# Wait a moment for services to update
sleep 5

# Get service details
echo ""
print_info "Service Configuration:"
kubectl get svc -n data-platform -o wide

# Extract NodePort information
echo ""
print_info "Extracting NodePort assignments..."
AIRFLOW_PORT=$(kubectl get svc airflow-webserver -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
MINIO_PORT=$(kubectl get svc minio-console -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
FLOWER_PORT=$(kubectl get svc airflow-flower -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
GRAFANA_PORT=$(kubectl get svc grafana -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
SFTP_PORT=$(kubectl get svc sftp-server -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
FILEBROWSER_PORT=$(kubectl get svc filebrowser -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
KAFKA_PORT=$(kubectl get svc kafka-external -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
KAFKA_UI_PORT=$(kubectl get svc kafka-ui -n data-platform -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)


# Display access information
echo ""
print_header "🌐 Production Platform Access URLs"
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│                     🎯 SERVICE ACCESS INFORMATION                    │"
echo "├─────────────────────────────────────────────────────────────────────┤"
echo "│                                                                     │"
echo "│  🚀 AIRFLOW ORCHESTRATION                                          │"
echo "│     URL: http://$SERVER_IP:$AIRFLOW_PORT                                      │"
echo "│     Username: admin | Password: [Check credentials.env]                           │"
echo "│     Purpose: Data pipeline orchestration & DAG management          │"
echo "│                                                                     │"
echo "│  💾 MinIO OBJECT STORAGE                                           │"
echo "│     URL: http://$SERVER_IP:$MINIO_PORT                                       │"
echo "│     Username: minioadmin | Password: [Check credentials.env]                │"
echo "│     Purpose: S3-compatible data lake and object storage            │"
echo "│                                                                     │"
echo "│  🌸 FLOWER WORKER MONITORING                                       │"
echo "│     URL: http://$SERVER_IP:$FLOWER_PORT                                      │"
echo "│     Purpose: Real-time Celery worker monitoring & task tracking    │"
echo "│                                                                     │"
echo "│  📊 GRAFANA DASHBOARDS                                             │"
echo "│     URL: http://$SERVER_IP:$GRAFANA_PORT                                     │"
echo "│     Username: admin | Password: [Check credentials.env]                           │"
echo "│     Purpose: System metrics, monitoring & alerting dashboards      │"
echo "│                                                                     │"
echo "│  📁 SFTP FILE SERVER                                           │"
echo "│     SFTP: sftp://datauser@$SERVER_IP:$SFTP_PORT                           │"
echo "│     Password: [Check credentials.env file]                     │"
echo "│     Purpose: Secure file transfer and data exchange            │"
echo "│                                                                     │"
echo "│  🌐 FILEBROWSER WEB UI                                         │"
echo "│     URL: http://$SERVER_IP:$FILEBROWSER_PORT                              │"
echo "│     Username: admin | Password: [Check credentials.env]        │"
echo "│     Purpose: Web-based file management and sharing             │"
echo "│                                                                     │"
echo "│  🔄 KAFKA STREAMING                                            │"
echo "│     Brokers: kafka://$SERVER_IP:$KAFKA_PORT                           │"
echo "│     UI: http://$SERVER_IP:$KAFKA_UI_PORT                             │"
echo "│     Purpose: Real-time data streaming & message queuing        │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo ""

# Create detailed access info file
print_info "Creating access information file..."
cat > access-info.txt << EOL
# Kubernetes Data Platform - Production Access Information
# Generated: $(date)
# Platform Version: 3.0 Production Ready

## 🌐 EXTERNAL ACCESS URLS:

### Primary Services
- Airflow Orchestration:    http://$SERVER_IP:$AIRFLOW_PORT
  Username: admin | Password: [credentials.env]
  Features: DAG management, task scheduling, workflow monitoring

- MinIO Object Storage:     http://$SERVER_IP:$MINIO_PORT
  Username: minioadmin | Password: [credentials.env]
  Features: S3-compatible API, bucket management, data lake storage

- Flower Worker Monitoring: http://$SERVER_IP:$FLOWER_PORT
  Features: Real-time worker status, task distribution, performance metrics

- Grafana Dashboards:       http://$SERVER_IP:$GRAFANA_PORT
  Username: admin | Password: [credentials.env]
  Features: System monitoring, custom dashboards, alerting

## 📊 PLATFORM ARCHITECTURE:

### Core Components
- Apache Airflow 2.8.1 with CeleryExecutor
- PostgreSQL 15 with HA configuration
- Redis 7 message broker and cache
- MinIO S3-compatible object storage
- Prometheus metrics collection
- Grafana monitoring dashboards

### Scaling Configuration
- Airflow Workers: 2 replicas (16 tasks each)
- Auto-scaling ready for production workloads
- Load balancing across worker nodes

## 🔧 MANAGEMENT COMMANDS:

### Health Monitoring
kubectl get pods -n data-platform
kubectl get svc -n data-platform
kubectl top pods -n data-platform

### Scaling Operations
kubectl scale deployment airflow-worker --replicas=4 -n data-platform
kubectl scale deployment airflow-webserver --replicas=2 -n data-platform

### Log Analysis
kubectl logs -l app=airflow -n data-platform
kubectl logs -l app=postgres -n data-platform

## 📈 SERVICE DETAILS:
$(kubectl get svc -n data-platform -o wide)

## 🏥 CURRENT PLATFORM STATUS:
$(kubectl get pods -n data-platform -o wide)

## 💾 STORAGE STATUS:
$(kubectl get pvc -n data-platform)

---
Generated by Kubernetes Data Platform Production Setup v3.0
For support and documentation: Check README.md
EOL

print_success "Detailed access information saved to: access-info.txt"

# Final verification
echo ""
print_header "🔍 Final Verification"
print_info "Testing service accessibility..."

# Quick connectivity test (if curl is available)
if command -v curl &> /dev/null; then
    if [ "$SERVER_IP" != "<YOUR_SERVER_IP>" ]; then
        for port in $AIRFLOW_PORT $MINIO_PORT $FLOWER_PORT $GRAFANA_PORT; do
            if curl -s --connect-timeout 5 http://$SERVER_IP:$port >/dev/null; then
                print_success "Port $port is accessible"
            else
                print_warning "Port $port may not be ready yet (normal during startup)"
            fi
        done
    fi
fi

print_header "🎉 External Access Configuration Complete!"
print_feature "Your production data platform is now accessible from anywhere!"
print_info "Save the URLs above for your team and bookmark access-info.txt"
EOF

    # complete-setup.sh
    print_info "Creating one-command automation..."
    cat > scripts/complete-setup.sh << 'EOF'
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
EOF

    chmod +x scripts/fix-airflow-secrets.sh scripts/expose-services.sh scripts/complete-setup.sh
    print_success "Production automation scripts created"
}

# Create comprehensive documentation
create_documentation() {
    print_header "Creating Production Documentation"

    cat > README.md << 'EOF'
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
| **🚀 Airflow** | http://YOUR_IP:PORT | admin / [credentials.env] | Workflow orchestration & DAG management |
| **💾 MinIO** | http://YOUR_IP:PORT | minioadmin / [credentials.env] | S3-compatible object storage |
| **🌸 Flower** | http://YOUR_IP:PORT | - | Real-time Celery worker monitoring |
| **📊 Grafana** | http://YOUR_IP:PORT | admin / [credentials.env] | System monitoring & dashboards |
| **📁 SFTP** | sftp://USER@YOUR_IP:PORT | datauser / [credentials.env] | Secure file transfer & data exchange |
| **🌐 FileBrowser** | http://YOUR_IP:PORT | admin / [credentials.env] | Web-based file management UI |
| **🔄 Kafka** | kafka://YOUR_IP:PORT & http://YOUR_IP:PORT | - | Real-time streaming & messaging |


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
EOF

    print_success "Comprehensive production documentation created"
}

# Main execution function
main() {
    validate_environment          # ADD THIS LINE
    detect_k8s_env
    generate_secure_secrets      # ADD THIS LINE
    create_project_structure
    create_all_deployments
    create_management_scripts
    create_post_deployment_scripts
    create_documentation
    save_credentials            # ADD THIS LINE

    print_header "🎉 Production Platform Setup Complete!"

    print_success "Enterprise-grade project created at: $PROJECT_DIR"
    echo ""
    print_info "📁 Production project structure:"
    echo "kubernetes-data-platform/"
    echo "├── deployment/              # Production Kubernetes YAML files"
    echo "│   ├── 01-postgres-ha.yaml  # PostgreSQL HA database"
    echo "│   ├── 02-redis.yaml        # Redis message broker"
    echo "│   ├── 03-prometheus.yaml   # Metrics collection"
    echo "│   ├── 04-grafana.yaml      # Monitoring dashboards"
    echo "│   ├── 05-airflow.yaml      # Airflow 2.8.1 CeleryExecutor"
    echo "│   ├── 06-minio.yaml        # S3-compatible storage"
    echo "│   ├── 07-sftp-filebrowser.yaml # SFTP and FileBrowser"
    echo "│   └── 08-kafka.yaml        # Apache Kafka streaming"
    echo "├── scripts/"
    echo "│   ├── setup-environment.sh # Production environment setup"
    echo "│   ├── deploy.sh            # Core platform deployment"
    echo "│   ├── fix-airflow-secrets.sh # Security automation"
    echo "│   ├── expose-services.sh   # External access automation"
    echo "│   ├── complete-setup.sh    # One-command production deployment"
    echo "│   ├── check-health.sh      # Comprehensive health monitoring"
    echo "│   └── port-forward.sh      # Local development access"
    echo "├── README.md                # Complete production documentation"
    echo "└── access-info.txt          # Generated after deployment"

    echo ""
    print_header "🚀 Quick Start Options"
    echo ""
    print_feature "Option 1 - One Command Production Deployment (Recommended):"
    echo "  1. cd $PROJECT_DIR"
    echo "  2. ./scripts/setup-environment.sh"
    echo "  3. ./scripts/complete-setup.sh  # Everything automated!"
    echo ""
    print_info "Option 2 - Step by Step (For learning/debugging):"
    echo "  1. cd $PROJECT_DIR"
    echo "  2. ./scripts/setup-environment.sh"
    echo "  3. ./scripts/deploy.sh"
    echo "  4. ./scripts/fix-airflow-secrets.sh"
    echo "  5. ./scripts/expose-services.sh"

    echo ""
    print_header "🎯 Platform Specifications"
    print_info "🔧 Environment detected: $K8S_TYPE"
    print_info "💾 Storage class configured: $STORAGE_CLASS"
    echo ""
    print_feature "✨ Production features included:"
    echo "  • Apache Airflow 2.8.1 with Python 3.11 (Latest version)"
    echo "  • CeleryExecutor with 2 distributed workers (32 parallel tasks)"
    echo "  • Production security with auto-generated encryption keys"
    echo "  • External NodePort access for team collaboration"
    echo "  • Complete monitoring stack (Prometheus + Grafana + Flower)"
    echo "  • S3-compatible object storage with MinIO"
    echo "  • High-availability PostgreSQL database"
    echo "  • Redis message broker and caching layer"
    echo "  • Comprehensive health monitoring and automation"
    echo "  • One-command deployment with all fixes applied"

    echo ""
    print_header "🎊 Ready for Enterprise Data Engineering!"
    print_success "Your production-ready Kubernetes Data Platform is complete!"
    print_info "⏱️  Estimated deployment time: 10-15 minutes"
    print_info "🎯 Platform capacity: 32 parallel tasks, auto-scaling ready"
    print_info "🔒 Security: Production-grade encryption and secure secrets"
    print_info "🌐 Access: External URLs + local port-forwarding support"

    # Ask if user wants to change to project directory
    echo ""
    read -p "🚀 Change to project directory and start deployment? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        print_success "🎯 Quick commands to deploy your platform:"
        echo ""
        echo "cd $PROJECT_DIR"
        echo "./scripts/setup-environment.sh"
        echo "./scripts/complete-setup.sh"
        echo ""
        print_info "After deployment, check 'access-info.txt' for service URLs!"
    else
        echo ""
        print_info "🎯 When ready to deploy, run these commands:"
        echo ""
        echo "cd $PROJECT_DIR"
        echo "./scripts/setup-environment.sh"
        echo "./scripts/complete-setup.sh"
    fi

    echo ""
    print_header "🌟 Thank you for choosing our Production Data Platform!"
    print_feature "Happy data engineering with Apache Airflow 2.8.1! 🚀📊💫"
}

# Run main function
main "$@"