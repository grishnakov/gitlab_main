#!/bin/bash
set -e

NAMESPACE="gitlab"

echo "===== Creating/updating required secrets ====="

# Create init secrets for components that need them
echo "Creating init secrets for components..."
kubectl create secret generic init-sidekiq-secrets \
  --from-literal=placeholder=placeholder \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic init-toolbox-secrets \
  --from-literal=placeholder=placeholder \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic init-webservice-secrets \
  --from-literal=placeholder=placeholder \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Update registry storage configuration
echo "Updating registry storage configuration..."
cat > registry-storage.yaml << EOF
storage:
  filesystem:
    rootdirectory: /var/lib/registry
EOF

kubectl create secret generic gitlab-registry-storage \
  --from-file=storage=registry-storage.yaml \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Check if migrations job needs to be deleted to restart it
if kubectl get job -n $NAMESPACE gitlab-migrations-ed016e0 &>/dev/null; then
  echo "Deleting failed migrations job..."
  kubectl delete job -n $NAMESPACE gitlab-migrations-ed016e0
fi

echo "===== Upgrading GitLab Helm release ====="
helm upgrade gitlab gitlab/gitlab -f gitlab-repair-updated.yaml -n $NAMESPACE

echo "===== Monitoring pods ====="
echo "Run the following command to watch pod status:"
echo "kubectl get pods -n $NAMESPACE -w"

echo "===== Note: Port Forwarding ====="
echo "If you want to access GitLab locally for debugging, run:"
echo "kubectl port-forward -n $NAMESPACE svc/gitlab-webservice-default 8080:8080"
echo "Then access: http://localhost:8080"
