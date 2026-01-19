---
title: "Certified Kubernetes Administrator (CKA) Study Notes"
date: 2025-03-03
tags:
- Kubernetes
- CKA
- Certification
- DevOps
---

#publish

## Resources

- [CKA Allowed Resources](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed#certified-kubernetes-administrator-cka)
- [Practice Tests - Killer.sh](https://killer.sh/)
- [CNCF CKA Guide 2025](https://github.com/Cloud-Native-Islamabad/Certified-Kubernetes-Administrator-CKA-Guide-2025)

## High Level Architecture

![k8s-architecture](https://notes.kodekloud.com/images/CKA-Certification-Course-Certified-Kubernetes-Administrator-Cluster-Architecture/frame_510.jpg)

## Kubernetes Control Plane

- etcd
- kube-api
- kube-controller-manager
- kube-scheduler
- kubelet
- kube-proxy

## Create & Configure Pods

- ReplicaSets
- Deployments
- Services
  - ClusterIP
  - LoadBalancer

## Infrastructure as Code

- Imperative vs Declarative

## Kubernetes Scheduler

- Manual Scheduling
- Labels and Selectors
- Resource Limits
- DaemonSets
- Static Pods
- Multiple Schedulers
- Scheduler Profiles
- Admission Controllers
  - Validating and Mutating Admission Controllers

## Configuration

- Taints and Tolerations
- Node Selectors
- Node Affinity
- Affinity vs Taints and Tolerations

## Logging & Monitoring

- Monitoring Components
- Application Logs

## Application Lifecycle Management

- Rolling Updates and Rollback
- Configure Applications
  - Commands and Arguments
  - Environment Variables
  - Secrets
- Multi-Container Pods
- Init Containers
- Autoscaling

## Cluster Maintenance

- OS Updates
- Software Versioning
- Cluster Upgrade Process
- Backup and Restore Methods

## Security

![security](https://notes.kodekloud.com/images/CKA-Certification-Course-Certified-Kubernetes-Administrator-Security-Section-Introduction/frame_50.jpg)

- Security Primitives
- Authentication
- TLS Certificates
- kubeconfig
- API Groups
- Authorization
- Role-Based Access Controls (RBAC)
- Cluster Roles
- Service Accounts
- Image Security
- Security Contexts
- Network Policies
- Custom Resource Definitions (CRDs)
- Custom Controllers

## Storage

- Docker Storage
- Container Storage Interface (CSI)
- Volumes
- Persistent Volumes
- Persistent Volume Claims (PVC)
- Storage Classes

## Networking

- Cluster Networking
- Pod Networking
- CNI in Kubernetes
- IP Address Management
- Service Networking
- Cluster DNS
- CoreDNS
- Ingress
- Gateway API

## Other Topics

- JSONPath
- Kubernetes the Hard Way

## Practice Tests

- Lightning Labs
