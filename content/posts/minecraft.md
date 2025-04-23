---
title: How I installed ATM10 in Talos Linux Kubernetes
date: 2025-04-23
tags:
- Blog
- How-I
---
# How I Installed Minecraft All the Mods 10 on Kubernetes

## Introduction

First of all, you don't have to do this at all..

It just adds another complication, instead of just running Minecraft ATM10 on
Docker.

That being said, I love Kubernetes, and have been wanting to use for all my
server needs. Even when it is complicated..

*Also*, if you want to follow along, you have to know that I have FluxCD in my
process, so you may have modify it for your use case.

Anyways, here is what I did!

### Setup

I found an already made image of Minecraft made on Docker, and used their
settings.

<https://github.com/itzg/docker-minecraft-server?tab=readme-ov-file>

I made a Deployment with requests and limits. ATM10 is a heavy app, and tbh
I don't have too many resources in my little PCs.

I also held the version to the release date, rather than getting the *latest*
release automatically.

```Deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minecraft
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minecraft
  template:
    metadata:
      labels:
        app: minecraft
        policy-type: "server"
    spec:
      containers:
        - name: minecraft
          image: itzg/minecraft-server:2025.4.0

          resources:
            requests:
              memory: 8Gi
              cpu: 2
            limits:
              memory: 12Gi
              cpu: 4

          securityContext:
              allowPrivilegeEscalation: false

          imagePullPolicy: Always

          envFrom:
            - configMapRef:
                name: minecraft-configmap
            - secretRef:
                name: minecraft-container-env

          ports:
            - containerPort: 25565
              protocol: TCP

          volumeMounts:
          - name: minecraft-data
            mountPath: /data

      restartPolicy: Always

      volumes:
        - name: minecraft-data
          persistentVolumeClaim:
            claimName: minecraft-data-pvc
```

I also created a Service, Storage, and Secret. I called these with Kustomize.

If you want to see my exact settings, they are public to view!

<https://github.com/pedrotchang>

### Extra Settings for ATM10

Rather than listing all the settings here though, I wanted to go through how to
setup ATM10. It has some extra setting that I had to figure out.

For one, you need an API key from CurseForge.

Login by either signing up or using an exisiting account:
<https://console.curseforge.com/#/login>

Go to API Keys, and copy your API Key.

I then grabbed this key and created an Azure Key Vault entry with it. I called 
it inside my deployment using secretRef section:

```deployment.yaml
secretRef:
  name: minecraft-container-env
```

I then also had to include settings for the deployment to install ATM10 inside
the server. It also required the `MEMORY: "4G"`. This settings gives the
*installation* process 4G. Really great way of ensuring that the container
has enough resources to complete its job.

Also...make sure to add ALLOW_FLIGHT, otherwise when you die you become a ghost
and float, you'll get kicked out of the server.

```configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: minecraft-configmap
data:
  EULA: "TRUE"
  MOD_PLATFORM: "AUTO_CURSEFORGE"
  CF_SLUG: "all-the-mods-10"
  MEMORY: "4G"
  CF_OVERRIDES_EXCLUSIONS: |
    shaderpacks/**
  ALLOW_FLIGHT: "TRUE"
  OVERRIDE_SERVER_PROPERTIES: "false"
  SEED: "7783552872028868482"
  OPS: |
    a_seyza
  MAX_PLAYERS: "5"
```

#### Conclusion

Other than that, there wasn't much to it other than finding the external IP
that allowed me to connect to it. I never exposed it to the internet, as I have
no intention of playing it elsewhere (nor do I currently have the time to play)
with others (someday soon!). It was a fun little exercise, which for now, I
will shelf for a day when I can play with my son, and friends in the future!

I hope you enjoyed!


---


202504130837
