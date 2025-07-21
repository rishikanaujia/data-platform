🚀 Alternative: Complete Clean Restart
For a completely fresh start:
bash# Delete the entire namespace (this removes everything)
kubectl delete namespace data-platform

# Wait a moment for cleanup
sleep 10

# Run the complete setup again
./scripts/complete-setup.sh

# 🔧 **Airflow Webserver Stuck - Let's Diagnose & Fix!**

## 🔍 **Quick Diagnosis:**

Let's check what's happening with the webserver:

```bash
# Check webserver pod status
kubectl get pods -n data-platform -l component=webserver

# Check webserver logs for errors
kubectl logs -l component=webserver -n data-platform --tail=20

# Check if there are any events/errors
kubectl describe pod -l component=webserver -n data-platform
```

## 🚨 **Most Likely Issues & Fixes:**

### **Issue 1: Secret Key Problem (Most Common)**
The webserver might still have the secret key issue. Let's fix it:

```bash
# Fix Airflow secrets immediately
./scripts/fix-airflow-secrets.sh
```

### **Issue 2: Resource Constraints**
Check if the pod has enough resources:

```bash
# Check resource usage
kubectl top pods -n data-platform 2>/dev/null || echo "Metrics not available"

# Check node resources
kubectl describe nodes
```



### **Issue 3: Pod Crash Loop**
If the pod is restarting:

```bash
# Check pod restart count
kubectl get pods -n data-platform -l component=webserver -o wide

# Get detailed error info
kubectl describe pod -l component=webserver -n data-platform
```

## ⚡ **Quick Fix Commands:**

```bash
# Method 1: Apply the security fix (most likely solution)
./scripts/fix-airflow-secrets.sh

# Method 2: Restart the webserver deployment
kubectl rollout restart deployment/airflow-webserver -n data-platform

# Method 3: Check and wait with more verbose output
kubectl get pods -n data-platform -w
```

## 🎯 **Emergency Bypass (Skip webserver wait):**

If you want to continue with the deployment while troubleshooting:

```bash
# Cancel the current script (Ctrl+C)
# Then run individual steps:

# Skip to MinIO deployment
kubectl apply -f deployment/06-minio.yaml

# Run security fixes
./scripts/fix-airflow-secrets.sh

# Set up external access
./scripts/expose-services.sh
```

## 📊 **Most Likely Solution:**

Based on our previous work, this is **probably the secret key issue**. Run this:

```bash
# This should fix the webserver startup issue
./scripts/fix-airflow-secrets.sh

# Then check the status
kubectl get pods -n data-platform -l component=webserver
```

## 💡 **What to Look For:**

**Good signs:**
- Pod status: `Running` 
- Ready: `1/1`
- Restarts: `0` or low number

**Bad signs:**
- Pod status: `CrashLoopBackOff`, `Error`, `Pending`
- Ready: `0/1`
- High restart count

**Run the diagnosis commands above and let me know what you see!** 🔍

The **security fix script** is most likely to resolve this issue immediately! 🚀


🚨 **I see the issue!** You're still stuck at the same place, which means there are two problems:

1. **Permission denied** - Script needs execute permissions
2. **Still using old deployment files** - The Airflow job is failing with the same password issue

Let's fix this immediately:

## 🔧 **Quick Fix Commands:**

```bash
# 1. Fix script permissions
chmod +x setup-data-platform.sh

# 2. Check if you're running the updated script
grep -n "POSTGRES_PASSWORD.*password123" setup-data-platform.sh
# This should return NOTHING if the script is properly updated

# 3. Stop the current failing deployment
kubectl delete job airflow-db-init-fixed -n data-platform
kubectl delete deployment airflow-webserver airflow-scheduler airflow-worker airflow-flower -n data-platform

# 4. Check what's in the current Airflow config
kubectl get configmap airflow-config -n data-platform -o yaml | grep -A5 -B5 "password123"
```


## 🚀 **Correct Deployment Process:**

```bash
# 1. Make script executable
chmod +x setup-data-platform.sh

# 2. Clean up everything
kubectl delete namespace data-platform

# 3. Run the updated script (this creates the project directory)
./setup-data-platform.sh

# 4. Move to the project directory with UPDATED files
cd kubernetes-data-platform

# 5. Check that credentials.env exists with secure passwords
cat credentials.env

# 6. NOW run the deployment
./scripts/complete-setup.sh
```
