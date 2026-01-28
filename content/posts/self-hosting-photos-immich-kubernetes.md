---
title: "Self-Hosting Your Photos: Running Immich in Kubernetes with Bulletproof Backups"
date: 2026-02-02
draft: true
tags:
  - immich
  - photos
  - kubernetes
  - homelab
  - backup
  - cloudnativepg
---

## Introduction

After years of trusting Google Photos with my family's memories, I decided it was time to take control. The combination of storage limits, privacy concerns, and the ever-present threat of service changes pushed me to find an alternative. Enter Immich - a self-hosted photo and video management solution that rivals Google Photos in features while keeping your data entirely under your control.

Running Immich in my homelab Kubernetes cluster has been a rewarding journey, but it taught me one crucial lesson: backups are not optional. In this post, I will walk through my Immich deployment, the machine learning service challenges I encountered, and how I configured CloudnativePG to ensure my photo library is protected with automated database backups.

## Immich Architecture on Kubernetes

Immich consists of several components that work together to deliver a polished photo management experience. My deployment runs on a two-node Kubernetes cluster managed by FluxCD, with the database hosted on a separate dedicated database cluster.

The core components include:

**Immich Server** - The main application handling the web interface, API, and photo processing. It runs as a single replica deployment with 4GB memory limit and mounts two NFS-backed persistent volumes: one for the photo library and another for cache storage.

```yaml
containers:
  - name: immich-server
    image: ghcr.io/immich-app/immich-server:v2.5.0
    resources:
      limits:
        memory: 4Gi
      requests:
        cpu: 200m
        memory: 512Mi
```

**Machine Learning Service** - A separate deployment handling facial recognition, object detection, and smart search capabilities using transformer models. This service downloads models from Hugging Face and requires careful configuration of cache directories.

**Redis** - Provides caching and job queue management for background tasks like thumbnail generation and ML processing.

**PostgreSQL with VectorChord** - The database runs on CloudnativePG with the VectorChord extension, which enables efficient storage and querying of ML embedding vectors - essential for Immich's smart search functionality.

## Taming the ML Service

The machine learning service proved to be the trickiest component to configure. When I first deployed Immich, search functionality was completely broken. The ML pod logs revealed permission errors whenever it attempted to download transformer models.

The root cause? Immich's ML container runs as a non-root user (UID 1000) for security, but several Python libraries default to writing cache files to locations like `/.config` on the root filesystem. Since our containers use security contexts that restrict filesystem access, these writes fail silently.

The fix required setting multiple environment variables to redirect all cache writes to a mounted volume:

```yaml
env:
  - name: TRANSFORMERS_CACHE
    value: /cache
  - name: HF_HOME
    value: /cache
  - name: MPLCONFIGDIR
    value: /cache/matplotlib
  - name: HOME
    value: /tmp
```

The `TRANSFORMERS_CACHE` variable handles the Hugging Face transformers library, `HF_HOME` covers the broader Hugging Face hub client, and `MPLCONFIGDIR` redirects matplotlib's configuration directory. Setting `HOME` to `/tmp` provides a writable home directory for any other libraries that need it.

After applying these changes, the ML service successfully downloaded its models and facial recognition came to life. Watching Immich automatically cluster photos of family members was the moment I knew the migration was worth it.

## Database Backups with CloudnativePG

Here is where I learned my most important lesson. For weeks, I ran Immich without database backups. The photo files themselves were synced to my phone and uploaded through the app, so I had some redundancy there. But the database - containing all the metadata, facial recognition data, album structures, and ML embeddings - had no protection.

CloudnativePG makes backup configuration straightforward, but there is a critical gotcha with scheduled backups that caught me off guard.

My initial ScheduledBackup resource used a standard 5-field cron expression:

```yaml
spec:
  schedule: "0 0 * * *"  # Intended: daily at midnight
```

What I did not realize is that CloudnativePG uses a 6-field cron format that includes seconds. My "daily at midnight" schedule was actually being interpreted as "every hour at minute 0, second 0". I was running 24 backups per day instead of one.

The corrected configuration uses the proper 6-field format:

```yaml
spec:
  # CNPG uses 6-field cron: second minute hour day month weekday
  # 0 0 3 * * * = daily at 03:00:00 UTC
  schedule: "0 0 3 * * *"
  backupOwnerReference: self
  cluster:
    name: immich-db-tachtit-cnpg-v0
  immediate: false
```

I also set `immediate: false` to prevent a backup from triggering every time the ScheduledBackup resource is updated. This is important when using GitOps - you do not want a backup firing every time you reconcile your manifests.

The database cluster itself is configured to store backups in Azure Blob Storage with gzip compression and a 14-day retention policy:

```yaml
backup:
  barmanObjectStore:
    destinationPath: https://seyzahldata.blob.core.windows.net/immich
    azureCredentials:
      connectionString:
        name: azure-creds
        key: connection-string-2
    wal:
      compression: gzip
    data:
      compression: gzip
  retentionPolicy: "14d"
```

## Lessons Learned

Running Immich in Kubernetes taught me several valuable lessons:

**Backups must be verified, not assumed.** Just because a backup configuration exists does not mean it is working correctly. Check your backup schedules, verify files are being created, and test restores periodically.

**Read the documentation carefully.** The 6-field cron format difference seems minor, but it resulted in a completely different backup schedule than intended. Always verify operator-specific configuration formats.

**ML workloads need special attention.** Machine learning containers often have complex cache and filesystem requirements. When running as non-root, explicitly configure all cache paths to writable volumes.

**Separate concerns by cluster.** Running databases on a dedicated cluster and applications on another provides isolation and allows independent scaling. My database cluster can focus on data integrity while the application cluster handles user traffic.

Immich has become the centerpiece of my homelab. Every photo and video my family captures is automatically backed up, organized, and searchable - all without relying on any cloud service. With proper backups in place, I can sleep soundly knowing our memories are protected.
