---
title: "Self-Hosting Git with Forgejo: Building a Private GitHub Alternative on Kubernetes"
date: 2026-01-30
draft: true
tags:
  - forgejo
  - git
  - kubernetes
  - homelab
  - cicd
  - gitops
---

When GitHub went down for a few hours last year, I realized how dependent I had become on a single service for my entire development workflow. Code hosting, CI/CD, issue tracking - all eggs in one basket. That realization pushed me to explore self-hosted alternatives, and Forgejo emerged as the clear winner.

## Why Forgejo?

Forgejo is a community fork of Gitea, itself a fork of Gogs. It provides a lightweight, self-hosted Git service with a familiar interface. Think GitHub, but running on your own hardware. The project emphasizes community governance and has a strong commitment to remaining free software.

For my homelab, Forgejo offered several advantages: low resource requirements, PostgreSQL support (matching my existing CloudnativePG setup), and built-in Actions support for CI/CD workflows.

## The Deployment Journey

My Forgejo deployment went through several iterations before reaching its current stable state. The initial setup seemed straightforward - deploy the container, point it at a database, expose via ingress. Reality, as usual, had other plans.

### Configuration Persistence

The first challenge was configuration persistence. Forgejo's rootless container image expects configuration files in specific locations, and the defaults do not align with Kubernetes volume mounting conventions.

```yaml
env:
  - name: GITEA_CUSTOM
    value: /data/gitea
```

Setting `GITEA_CUSTOM` redirects all configuration to a path within my persistent volume. Without this, configuration changes would vanish on pod restart.

### The Setup Wizard Dance

Forgejo includes a first-run setup wizard, controlled by the `INSTALL_LOCK` setting. My initial approach was to disable it entirely:

```yaml
INSTALL_LOCK: "true"
```

This backfired. With the wizard disabled but no initial admin user configured, I locked myself out of the instance. The fix required temporarily enabling the wizard, completing setup, then re-disabling it:

```yaml
INSTALL_LOCK: "false"  # Temporary
DISABLE_REGISTRATION: "false"  # Allow initial signup
SECRET_KEY: "<generated-secret>"  # Required for security
```

After creating the admin account through the UI, I flipped both settings back and committed the change. GitOps means the configuration is now permanently documented.

### Network Policies: A Cilium Adventure

Running Forgejo in a locked-down Kubernetes environment required careful network policy configuration. The application needs to reach its PostgreSQL database, and the Cloudflare tunnel sidecar needs egress to Cloudflare's network.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
spec:
  egress:
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: forgejo
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
    - toFQDNs:
        - matchPattern: "*.cloudflareaccess.com"
      toPorts:
        - ports:
            - port: "7844"
              protocol: TCP
```

Port 7844 is Cloudflare's tunnel port. Missing this initially caused silent failures - the tunnel would establish but no traffic would flow.

## Forgejo Actions: Self-Hosted CI/CD

The real power of Forgejo comes from its Actions support, compatible with GitHub Actions workflows. I deployed a dedicated runner in a separate namespace:

```yaml
env:
  - name: FORGEJO_URL
    value: "http://forgejo.forgejo.svc.cluster.local:3000"
  - name: RUNNER_REGISTRATION_TOKEN
    valueFrom:
      secretKeyRef:
        name: forgejo-runner-token
        key: token
```

The runner registers itself with Forgejo on startup and polls for jobs. One gotcha: the registration command changed between versions. Earlier documentation suggested `create-runner-file`, but current versions use `register`:

```yaml
command:
  - forgejo-runner
  - register
  - --no-interactive
  - --instance
  - $(FORGEJO_URL)
  - --token
  - $(RUNNER_REGISTRATION_TOKEN)
```

### Cross-Namespace Communication

The runner lives in its own namespace (`forgejo-runner`) but needs to communicate with Forgejo in the `forgejo` namespace. This required bidirectional network policy rules:

**Forgejo side:** Allow ingress from runner namespace on port 3000
**Runner side:** Allow egress to forgejo namespace on port 3000

```yaml
# In forgejo namespace
ingress:
  - fromEndpoints:
      - matchLabels:
          io.kubernetes.pod.namespace: forgejo-runner
    toPorts:
      - ports:
          - port: "3000"
```

## External Access via Cloudflare Tunnel

Rather than exposing Forgejo through a traditional ingress with TLS termination, I use a Cloudflare tunnel. This eliminates the need for public IP addresses and provides Cloudflare's security features.

The tunnel runs as a sidecar deployment with its own configuration:

```yaml
ingress:
  - hostname: git.seyzahl.com
    service: http://forgejo.forgejo.svc.cluster.local:3000
  - service: http_status:404
```

I initially tried using both local access (via Gateway API HTTPRoute) and the Cloudflare tunnel. This created confusion with authentication and session handling. The final architecture uses Cloudflare tunnel exclusively - simpler and more secure.

## Storage Considerations

Git repositories can grow large, especially with binary assets. I mounted Forgejo's data directory on my TrueNAS NFS server:

```yaml
volumes:
  - name: forgejo-data
    persistentVolumeClaim:
      claimName: forgejo-data-nfs
```

NFS provides the flexibility to expand storage without Kubernetes PVC resize operations, and backups integrate with my existing TrueNAS snapshot schedule.

## Lessons Learned

Self-hosting Git is more complex than it appears. The application itself is straightforward, but the surrounding infrastructure - networking, storage, CI/CD runners - requires careful planning.

Key takeaways:
- **Document configuration persistence paths** for containerized applications
- **Network policies need both directions** for cross-namespace communication  
- **Cloudflare tunnels simplify external access** but require proper egress rules
- **Runner registration commands change** between versions - check current docs

Forgejo now hosts my private repositories, runs CI/CD workflows, and provides a backup location for critical projects. When GitHub has its next outage, I will barely notice.
