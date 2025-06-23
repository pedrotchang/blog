---
title: "Bash: History Expansion"
date: 2025-06-21
tags:
- Linux
- Bash
---

# Event Designators (found on `man bash`)

These commands help to save time on Linux based tests:

```bash
! # Start a history sub.
* # All the words but the zeroth. After the 1st command all the words
$ # The last word.
```

So if you add it all together:
```bash
!$ # The last word of the previous command.
!* # The first word of the previous command.
!! # The previous command.
```

### Examples

```bash
kubectl apply -f my-pod.yaml 
vim !$ # vim my-pod.yaml

touch file1.txt file2.txt
rm !* # rm file1.txt file2.txt

kubectl get pods
!! -n kube-system # kbuectl get pods -n kube-system
```

---


202506210844
