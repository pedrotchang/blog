---
title: "Running Claude Code CLI in Kubernetes: A Journey Through Init Containers, OAuth, and OOM Kills"
date: 2026-01-29
tags:
  - kubernetes
  - claude-code
  - homelab
  - containers
  - ai
---

When I decided to run Claude Code CLI as a backend service in my homelab Kubernetes cluster, I expected a weekend project. What I got was a masterclass in container initialization patterns, file permission nightmares, and the intricacies of OAuth token refresh in a headless environment. Here's what I learned.

## Why Containerize Claude Code?

My homelab runs n8n for workflow automation, and I wanted to expose Claude Code's capabilities as an API endpoint. The vision was simple: an HTTP service that accepts prompts, passes them to Claude Code CLI with my custom configuration (skills, memory, settings), and returns the response. This would let n8n workflows leverage Claude's agentic capabilities for tasks like code review, documentation generation, and homelab maintenance automation.

The catch? Claude Code CLI expects a specific directory structure (`~/.claude`) with configuration files, skills definitions, and OAuth credentials. These live in a private GitHub repository. Running this in Kubernetes meant solving several interesting problems.

## The Implementation

### Init Container Pattern for Configuration

The core challenge was getting my `.claude` configuration directory into the container before the main process starts. I used an init container that clones a private repository:

```yaml
initContainers:
  - name: clone-claude-config
    image: alpine/git:latest
    env:
      - name: GITHUB_PAT
        valueFrom:
          secretKeyRef:
            name: lux-api-github-pat
            key: token
      - name: GIT_TERMINAL_PROMPT
        value: "0"
    command:
      - /bin/sh
      - -c
      - |
        set -e
        REPO_URL="https://${GITHUB_PAT}@github.com/pedrotchang/.claude.git"
        if [ -d "/claude-config/.git" ]; then
          echo "Git repo exists, updating remote and pulling..."
          cd /claude-config
          git remote set-url origin "$REPO_URL"
          git -c credential.helper= pull
        else
          echo "No git repo found, cleaning and cloning..."
          rm -rf /claude-config/* /claude-config/.[!.]* 2>/dev/null || true
          git clone "$REPO_URL" /claude-config
        fi
        rm -rf /claude-config/.git
        if [ -f "/secrets/credentials.json" ]; then
          cp /secrets/credentials.json /claude-config/.credentials.json
        fi
        chown -R 1000:1000 /claude-config
```

Several details here came from hard-won lessons. `GIT_TERMINAL_PROMPT=0` prevents git from hanging waiting for credentials if authentication fails. The `-c credential.helper=` disables any credential helper that might also try interactive prompts. The cleanup before clone handles a subtle PVC state issue: if the pod crashes mid-clone, you can end up with files but no `.git` directory, causing subsequent clones to fail.

### OAuth Token Refresh: The Read-Only Trap

Claude Code uses OAuth tokens that expire and need refreshing. Initially, I mounted the credentials file directly from a Kubernetes Secret:

```yaml
volumeMounts:
  - name: oauth-credentials
    mountPath: /home/node/.claude/.credentials.json
    subPath: credentials.json
    readOnly: true
```

This broke token refresh completely. When Claude Code tries to write refreshed tokens, it gets a read-only filesystem error and authentication fails. The fix was copying credentials into a writable location during init, making the entire `.claude` directory writable.

### Network Policies: Precision Over Permissiveness

Running an AI service that can execute arbitrary tools demands careful network isolation. I used Cilium's FQDN-based egress policies:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: lux-api-app
spec:
  endpointSelector:
    matchLabels:
      policy-type: app
  egress:
    - toEndpoints:
        - matchLabels:
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"
    - toFQDNs:
        - matchName: "api.anthropic.com"
        - matchName: "console.anthropic.com"
        - matchName: "github.com"
        - matchName: "api.github.com"
        - matchName: "raw.githubusercontent.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

The pod can only reach specific domains over HTTPS. My first iteration restricted DNS queries to only those domains, but this broke unexpectedly. Some internal resolution needs generic DNS access even if the actual connections are blocked. The solution: allow all DNS queries but restrict actual egress by FQDN.

Adding `console.anthropic.com` came after OAuth refresh failures in production. The CLI needs to reach the console endpoint to refresh tokens, not just the API endpoint.

## Challenges and Solutions

### Out of Memory Kills

Claude Code with my Personal AI Infrastructure extensions is memory-hungry. The CLI spawns subprocesses, loads MCP servers, and maintains conversation context. My initial limits of 512Mi request / 2Gi limit caused consistent OOM kills during longer conversations:

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "4Gi"
    cpu: "3000m"
```

Doubling the request and limit resolved the crashes. Memory usage now hovers around 1.5-2GB during active use.

### File Permissions

The container runs as `node` (uid 1000), but the init container runs as root. Without explicit `chown`, the main container cannot write to the configuration directory. This manifests as cryptic errors during skill loading or memory persistence. Setting `fsGroup: 1000` in the pod security context and explicitly chowning in the init container solved this.

### Corrupted State Recovery

Persistent volumes survive pod restarts, which is usually good. But partial failures during init can leave the volume in an invalid state: files exist but not a valid git repo. The init container now handles this explicitly:

```bash
rm -rf /claude-config/* /claude-config/.[!.]* 2>/dev/null || true
git clone "$REPO_URL" /claude-config
```

The glob pattern `.[!.]*` catches dotfiles without matching `.` or `..`.

## Results

The service now runs reliably, surviving pod restarts and node rescheduling. My n8n workflows can hit the API endpoint, pass context-rich prompts, and get Claude's responses with full access to my custom skills and memory. The tight network policies mean even if a prompt injection tried to exfiltrate data, it could only reach Anthropic and GitHub.

The key insights: treat init containers as first-class citizens in your design, test OAuth flows in the actual runtime environment, and when running AI workloads, be generous with memory limits. The debugging time saved is worth the extra RAM.
