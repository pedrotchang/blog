---
title: How I Passed the CKAD Exam in June 2025
date: 2025-07-02
tags:
- Kubernetes
- How-I
---
# Introduction

CKAD stands for Certified Kubernetes Application Developer.

I thought I'd take the time to write a long-form documentation of how I passed 
the Certified Kubernetes Application Developer exam.

I took the exam on June 5, and although I passed, let me tell you, I had to
make changes to my strategy during the exam.

I was at first, in the first 10 minutes, trying to use YAML files from the
docs, but realized quickly how slow the remote system was, so I decided to use
`kubectl` commands wherever possible.

## Imperative vs. Declarative

First of all, forget about trying to memorize YAML files or even copying them
from the documentation. Yes, it is available to you, but extracting from the
documentation takes way too much time.

It is way more efficient to create your commands from scratch using
`kubectl`.

That being said, it is important to navigate the documentation. Try to do most
of your practice sessions with just the documentation.

## Documentation to Remember

If you can, remember a couple of documentation links that you can refer to
quickly:
`https://kubernetes.io/docs/reference/kubectl/quick-reference/`
For reference, the above link is on the front page of the documentation site.

Another great link is to search `Configure a Pod`, and look at result #4:
<https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/>

This is a how-to guide that is more granular than the generic PVC guide.

Lastly, for `deployments`, I used this documentation page as it's a more
granular explanation of deployments:

Search for `wordpress`, and choose the 4th result:
<https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/>

## Practice

I used mostly just quick and short practices that go over each topic.

To be honest, as much as I like Killercoda, it can be quite slow, and long
tests should be more of a litmus test of your level of preparation.

I opted to use [minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Flinux%2Fx86-64%2Fstable%2Fbinary+download).

It is really straightforward to follow how to set it up, and all you have to
do to use it is:
```bash
minikube start
minikube stop
```

## Time Management

It is incredibly important to manage your time. I thought it would be best to
read through each question and find the ones that I could work on easily.

You can't! It's too slow. The system will eat up your time.

Your best bet is to watch your time, divide the number of questions you have,
set aside those minutes for each question, and then move forward!

Don't dwell on the questions and try to figure out how to solve them; skip,
and come back to them.

---


202507021251
