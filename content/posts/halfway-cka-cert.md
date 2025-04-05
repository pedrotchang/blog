---
title: Halfway through CKA Certification
date: 2025-04-05
tags:
- Blog
- CKA
- Certification
---

I am about 50% complete with my CKA Certification course! Woot! I thought I
would write a little blog here about my experience so far.

Yes, homelab really helps, and what is even more helpful is writing things in
your own words. Not for all topics and learnings, but I err on the side of:
"Should I write this or not", and if I do, I opt for writing in my own words.

It takes more time. Even a 5 minute video can go into 15 - 30 minutes of
studying, but it is way more worth it. It lingers in my mind, rather than just
going in one ear and going out the other.

So far I am enjoying so much of the topics available. It is getting a bit out
of hand remembering everything all at once, but I always remember that you can
use `kubectl [command] -h`. This saves me a lot.

In the pursuit of perfection, I also find myself forgetting that I *can* use the
<https://kubernetes.io/docs/home/>, instead of just memorizing everything. Don't
forget that if you plan to pursue the CKA!

Here is a snippet of all my notes that I've written so far. Each link is its own
definition written in my own words.

[[cluster-architecture]]

kubernetes-control-plane:
    [[etcd]]
    [[kube-api]]
    [[kube-controller-manager]]
    [[kube-scheduler]]
    [[kubelet]]
    [[kube-proxy]]

Create & Configure Pods
    [[replicasets]]
    [[deployments]]
    [[services]]
        [[cluster-ip]]
        [[load-balancer]]

Infrastructure as Code
    [[imperative-vs-declarative]]

[[kubernetes-scheduler]]
    [[manual-scheduling]]
    [[labels-and-selectors]]
    [[resource-limits]]
    [[daemon-sets]]
    [[static-pods]]
    [[multiple-schedulers]]
    [[scheduler-profiles]]
    [[admission-controllers]]
        [[validating-and-mutating-admission-controllers]]

configuration
    [[taints-and-tolerations]]
    [[node-selectors]]
    [[node-affinity]]
    [[affinity-vs-taints-and-tolerations]]

logging-monitoring
    [[monitoring-components]]
    [[application-logs]]

application-lifecyle-management
    [[rolling-updates-and-rollback]]
    [[configure-applications]]
        [[commands-and-arguments]]
        [[environment-variables]]
        [[secrets]]
    [[multi-container-pods]]
    [[init-containers]]
    [[autoscaling]]

---


202504050643
