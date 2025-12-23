# Blog Deployment Guide

Complete guide to deploy your Hugo blog to Kubernetes and serve it at https://pedrotchang.dev

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup & First Release](#initial-setup--first-release)
3. [Kubernetes Configuration](#kubernetes-configuration)
4. [DNS Configuration](#dns-configuration)
5. [TLS/SSL Setup](#tlsssl-setup)
6. [Deployment](#deployment)
7. [Verification](#verification)
8. [Publishing Updates](#publishing-updates)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### 1. GitHub CLI Authentication
```bash
# Check if gh is installed
gh --version

# If not installed (Arch Linux)
sudo pacman -S github-cli

# Authenticate
gh auth login
```

### 2. GitHub Container Registry Access
Ensure your GitHub token has `write:packages` permission:
```bash
gh auth status
```

### 3. Kubernetes Cluster Access
```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Check if you have an ingress controller (e.g., nginx)
kubectl get pods -n ingress-nginx
```

### 4. Cert-Manager (for TLS)
```bash
# Check if cert-manager is installed
kubectl get pods -n cert-manager

# If not installed, install it
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
```

### 5. Domain Control
- You need access to DNS settings for `pedrotchang.dev`
- Get your cluster's external IP:
  ```bash
  kubectl get svc -n ingress-nginx
  # Look for EXTERNAL-IP of ingress-nginx-controller
  ```

---

## Initial Setup & First Release

### Step 1: Commit the New Files
```bash
cd /home/seyza/Repos/github.com/pedrotchang/blog

# Check what files were added
git status

# Add the deployment files
git add Dockerfile .dockerignore .github/workflows/publish.yaml publish

# Commit
git commit -m "build: add containerization and CI/CD workflow"

# Push to GitHub
git push origin main
```

### Step 2: Publish Your First Release
```bash
# Run the publish script
./publish

# When prompted:
# - Enter version: v1.0.0
# - Confirm: y
```

This will:
- Trigger GitHub Actions workflow
- Build your Hugo site inside Docker
- Push image to `ghcr.io/pedrotchang/blog:v1.0.0`
- Create a GitHub release

### Step 3: Monitor the Build
```bash
# Open the actions page
gh run list --workflow=publish.yaml

# Or watch in real-time
gh run watch

# Or open in browser
gh run view --web
```

Wait for the workflow to complete (usually 2-5 minutes).

### Step 4: Verify the Image
```bash
# Check that the image exists
gh api /user/packages/container/blog/versions

# Or try pulling it locally
docker pull ghcr.io/pedrotchang/blog:v1.0.0

# Test it locally (optional)
docker run -p 8080:80 ghcr.io/pedrotchang/blog:v1.0.0
# Visit http://localhost:8080
# Ctrl+C to stop
```

---

## Kubernetes Configuration

### Step 1: Create Namespace (Optional)
```bash
# Create a dedicated namespace
kubectl create namespace blog

# Or use default namespace
# (adjust namespace in manifests below accordingly)
```

### Step 2: Create Kubernetes Manifests

Navigate to your infrastructure repository (or create manifests in a new directory):

```bash
# Example: if you have an infra repo
cd ~/Repos/k8s-infra  # or wherever your k8s configs live

# Create blog directory
mkdir -p apps/blog
cd apps/blog
```

Create three files:

#### `deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog
  namespace: default  # Change to 'blog' if using dedicated namespace
  labels:
    app: blog
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: blog
  template:
    metadata:
      labels:
        app: blog
    spec:
      imagePullSecrets:
      - name: ghcr-secret  # We'll create this next
      containers:
      - name: blog
        image: ghcr.io/pedrotchang/blog:v1.0.0  # Update this with each release
        imagePullPolicy: Always
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
```

#### `service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: blog
  namespace: default
  labels:
    app: blog
spec:
  selector:
    app: blog
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
  type: ClusterIP
```

#### `ingress.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blog
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod  # Adjust if your issuer has a different name
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  labels:
    app: blog
spec:
  ingressClassName: nginx  # Or 'traefik' depending on your setup
  tls:
  - hosts:
    - pedrotchang.dev
    - www.pedrotchang.dev  # Optional
    secretName: blog-tls
  rules:
  - host: pedrotchang.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog
            port:
              number: 80
  - host: www.pedrotchang.dev  # Optional redirect
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog
            port:
              number: 80
```

### Step 3: Create Image Pull Secret

GitHub Container Registry requires authentication:

```bash
# Create a GitHub Personal Access Token (PAT) with 'read:packages' scope
# Go to: https://github.com/settings/tokens/new
# Select scopes: read:packages
# Generate token and copy it

# Create the secret
kubectl create secret docker-registry ghcr-secret \
  --namespace=default \
  --docker-server=ghcr.io \
  --docker-username=pedrotchang \
  --docker-password=YOUR_GITHUB_PAT_HERE \
  --docker-email=your-email@example.com

# Verify
kubectl get secret ghcr-secret -n default
```

**Alternative: Use GitHub Actions to create secret**

If you prefer, you can make the image public:
1. Go to https://github.com/users/pedrotchang/packages/container/blog/settings
2. Change visibility to "Public"
3. Remove `imagePullSecrets` from deployment.yaml

---

## DNS Configuration

### Step 1: Get Cluster External IP
```bash
# Get your ingress controller's external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Note the EXTERNAL-IP value (e.g., 203.0.113.45)
```

### Step 2: Configure DNS

Go to your DNS provider (e.g., Cloudflare, Google Domains, etc.):

**Add A Records:**
```
Type: A
Name: @
Value: <YOUR_CLUSTER_EXTERNAL_IP>
TTL: 300

Type: A
Name: www
Value: <YOUR_CLUSTER_EXTERNAL_IP>
TTL: 300
```

**Or CNAME (if using subdomain):**
```
Type: CNAME
Name: www
Value: pedrotchang.dev
TTL: 300
```

### Step 3: Verify DNS Propagation
```bash
# Check A record
dig pedrotchang.dev +short
dig www.pedrotchang.dev +short

# Or use nslookup
nslookup pedrotchang.dev
```

Wait for DNS to propagate (can take 5 minutes to 48 hours, usually ~10 minutes).

---

## TLS/SSL Setup

### Step 1: Create ClusterIssuer (If Not Already Present)

Check if you have a ClusterIssuer:
```bash
kubectl get clusterissuer
```

If you don't have `letsencrypt-prod`, create it:

```yaml
# Save as clusterissuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: your-email@example.com  # Change this
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply it:
```bash
kubectl apply -f clusterissuer.yaml
```

### Step 2: Verify Cert-Manager is Working
```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# All should be Running
```

---

## Deployment

### Step 1: Apply Kubernetes Manifests
```bash
# Navigate to where you saved the manifests
cd ~/Repos/k8s-infra/apps/blog  # or wherever

# Apply in order
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

### Step 2: Watch the Deployment
```bash
# Watch pods come up
kubectl get pods -n default -l app=blog -w

# Wait for STATUS: Running and READY: 1/1
# Press Ctrl+C when ready
```

### Step 3: Check Certificate Issuance
```bash
# Check certificate status
kubectl get certificate -n default

# Should show blog-tls with READY: True
# This may take 1-2 minutes

# If not ready, check the challenge
kubectl get challenge -n default

# Check cert-manager logs if issues
kubectl logs -n cert-manager deployment/cert-manager
```

---

## Verification

### Step 1: Check All Resources
```bash
# Check deployment
kubectl get deployment blog -n default

# Check pods (should show 2/2)
kubectl get pods -n default -l app=blog

# Check service
kubectl get svc blog -n default

# Check ingress
kubectl get ingress blog -n default

# Check certificate
kubectl get certificate blog-tls -n default
```

### Step 2: Test the Endpoint
```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://pedrotchang.dev

# Test HTTPS
curl -I https://pedrotchang.dev

# Should return HTTP/2 200
```

### Step 3: Visit in Browser
Open https://pedrotchang.dev in your browser.

You should see:
- Your blog homepage
- Valid SSL certificate (green padlock)
- No security warnings

### Step 4: Check Logs
```bash
# View application logs
kubectl logs -n default -l app=blog --tail=50

# Follow logs in real-time
kubectl logs -n default -l app=blog -f
```

---

## Publishing Updates

### Workflow for Future Updates

1. **Make changes to your blog**
   ```bash
   cd /home/seyza/Repos/github.com/pedrotchang/blog

   # Edit content, config, etc.
   # Test locally with Hugo if desired:
   hugo server -D
   ```

2. **Commit and push changes**
   ```bash
   git add .
   git commit -m "content: add new blog post about XYZ"
   git push origin main
   ```

3. **Publish new release**
   ```bash
   ./publish
   # Enter new version (e.g., v1.1.0)
   # Confirm
   ```

4. **Update Kubernetes deployment**
   ```bash
   # Option 1: Update with kubectl
   kubectl set image deployment/blog \
     blog=ghcr.io/pedrotchang/blog:v1.1.0 \
     -n default

   # Option 2: Edit deployment.yaml and apply
   # Change image tag to v1.1.0
   kubectl apply -f deployment.yaml
   ```

5. **Watch rollout**
   ```bash
   kubectl rollout status deployment/blog -n default

   # If something goes wrong, rollback
   kubectl rollout undo deployment/blog -n default
   ```

### Automated Updates (Optional)

You can automate step 4 with ArgoCD, FluxCD, or a simple script:

```bash
#!/bin/bash
# update-blog.sh

VERSION=$1

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./update-blog.sh v1.1.0"
  exit 1
fi

kubectl set image deployment/blog \
  blog=ghcr.io/pedrotchang/blog:${VERSION} \
  -n default

kubectl rollout status deployment/blog -n default

echo "Blog updated to ${VERSION}"
```

---

## Troubleshooting

### Pods Not Starting

**Check pod status:**
```bash
kubectl get pods -n default -l app=blog
kubectl describe pod <pod-name> -n default
```

**Common issues:**
- `ImagePullBackOff`: Check image pull secret, verify image exists
- `CrashLoopBackOff`: Check container logs: `kubectl logs <pod-name> -n default`

### Certificate Not Issuing

**Check certificate:**
```bash
kubectl describe certificate blog-tls -n default
```

**Check challenges:**
```bash
kubectl get challenge -n default
kubectl describe challenge <challenge-name> -n default
```

**Common issues:**
- DNS not propagated: Wait longer, verify with `dig`
- Port 80 not accessible: Check firewall, ingress controller
- Wrong email in ClusterIssuer: Update and reapply

**Force certificate renewal:**
```bash
kubectl delete certificate blog-tls -n default
kubectl delete secret blog-tls -n default
kubectl apply -f ingress.yaml
```

### Site Not Accessible

**Check ingress:**
```bash
kubectl describe ingress blog -n default
```

**Check ingress controller logs:**
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

**Test from within cluster:**
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
# Inside the pod:
curl http://blog.default.svc.cluster.local
```

### Image Pull Errors

**Public image (easiest):**
1. Go to https://github.com/users/pedrotchang/packages/container/blog/settings
2. Change Package Visibility to "Public"
3. Remove `imagePullSecrets` from deployment

**Private image:**
```bash
# Verify secret exists
kubectl get secret ghcr-secret -n default

# Test pulling manually
docker login ghcr.io -u pedrotchang
docker pull ghcr.io/pedrotchang/blog:v1.0.0
```

### DNS Issues

**Verify DNS:**
```bash
# Should return your cluster IP
dig pedrotchang.dev +short

# Check from different DNS
dig @8.8.8.8 pedrotchang.dev +short
```

**Clear local DNS cache:**
```bash
# Linux
sudo systemd-resolve --flush-caches

# Or edit /etc/hosts temporarily for testing
echo "<CLUSTER_IP> pedrotchang.dev" | sudo tee -a /etc/hosts
```

### Rollback a Deployment

```bash
# View rollout history
kubectl rollout history deployment/blog -n default

# Rollback to previous version
kubectl rollout undo deployment/blog -n default

# Rollback to specific revision
kubectl rollout undo deployment/blog --to-revision=2 -n default
```

---

## Monitoring & Maintenance

### View Logs
```bash
# All pods
kubectl logs -n default -l app=blog --tail=100

# Specific pod
kubectl logs -n default <pod-name>

# Follow logs
kubectl logs -n default -l app=blog -f
```

### Resource Usage
```bash
# Get resource usage
kubectl top pods -n default -l app=blog
kubectl top nodes
```

### Scale Deployment
```bash
# Scale up
kubectl scale deployment/blog --replicas=3 -n default

# Scale down
kubectl scale deployment/blog --replicas=1 -n default
```

### Update Resource Limits
Edit `deployment.yaml` and adjust:
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

Then apply:
```bash
kubectl apply -f deployment.yaml
```

---

## Quick Reference

### Common Commands
```bash
# Publish new version
./publish

# Update deployment
kubectl set image deployment/blog blog=ghcr.io/pedrotchang/blog:v1.2.0 -n default

# Check status
kubectl get all -n default -l app=blog

# View logs
kubectl logs -n default -l app=blog --tail=50 -f

# Restart deployment
kubectl rollout restart deployment/blog -n default

# Delete everything
kubectl delete -f deployment.yaml -f service.yaml -f ingress.yaml
```

### URLs
- **Blog:** https://pedrotchang.dev
- **GitHub Repo:** https://github.com/pedrotchang/blog
- **GitHub Actions:** https://github.com/pedrotchang/blog/actions
- **Container Registry:** https://github.com/pedrotchang?tab=packages

---

## Next Steps After Initial Deployment

1. **Set up monitoring** (optional)
   - Add Prometheus metrics
   - Set up Grafana dashboards
   - Configure alerts

2. **Automate deployments** (optional)
   - Set up ArgoCD or FluxCD
   - Auto-deploy on git push
   - Implement GitOps workflow

3. **Add CI/CD enhancements** (optional)
   - Run Hugo build tests
   - Check for broken links
   - Automated lighthouse scores

4. **Performance optimization** (optional)
   - Add CDN (Cloudflare)
   - Enable HTTP/3
   - Optimize image sizes

5. **Backup strategy** (optional)
   - Backup git repo (already on GitHub)
   - Export blog posts regularly
   - Document restore procedure

---

Good luck with your deployment! 🚀
