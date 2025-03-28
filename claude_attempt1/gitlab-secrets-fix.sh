#!/bin/bash
set -e

NAMESPACE="gitlab"

echo "===== Creating additional required GitLab secrets ====="

# Generate random values for secrets
GITLAB_SHELL_TOKEN=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)
GITLAB_WORKHORSE_TOKEN=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)
GITLAB_RUNNER_TOKEN=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)
DB_KEY_BASE=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)
OTP_KEY_BASE=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)
SECRET_KEY_BASE=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)
SIDEKIQ_ENC_KEY=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)
GITLAB_PAGES_SECRET=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)

# Create GitLab shell secret
echo "Creating gitlab-shell-secret..."
kubectl create secret generic gitlab-shell-secret \
  --from-literal=secret=$GITLAB_SHELL_TOKEN \
  -n $NAMESPACE 2>/dev/null || echo "Secret gitlab-shell-secret already exists"

# Create GitLab workhorse secret
echo "Creating gitlab-workhorse-secret..."
kubectl create secret generic gitlab-workhorse-secret \
  --from-literal=shared-secret=$GITLAB_WORKHORSE_TOKEN \
  -n $NAMESPACE 2>/dev/null || echo "Secret gitlab-workhorse-secret already exists"

# Create GitLab runner secret
echo "Creating gitlab-runner-secret..."
kubectl create secret generic gitlab-runner-secret \
  --from-literal=runner-registration-token=$GITLAB_RUNNER_TOKEN \
  --from-literal=runner-token=$GITLAB_RUNNER_TOKEN \
  -n $NAMESPACE 2>/dev/null || echo "Secret gitlab-runner-secret already exists"

# Create Rails secrets
echo "Creating gitlab-rails-secret..."
kubectl create secret generic gitlab-rails-secret \
  --from-literal=db-key-base=$DB_KEY_BASE \
  --from-literal=otp-key-base=$OTP_KEY_BASE \
  --from-literal=secret-key-base=$SECRET_KEY_BASE \
  --from-literal=openid-connect-signing-key=placeholder \
  --from-literal=encrypted-setting-key-base=$SIDEKIQ_ENC_KEY \
  --from-literal=encrypted-setting-iv-base=$SIDEKIQ_ENC_KEY \
  -n $NAMESPACE 2>/dev/null || echo "Secret gitlab-rails-secret already exists"

# Create GitLab pages secret
echo "Creating gitlab-pages-secret..."
kubectl create secret generic gitlab-pages-secret \
  --from-literal=shared-secret=$GITLAB_PAGES_SECRET \
  -n $NAMESPACE 2>/dev/null || echo "Secret gitlab-pages-secret already exists"

# Create init secrets for sidekiq, toolbox, and webservice
echo "Creating init-*-secrets..."
kubectl create secret generic init-sidekiq-secrets \
  --from-literal=placeholder=placeholder \
  -n $NAMESPACE 2>/dev/null || echo "Secret init-sidekiq-secrets already exists"

kubectl create secret generic init-toolbox-secrets \
  --from-literal=placeholder=placeholder \
  -n $NAMESPACE 2>/dev/null || echo "Secret init-toolbox-secrets already exists"

kubectl create secret generic init-webservice-secrets \
  --from-literal=placeholder=placeholder \
  -n $NAMESPACE 2>/dev/null || echo "Secret init-webservice-secrets already exists"

echo "===== All additional secrets created successfully ====="
echo "You can now retry the GitLab installation with Helm"
