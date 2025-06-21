---
title: Bash Commands 01
date: 2025-06-21
tags:
- Linux
- Bash
---

# Bash Commands 01

Introduction:
Just a collection of commands that help me with Linux, and Kubernetes tests.

Some commands that I learned that helped on my CKAD were bash commands such as:
```bash
!$
!*
!!
```

Reading the manual at `man bash` you can read that:
```bash
! # Start a history sub.
* # All the words but the zeroth. After the 1st command all the words
$  The last word.
```

So if you add it all together:
```bash
!$ # The last word of the previous command.
!* # The first word of the previous command.
!! # The previous command.
```

Here is how it's useful:
```bash
kubectl create deployment nginx-app --image=nginx
kubectl describe deployment !$

kubectl get pods -l app=frontend -o wide
kubectl get services !*

kubectl get pods
!! -n kube-system
```

---


202506210844
