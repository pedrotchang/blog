---
title: How I Set my GitHub README
date: 2025-03-04
tags:
- GitHub
- How-I
---

I finally took the time to update my README on GitHub. If you don't know, your `username/username` repository in
GitHub is unique!

If you modify your README, you can get something like this:

![README](/README.png)

Let's get started!

## Blog Workflow

Let's create a blog workflow. I use a Hugo website for my blog. You can learn how to make one yourself following
my blog [post]((https://www.pedrotchang.dev/posts/how-i-created-a-hugo-blog/)).

At the end, it will automatically pull your five recent blog posts from your website.

Follow the steps from <https://github.com/gautamkrishnar/blog-post-workflow>. 

> [!NOTE]
> You need to create a folder named `.github`, and create a `workflows/` folder inside if it doesn't exist.

Add this file:
```.github/workflows/blog-post-workflow.yml
name: Latest blog post workflow
on:
  schedule: # Run workflow automatically
    - cron: '0 * * * *' # Runs every hour, on the hour
  workflow_dispatch: # Run workflow manually (without waiting for the cron to be called), through the GitHub Actions Workflow page directly
permissions:
  contents: write # To write the generated contents to the readme

jobs:
  update-readme-with-blog:
    name: Update this repo's README with latest blog posts
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Pull in dev.to posts
        uses: gautamkrishnar/blog-post-workflow@v1
        with:
          feed_list: "https://www.pedrotchang.dev/index.xml"
```

Make sure to commit and push the changes, and it should show up in your Actions tab on the repository.

There should now be a new workflow on the left called `Latest blog post workflow`. Then run it manually.

That's it! Feel free to [Contact](https://www.pedrotchang.dev/contact/) me if you need any help!

The other parts of the README just follow the convention of Markdown. I am not interested in doing templating.

You can use mine as an example for templating! :) 

---

202503042212
