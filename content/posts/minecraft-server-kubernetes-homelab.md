---
title: "Mining for Fun: Running a Modded Minecraft Server on My Kubernetes Homelab"
date: 2026-02-03
draft: true
tags:
  - minecraft
  - kubernetes
  - homelab
  - gaming
  - containers
---

There is something deeply satisfying about telling your friends, "Yeah, the server is running on my Kubernetes cluster at home." The confused looks, the raised eyebrows, the inevitable question of "why would you do that?" -- these are the moments that make homelabbing worthwhile. So when my friends wanted to play All The Mods 10 together, I knew exactly where that server was going to run.

## Why Self-Host a Minecraft Server?

The easy answer is that I could just pay for a hosted Minecraft server. Plenty of services offer modpack support, reasonable pricing, and zero maintenance headaches. But where is the fun in that?

Self-hosting a Minecraft server on my homelab gives me complete control over the experience. I can tweak settings on the fly, allocate resources as needed, and most importantly, integrate it into my existing GitOps workflow. Every configuration change is tracked in git, deployed automatically through FluxCD, and I can roll back if something goes catastrophically wrong. Which, as you will see, happened more than once.

Plus, there is an undeniable appeal to running a game server on the same infrastructure that hosts my personal applications. My Kubernetes cluster does not discriminate between serious business applications and block-building adventures. It treats my Minecraft server with the same declarative precision as my photo backup solution or RSS reader.

## The itzg/minecraft-server Container

If you have ever tried to containerize a Minecraft server yourself, you know it can be a pain. Java versions, memory settings, mod loading, world persistence -- there are a lot of moving pieces. Thankfully, the community has blessed us with [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server), a container image that handles all the complexity.

This image is incredibly flexible. You can run vanilla Minecraft, Forge, Fabric, Paper, or in my case, pull modpacks directly from CurseForge. The configuration happens through environment variables, which maps perfectly to Kubernetes ConfigMaps:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: minecraft-configmap
data:
  EULA: "TRUE"
  TYPE: "CURSEFORGE"
  CF_SLUG: "all-the-mods-10"
  CF_FILENAME_MATCHER: "Server"
  MEMORY: "4G"
  ALLOW_FLIGHT: "TRUE"
  SEED: "7783552872028868482"
  MOTD: "Seyza's Minecraft Server"
  MAX_PLAYERS: "5"
```

Set `TYPE: CURSEFORGE`, point it at a modpack with `CF_SLUG`, and the container handles downloading, installing, and configuring everything. The image even keeps itself updated through Renovate, which automatically creates pull requests when new versions are released. My Minecraft server stays current without me lifting a finger.

## The Colorwheel Catastrophe

Everything was working beautifully until it was not. The server started crash-looping, and the logs revealed the culprit: a mod called colorwheel was failing to load because it required Iris, a client-side shader mod that has no business running on a server.

This is the dark side of modpacks. They bundle hundreds of mods together, and sometimes those mods include client-side components that break when you try to run them server-side. The All The Mods 10 server pack should theoretically exclude these, but colorwheel slipped through.

My first attempt was surgical: exclude the problematic mod using `CF_EXCLUDE_MODS`:

```yaml
CF_EXCLUDE_MODS: "colorwheel"
```

Simple, right? Wrong. The mod was already downloaded and sitting in my persistent volume from the previous server startup. The exclusion only prevents new downloads -- it does not clean up existing files.

So I added `REMOVE_OLD_MODS`:

```yaml
REMOVE_OLD_MODS: "TRUE"
```

Still crashing. The modpack synchronization was not re-running because it thought everything was already in place. Time to bring out the big guns:

```yaml
CF_FORCE_SYNCHRONIZE: "TRUE"
```

This tells the container to re-sync the entire modpack on startup, respecting the new exclusion rules. Combined with `REMOVE_OLD_MODS`, this finally purged the colorwheel mod from existence.

But wait, I was paranoid. What if the container started before the sync completed and loaded the old mod anyway? I added an init container as a nuclear option:

```yaml
initContainers:
  - name: remove-incompatible-mods
    image: busybox:latest
    command: ['sh', '-c', 'rm -f /data/mods/colorwheel*.jar']
    volumeMounts:
    - name: minecraft-data
      mountPath: /data
```

Overkill? Maybe. But the server finally started, and I could commit all these fixes with proper git messages explaining why each change was necessary. Future me will thank present me when this inevitably happens again with a different mod.

## Auto-Sync Shenanigans

The modpack synchronization behavior taught me a valuable lesson about stateful applications in Kubernetes. The itzg/minecraft-server container is smart about not re-downloading the entire modpack on every restart -- that would be wasteful and slow. But this optimization becomes a problem when you need to make changes.

Here is the pattern I landed on for modpack management:

1. **Exclude problematic mods** with `CF_EXCLUDE_MODS` before they cause issues
2. **Use `CF_OVERRIDES_EXCLUSIONS`** for entire directories you do not need (like shader packs)
3. **Set `REMOVE_OLD_MODS: TRUE`** if you need to clean up after yourself
4. **Temporarily enable `CF_FORCE_SYNCHRONIZE`** when making changes, then disable it to speed up future restarts

The GitOps workflow makes this easy to manage. I can push a configuration change, watch Flux reconcile it, check if the server starts successfully, and then push another commit to remove the force-sync flag. Every step is documented in the git history.

## Fun with Friends

After all the debugging and configuration tweaking, the server has been running smoothly. My friends and I have been exploring the All The Mods 10 world, building increasingly ridiculous automated factories, and occasionally crashing the server when someone's quarry digs into the void.

The resource allocation ended up being reasonable for a small group: 4GB of memory for the JVM, with Kubernetes allowing bursts up to 12GB when loading chunks or processing heavy automation. The two HP EliteDesk 800 G2 machines in my cluster handle it without breaking a sweat.

Is this the most practical way to run a Minecraft server? Absolutely not. A $5/month hosted server would have been online in minutes with zero debugging required. But I would have missed out on learning about CurseForge modpack synchronization, init container patterns for cleaning up state, and the satisfaction of telling my friends that our world is backed by a proper Kubernetes deployment with persistent volume claims.

Sometimes the journey matters more than the destination. And in this case, the journey involved a lot of YAML files and a deep hatred for a mod called colorwheel.

---

*The server is currently commented out in my kustomization.yaml, resting peacefully until the next time my friends want to play. When that day comes, I will uncomment one line, push to git, and Flux will bring it back to life. GitOps is beautiful.*
