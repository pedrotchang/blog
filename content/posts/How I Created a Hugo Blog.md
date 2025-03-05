---
title: How I Created a Hugo Blog
date: 2025-02-25
tags:
- Hugo
- Blog
- How-I
---

I took the time to finally revamp my main website. Prior to the live one, I used one that focused on my career history
and a short biography.

It lacked the features that a Blog should have, especially one that uses it's base to index all of one's writings.

So, here is how I did it.

I went over to <https://github.com/adityatelange/hugo-PaperMod/wiki/Installation> and followed the steps. That's it.

So go do that!

Just kidding! Here are the steps I took:

## Getting Started

1. [Follow Hugo Doc's - Quick Start](https://gohugo.io/getting-started/quick-start/)

2. Create a new Hugo site:

```bash
hugo new site blog --format yaml
# replace blog with the name of your site.
```
3. Since I chose hugo-PaperMod as my theme, I followed their recommendation to install using Git Submodules:

>[!NOTE]This should be run *inside* the folder that you just created with the previous command
```bash
git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
git submodule update --init --recursive # needed when you reclone your repo (submodules may not get cloned automatically)
```
>[!NOTE] If you need to update the theme then do the following command:
```bash
git submodule update --remote --merge
```
4. Finally inside your `config.yaml` add:
```./blog/config.yaml
theme: ["PaperMod"]
```

You can follow the other steps to setup your site, but if you need help, feel free to copy my files and simply replace the
words in them!

---


202502251850
