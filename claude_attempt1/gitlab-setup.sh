#!/bin/bash
set -e

# Set namespace
NAMESPACE="gitlab"

echo "===== Creating GitLab namespace ====="
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Namespace $NAMESPACE already exists"

echo "===== Creating local storage class ====="
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

echo "===== Creating required directories on the node ====="
sudo mkdir -p /opt/gitlab-data/{postgresql,redis,gitaly,prometheus}
sudo chmod -R 777 /opt/gitlab-data

echo "===== Creating persistent volumes ====="
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gitlab-postgresql-pv
spec:
  capacity:
    storage: 8Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /opt/gitlab-data/postgresql
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - opium
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gitlab-redis-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /opt/gitlab-data/redis
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - opium
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gitlab-gitaly-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /opt/gitlab-data/gitaly
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - opium
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gitlab-prometheus-pv
spec:
  capacity:
    storage: 8Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /opt/gitlab-data/prometheus
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - opium
EOF

echo "===== Creating persistent volume claims ====="
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 8Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitaly-data
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-data
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 8Gi
EOF

echo "===== Creating required secrets ====="

# Generate random passwords
ROOT_PASSWORD=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 32)
POSTGRES_PASSWORD=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 32)
GITALY_TOKEN=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)
REDIS_PASSWORD=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 32)

# Create initial root password secret
kubectl create secret generic gitlab-initial-root-password \
  --from-literal=password=$ROOT_PASSWORD \
  -n $NAMESPACE

# Create Gitaly token secret
kubectl create secret generic gitlab-gitaly-secret \
  --from-literal=token=$GITALY_TOKEN \
  -n $NAMESPACE

# Create PostgreSQL password secret
kubectl create secret generic gitlab-postgresql-password \
  --from-literal=postgres-password=$POSTGRES_PASSWORD \
  --from-literal=password=$POSTGRES_PASSWORD \
  -n $NAMESPACE

# Create Redis password secret
kubectl create secret generic gitlab-redis-password \
  --from-literal=redis-password=$REDIS_PASSWORD \
  -n $NAMESPACE

# Create registry storage secret
cat > registry-storage.yaml <<EOF
filesystem:
  rootdirectory: /var/lib/registry
EOF

kubectl create secret generic gitlab-registry-storage \
  --from-file=storage=registry-storage.yaml \
  -n $NAMESPACE

echo "===== Saving generated passwords to gitlab-passwords.txt ====="
cat > gitlab-passwords.txt <<EOF
ROOT_PASSWORD: $ROOT_PASSWORD
POSTGRES_PASSWORD: $POSTGRES_PASSWORD
GITALY_TOKEN: $GITALY_TOKEN
REDIS_PASSWORD: $REDIS_PASSWORD
EOF

chmod 600 gitlab-passwords.txt
echo "Passwords saved to gitlab-passwords.txt"

echo "===== Adding GitLab Helm repo ====="
helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo "===== Installation ready ====="
echo "To install GitLab, run the following command:"
echo "helm install gitlab gitlab/gitlab -f gitlab-values.yaml -n $NAMESPACE"
echo "Or use the fixed values.yaml file:"
echo "helm install gitlab gitlab/gitlab -f gitlab-values-fixed.yaml -n $NAMESPACE"

echo "===== Note: Root password ====="
echo "The initial root password is saved in gitlab-passwords.txt"
echo "You can also retrieve it later with:"
echo "kubectl get secret gitlab-initial-root-password -n $NAMESPACE -o jsonpath='{.data.password}' | base64 --decode && echo"
