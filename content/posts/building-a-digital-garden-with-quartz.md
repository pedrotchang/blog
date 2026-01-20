---
title: "Building a Digital Garden with Quartz and Kubernetes"
publish: true
type: blog
date: 2026-01-19
tags:
- Quartz
- Kubernetes
- Obsidian
- Digital Garden
- Tutorial
created: 2026-01-19
---

# Let's Build a Digital Garden Together

We're going to build a digital garden that publishes your Obsidian notes to the web. By the end, you'll have a working garden deployed to Kubernetes with automatic updates whenever you push changes.

Here's what we're building:

```
Obsidian Vault → Quartz (build) → Docker → Kubernetes → garden.yourdomain.dev
```

## What You Need

- An Obsidian vault with notes
- A Kubernetes cluster (I use a homelab, but any cluster works)
- GitHub account
- Cloudflare account (for the tunnel)
- Docker installed locally

## Step 1: Fork Quartz

Go to [quartz.jzhao.xyz](https://quartz.jzhao.xyz/) and click "Get Started". We're using Quartz v4.

```bash
git clone https://github.com/jackyzha0/quartz.git garden
cd garden
```

You should see a `quartz.config.ts` file. That's where the magic happens.

## Step 2: Configure Quartz

Open `quartz.config.ts`. We need to change a few things.

First, set your base URL:

```typescript
const config: QuartzConfig = {
  configuration: {
    pageTitle: "My Garden",
    baseUrl: "garden.yourdomain.dev",
```

Now the important part - filtering what gets published. Add this to your configuration:

```typescript
ignorePatterns: [
  ".obsidian",
  ".git",
  "templates",
  "private",
  "periodic-notes",
],
```

And here's the key: only publish notes that have `publish: true` in frontmatter.

```typescript
Plugin.FrontMatter(),
Plugin.ContentIndex({
  enableRSS: true,
}),
// Add a filter plugin
Plugin.FilterContent({
  filter: (ctx) => {
    const fm = ctx.frontmatter
    return fm?.publish === true
  }
}),
```

## Step 3: Symlink Your Vault

This is the trick that makes everything work. Instead of copying files, we symlink.

```bash
rm -rf content
ln -s /path/to/your/obsidian/vault content
```

Now when you run Quartz, it reads directly from your vault. Run a local build:

```bash
npx quartz build --serve
```

Open `http://localhost:8080`. You should see your notes that have `publish: true`.

> [!TIP]
> Add `publish: false` as a default in your Obsidian templates. Only flip it to `true` when you're ready to share.

## Step 4: Create the Dockerfile

We need a multi-stage build. First stage builds with Bun, second serves with nginx.

Create `Dockerfile`:

```dockerfile
# Build stage
FROM oven/bun:1 AS builder
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install
COPY . .
RUN npx quartz build

# Production stage
FROM nginx:1.27-alpine
COPY --from=builder /app/public /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Create `nginx.conf`:

```nginx
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    server {
        listen 80;
        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files $uri $uri/ $uri.html =404;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

Build and test locally:

```bash
docker build -t garden:local .
docker run -p 8080:80 garden:local
```

Open `http://localhost:8080`. Same garden, now in a container.

## Step 5: Set Up GitHub Actions

Create `.github/workflows/deploy.yaml`:

```yaml
name: Deploy Garden

on:
  push:
    branches: [main]
  repository_dispatch:
    types: [content-update]
  workflow_dispatch:

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Checkout content
        uses: actions/checkout@v4
        with:
          repository: yourusername/secondbrain
          path: content
          token: ${{ secrets.PAT_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
```

Notice the `repository_dispatch` trigger. That's how we auto-deploy when vault content changes.

## Step 6: Auto-Deploy on Vault Changes

In your vault repo, create `.github/workflows/notify-garden.yaml`:

```yaml
name: Notify Garden

on:
  push:
    branches: [main]
    paths:
      - "00-zettelkasten/**"
      - "index.md"

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger garden rebuild
        uses: peter-evans/repository-dispatch@v2
        with:
          token: ${{ secrets.PAT_TOKEN }}
          repository: yourusername/garden
          event-type: content-update
```

Now when you push to your vault, it triggers the garden to rebuild. Push a note, wait a minute, see it live.

## Step 7: Deploy to Kubernetes

Create the deployment. I put mine in `apps/base/garden/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: garden
  namespace: garden
spec:
  replicas: 2
  selector:
    matchLabels:
      app: garden
  template:
    metadata:
      labels:
        app: garden
    spec:
      containers:
        - name: garden
          image: ghcr.io/yourusername/garden:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
```

And `service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: garden
  namespace: garden
spec:
  selector:
    app: garden
  ports:
    - port: 80
      targetPort: 80
```

Apply it:

```bash
kubectl create namespace garden
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

You should see two pods running:

```bash
kubectl get pods -n garden
```

## Step 8: Expose with Cloudflare Tunnel

I use Cloudflare Tunnel instead of LoadBalancer. No open ports, no firewall rules.

Create the tunnel in Cloudflare Zero Trust dashboard. Get your tunnel ID and credentials.

Create `cloudflare.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: garden
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:latest
          args:
            - tunnel
            - --config
            - /etc/cloudflared/config.yaml
            - run
          volumeMounts:
            - name: config
              mountPath: /etc/cloudflared
            - name: creds
              mountPath: /etc/cloudflared/creds
      volumes:
        - name: config
          configMap:
            name: cloudflared-config
        - name: creds
          secret:
            secretName: cloudflared-creds
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: garden
data:
  config.yaml: |
    tunnel: YOUR_TUNNEL_ID
    credentials-file: /etc/cloudflared/creds/credentials.json
    ingress:
      - hostname: garden.yourdomain.dev
        service: http://garden.garden.svc.cluster.local:80
      - service: http_status:404
```

Apply and check the logs:

```bash
kubectl apply -f cloudflare.yaml
kubectl logs -n garden -l app=cloudflared
```

You should see "Connection registered". Open `https://garden.yourdomain.dev`.

## What You've Built

You now have:

- A digital garden that publishes Obsidian notes with `publish: true`
- Docker image built automatically on push
- Kubernetes deployment with 2 replicas
- Cloudflare Tunnel for secure public access
- Auto-rebuild when you push vault changes

The workflow: write in Obsidian → set `publish: true` → push → garden updates automatically.

## Next Steps

- Set up frontmatter templates for consistent metadata
- Add Plausible analytics to see what people read
- Customize the graph view to show connections between notes

---

202601191741
