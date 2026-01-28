---
title: "Connecting TrueNAS to Kubernetes: A Democratic-CSI Deep Dive"
date: 2026-01-31
draft: true
tags:
  - truenas
  - kubernetes
  - storage
  - iscsi
  - nfs
  - homelab
---

Storage is the foundation of any serious Kubernetes deployment. Stateless applications are great for tutorials, but real workloads need persistent data. When I set up my homelab cluster, I knew I wanted to leverage my existing TrueNAS SCALE server for storage. What I did not expect was the debugging journey that followed.

## The Storage Architecture

My homelab runs two Kubernetes clusters managed by Talos Linux and Omni. The "Tachtit" cluster handles applications, while the "Data" cluster runs databases. Both need persistent storage, and both connect to a TrueNAS SCALE server running on dedicated hardware.

TrueNAS offers two primary protocols for Kubernetes integration: NFS and iSCSI. Each has tradeoffs:

**NFS** is simpler to configure and supports ReadWriteMany (RWX) access - multiple pods can mount the same volume simultaneously. Perfect for shared data like media libraries or configuration files.

**iSCSI** provides block-level storage with better performance characteristics. It is ideal for databases and applications that need consistent I/O. The downside: ReadWriteOnce (RWO) only, meaning a single pod per volume.

I ended up using both, connected through democratic-csi.

## Democratic-CSI: The Bridge

Democratic-csi is a CSI (Container Storage Interface) driver that connects Kubernetes to various storage backends, including TrueNAS. It handles volume provisioning, attachment, and lifecycle management.

The initial deployment seemed straightforward - install the Helm chart, configure credentials, create a StorageClass. Then TrueNAS SCALE 25.04 arrived and broke everything.

### The API Version Saga

TrueNAS SCALE 25.04 changed its API in subtle but breaking ways. Democratic-csi requests were failing with cryptic errors. The fix required forcing API v2:

```yaml
driver:
  config:
    httpConnection:
      apiVersion: 2
```

But wait, there is more. The `next` tag of democratic-csi included fixes for SCALE 25.04 compatibility that had not reached the stable release:

```yaml
image:
  repository: democraticcsi/democratic-csi
  tag: next
```

Running pre-release container images is not my favorite practice, but sometimes you need bleeding edge to work with bleeding edge.

### Configuration Secret Management

My first attempt at configuration used a ConfigMap referenced by the HelmRelease. This worked until I needed to include API credentials:

```yaml
# Bad approach - credentials in ConfigMap
driver:
  config:
    httpConnection:
      username: admin
      password: supersecret  # Exposed in plain text!
```

The correct pattern uses `existingConfigSecret`:

```yaml
csiDriver:
  config:
    driver: freenas-iscsi
  existingConfigSecret: democratic-csi-config

# Separate Secret (encrypted with SOPS)
apiVersion: v1
kind: Secret
metadata:
  name: democratic-csi-config
stringData:
  driver-config-file.yaml: |
    driver: freenas-iscsi
    httpConnection:
      protocol: https
      host: truenas.local
      port: 443
      username: admin
      password: ENC[AES256_GCM,...]
      apiVersion: 2
```

### The Template Validation Trap

HelmRelease validation checks templates before applying. Democratic-csi's Helm chart expects certain values to exist, even when using external secrets. My releases failed validation until I added minimal stubs:

```yaml
driver:
  config:
    driver: freenas-iscsi
    # Minimal stub to pass template validation
    # Actual config comes from existingConfigSecret
```

This feels like a workaround, but it is documented in the democratic-csi issues as expected behavior.

## Network Policies Strike Again

Democratic-csi pods need network access that surprised me:

1. **TrueNAS API** (port 443) - obvious
2. **Kubernetes API** - for CSI operations
3. **iSCSI targets** (port 3260) - for block storage
4. **Node communication** - for volume attachment

My initial restrictive policies broke CSI operations silently. Volumes would provision but never attach. The logs showed timeout errors connecting to the Kubernetes API.

The pragmatic solution:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
spec:
  endpointSelector:
    matchLabels:
      app: democratic-csi
  egress:
    - {}  # Allow all egress
```

Yes, this is permissive. Democratic-csi needs to talk to many endpoints, and debugging CSI networking issues is painful. For a homelab, this tradeoff is acceptable.

## NFS CSI Driver

For ReadWriteMany workloads, I added the standard NFS CSI driver alongside democratic-csi:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: csi-driver-nfs
spec:
  chart:
    spec:
      chart: csi-driver-nfs
      sourceRef:
        kind: HelmRepository
        name: csi-driver-nfs
```

The NFS driver is simpler - it just needs the NFS server address and export path. No API integration, no credentials, no version compatibility issues. Sometimes boring is better.

My StorageClasses now offer clear choices:

```yaml
# For databases and single-pod workloads
storageClassName: truenas-iscsi

# For shared data across pods
storageClassName: truenas-nfs
```

## Lessons Learned

Storage integration taught me several painful lessons:

**API versions matter.** When your storage backend upgrades, expect driver compatibility issues. Pin versions or test thoroughly before upgrading production.

**Secrets belong in Secrets.** Never put credentials in ConfigMaps, even for "internal" services. Use SOPS encryption and external secret references.

**CSI drivers need broad network access.** They communicate with storage backends, Kubernetes API, and nodes. Overly restrictive policies cause silent failures.

**Have multiple storage options.** iSCSI and NFS serve different use cases. Running both provides flexibility.

My storage layer now handles everything from ephemeral build caches to critical database volumes. The debugging was frustrating, but understanding how CSI drivers actually work has made troubleshooting much easier. When the next TrueNAS update breaks something, I will know where to look.
