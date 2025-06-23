---
title: "Vim: Substition"
date: 2025-06-23
tags:
- Vim
- Linux
---

First of all you can find information for this while inside `Vim` using:
`:help :substitute`

## Replace Names Quickly

Say that you have a Deployment yaml example:
```nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
  labels:
    app: nginx-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-app
  template:
    metadata:
      labels:
        app: nginx-app
    spec:
      containers:
      - name: nginx-app
        image: nginx:1.20
        ports:
        - containerPort: 80
```

And you want to rename it to `web-server`, instead of going line by line use:
`:%s/nginx-app/web-server/`

The original command is actually `:s`, and with it you need to tell Vim what
lines you want to replace.

Adding `%` allows it to grab all lines on the file.

```nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  labels:
    app: web-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
    spec:
      containers:
      - name: web-server
        image: nginx:1.20
        ports:
        - containerPort: 80
```

And if you want to only change some you can do `:%s/nginx-app/web-server/c`
for confirmation.

This will prompt you with the choice of `n` for no, and `y` for for yes.
