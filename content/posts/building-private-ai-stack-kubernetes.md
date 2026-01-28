---
title: "Building a Private AI Stack in My Kubernetes Homelab"
date: 2026-02-01
draft: true
tags:
  - ollama
  - ai
  - kubernetes
  - homelab
  - llm
  - open-webui
---

When OpenAI released GPT-4, I was amazed by what large language models could do. But every time I pasted a document into ChatGPT or asked about something personal, a small voice in the back of my head wondered: where does this data go? Who else might see it? For someone who runs their own email server and self-hosts their password manager, the answer was obvious. It was time to build a local AI stack.

This post walks through how I deployed Ollama, Open WebUI, and Paperless-ngx with AI integration on my Kubernetes homelab. The goal: a fully private AI system that can answer questions, process documents, and remember context, all without sending a single byte to the cloud.

## Why Self-Host AI?

The tradeoffs between cloud and local AI come down to three factors: privacy, cost, and capability.

Cloud AI services like ChatGPT and Claude are incredibly powerful. They run models with hundreds of billions of parameters on enterprise-grade hardware. The results speak for themselves. But you pay for that power in multiple currencies. There is the literal cost (API fees add up quickly for heavy users), but also the privacy cost. Every prompt you send becomes training data, or at minimum, sits on someone else's server.

Local AI flips this equation. You own every piece of data. There are no API costs after the initial hardware investment. The downside? You are limited to models that fit in your available memory, and inference is slower on consumer hardware.

For my use case, local AI wins. I am not trying to replace GPT-4 for complex reasoning tasks. I want a private assistant that can summarize documents, auto-tag my paperwork, and maintain conversational memory. A 3B parameter model running on modest hardware handles this beautifully.

## The Foundation: Ollama for Local Inference

Ollama is the engine that makes everything else possible. It provides a simple API for running open-source language models, handling all the complexity of model loading, prompt formatting, and inference.

My deployment runs on the Tachtit cluster (two HP EliteDesk 800 G2 mini PCs). Without a GPU, I am limited to CPU inference, which means sticking to smaller models. The deployment requests 2GB of memory but can burst to 8GB, enough to run 7B parameter models comfortably.

```yaml
resources:
  requests:
    memory: 2Gi
    cpu: 500m
  limits:
    memory: 8Gi
    cpu: 4000m
```

Storage is allocated at 30GB on my TrueNAS iSCSI backend, which provides plenty of room for multiple model files. The llama3.2:3b model has become my workhorse. It is fast enough for real-time chat and capable enough for summarization and tagging tasks.

I initially deployed Ollama with a LoadBalancer service, but switched to Gateway API HTTPRoute for cleaner routing. The service is available internally at `ollama.ollama.svc.cluster.local:11434` and externally (on my local network) at `ollama.local.seyzahl.com`. No Cloudflare tunnel here. This stays strictly on the LAN.

## The Interface: Open WebUI

Running a language model is only useful if you can interact with it. Open WebUI provides a ChatGPT-like interface that connects directly to Ollama.

The configuration is straightforward. The deployment points to Ollama's internal Kubernetes service:

```yaml
data:
  OLLAMA_BASE_URL: "http://ollama.ollama.svc.cluster.local:11434"
  WEBUI_AUTH: "true"
  ENABLE_SIGNUP: "true"
  DEFAULT_MODELS: "llama3.2:3b"
```

Open WebUI supports multiple users with authentication, chat history persistence, and model management. I can pull new models directly from the UI, switch between them mid-conversation, and share useful prompts across sessions.

Like Ollama, this service is local-only. I access it via `openwebui.local.seyzahl.com` through my Cilium gateway. The web interface is snappy, and chat responses from the 3B model typically start streaming within a second or two.

## Document Intelligence: Paperless-ngx with AI

Here is where local AI starts paying dividends. Paperless-ngx is a document management system, essentially a personal archive for receipts, bills, tax documents, and anything else that comes on paper. I have been using it for years, manually tagging documents as they come in.

The new addition is paperless-gpt, a sidecar service that connects Paperless-ngx to Ollama. When a document is ingested, paperless-gpt sends the OCR text to Ollama and automatically generates titles and tags.

```yaml
data:
  LLM_PROVIDER: "ollama"
  OLLAMA_HOST: "http://ollama.ollama.svc.cluster.local:11434"
  LLM_MODEL: "llama3.2:3b"
  AUTO_GENERATE_TITLE: "true"
  AUTO_GENERATE_TAGS: "true"
```

The Paperless stack is more complex than the other services. It includes Redis for task queuing, Gotenberg for document conversion, and Tika for OCR processing. Each component runs as a separate deployment, coordinated through environment variables. The main application connects to a CloudnativePG PostgreSQL cluster on my dedicated database hardware.

Unlike Open WebUI, Paperless-ngx has external access through a Cloudflare tunnel at `paperless.seyzahl.com`. I want to upload documents from my phone or scan them from anywhere, so external access makes sense. The AI processing still happens entirely on my local hardware.

## Persistent Memory: pgvector for Embeddings

The final piece of my AI infrastructure is a PostgreSQL database with the pgvector extension. This enables semantic search and AI memory through vector embeddings.

```yaml
postgresql:
  shared_preload_libraries:
    - vector

bootstrap:
  initdb:
    database: pai
    owner: pai
    postInitSQL:
      - CREATE EXTENSION IF NOT EXISTS vector;
```

The PAI (Personal AI Infrastructure) database runs on my Data cluster, a single HP laptop running CloudnativePG with two replicas. It stores embeddings generated by Ollama and serves as the backend for my PAI Memory MCP service, a mem0-based memory layer that provides conversational context across sessions.

This is where things get interesting. Instead of starting every conversation from scratch, the memory service can recall previous interactions and context. Ask about something we discussed last week, and the system retrieves relevant memories from the vector database. It is not perfect, but it transforms the AI from a stateless tool into something that actually knows who I am.

## Resource Reality Check

Let me be honest about the limitations. My dual EliteDesk cluster has no GPU, which means inference times of 3-5 seconds for typical responses with a 3B model. Larger models are impractical. The 7B variants are usable but noticeably slower.

Total resource allocation across the AI stack:

- Ollama: 2-8GB RAM, up to 4 CPU cores
- Open WebUI: 512MB-2GB RAM
- Paperless-ngx (full stack): ~6GB RAM combined
- PAI Memory: 256-512MB RAM
- pgvector database: 512MB+ RAM

This is not a replacement for GPT-4. Complex reasoning tasks, code generation for unfamiliar languages, and nuanced creative writing are all better handled by frontier models. What I have built is a private assistant for personal tasks, which is exactly what I wanted.

## What I Learned

Building this stack reinforced something I already suspected: local AI is ready for personal use. The models are good enough, the tooling has matured, and the privacy benefits are real.

The GitOps approach through FluxCD made iteration painless. When I switched Ollama from LoadBalancer to Gateway API, it was a single commit. When I wanted to try a different model, I updated the configmap. Everything is version controlled, reproducible, and auditable.

If you are running a homelab and care about privacy, I would encourage you to try this. Start with Ollama and a small model. Add Open WebUI for a chat interface. Then look at your existing services and ask: could AI make this better? For me, automatic document tagging alone justified the effort. The rest is a bonus.
