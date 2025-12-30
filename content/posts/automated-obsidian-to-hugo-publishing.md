---
title: "Automating Blog Posts from Obsidian to Hugo with Git Hooks"
date: 2025-12-29
tags:
- Obsidian
- Hugo
- Git
- Automation
- Productivity
- Publish
---

#publish

I use Obsidian for my personal knowledge management and Hugo for my blog. I wanted a seamless way to publish notes from my Obsidian vault to my blog without manual copying or running scripts. Here's how I automated the entire workflow using git hooks.

## The Problem

I maintain two separate git repositories:
- **Obsidian vault**: `/home/seyza/secondbrain` - my personal notes and zettelkasten
- **Hugo blog**: `/home/seyza/Repos/github.com/pedrotchang/blog` - my published blog

Previously, publishing a note required:
1. Manually copying the markdown file to the blog's `content/posts/` directory
2. Committing the change to the blog repo
3. Running the publish script to create a release
4. Triggering GitHub Actions to deploy

This was tedious and disrupted my writing flow.

## The Solution

I created an automated workflow that:
1. **Tags notes for publishing** using `#publish` in the markdown
2. **Auto-detects tagged notes** on every commit to the Obsidian vault
3. **Syncs them to the blog repo** automatically
4. **Triggers the release process** without manual intervention

All of this happens transparently whenever I commit changes to my Obsidian vault.

## Implementation

### Step 1: Create the Git Post-Commit Hook

Git hooks are scripts that run automatically at certain points in the git workflow. I used a `post-commit` hook that runs after every commit.

Create the hook file:
```bash
touch .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

### Step 2: Write the Automation Script

The hook searches for files tagged with `#publish`, copies them to the blog, and triggers the release:

```bash
#!/bin/bash

# Auto-publish to blog when #publish tag is detected

BLOG_DIR="/home/seyza/Repos/github.com/pedrotchang/blog"
BLOG_POSTS_DIR="$BLOG_DIR/content/posts"
OBSIDIAN_DIR="/home/seyza/secondbrain"

# Find all markdown files with #publish tag
PUBLISH_FILES=$(cd "$OBSIDIAN_DIR" && grep -rl "#publish" --include="*.md" . 2>/dev/null || true)

if [ -z "$PUBLISH_FILES" ]; then
    exit 0
fi

echo "🚀 Publishing notes with #publish tag to blog..."

# Copy files to blog
COPIED_FILES=()
while IFS= read -r file; do
    if [ -f "$OBSIDIAN_DIR/$file" ]; then
        filename=$(basename "$file")
        cp "$OBSIDIAN_DIR/$file" "$BLOG_POSTS_DIR/$filename"
        COPIED_FILES+=("$filename")
        echo "  ✓ Copied: $filename"
    fi
done <<< "$PUBLISH_FILES"

# Change to blog directory
cd "$BLOG_DIR"

# Stage files
git add content/posts/

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "No new changes to publish"
    exit 0
fi

# Create commit message
if [ ${#COPIED_FILES[@]} -eq 1 ]; then
    COMMIT_MSG="Add post: ${COPIED_FILES[0]}"
else
    COMMIT_MSG="Add posts: ${COPIED_FILES[*]}"
fi

# Commit
git commit -m "$COMMIT_MSG"

# Run publish script to create release
echo "📦 Running publish script to create release..."
cd "$BLOG_DIR"
./publish

echo "✅ Blog published successfully!"
```

### Step 3: Tag Notes for Publishing

To publish a note, simply add `#publish` anywhere in the markdown file:

```markdown
#publish

---
title: "My Article Title"
date: 2025-12-29
tags:
- Topic
---

Content goes here...
```

### Step 4: Commit and Watch It Work

```bash
git add .
git commit -m "Update notes"
```

The hook automatically:
- Detects the `#publish` tag
- Copies the file to the blog repo
- Commits the change
- Runs the publish script
- Creates a new GitHub release
- Triggers deployment via GitHub Actions

## Why This Works Well

**Separation of concerns**: My Obsidian vault stays private and personal, while only tagged notes become public blog posts.

**Atomic workflow**: Writing and publishing happen in one action - commit my notes.

**No context switching**: I never leave my note-taking environment to publish.

**Reversible**: If I want to unpublish, I just remove the `#publish` tag and commit.

## Technical Details

The workflow leverages:
- **Git hooks**: Automated triggers on git events
- **grep**: Pattern matching to find tagged files
- **Bash scripting**: Orchestrating the file sync and release process
- **GitHub Actions**: Automated deployment (triggered by the existing publish script)

## Potential Improvements

Future enhancements could include:
- Remove `#publish` tag after successful publish to track what's already been published
- Add frontmatter validation to ensure Hugo compatibility
- Create a pre-commit hook to warn about publishing notes without proper metadata
- Support for updating existing posts (detecting changes to already-published notes)

## Conclusion

This setup transformed my blogging workflow from a multi-step manual process to a seamless, automated experience. Now I can focus on writing in Obsidian, and publishing happens automatically when I'm ready to share.

The key insight: **leverage existing tools** (git hooks, grep, bash) rather than building complex custom solutions. Simple, Unix-philosophy automation often beats elaborate workflows.

---

202512292140
