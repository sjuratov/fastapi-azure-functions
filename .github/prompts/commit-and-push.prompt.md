---
description: Commit changes with a well-crafted message and push to remote
---

Review all current changes in the repository using `git status` and `git diff`.

Analyze the changes to understand:
- What files were modified/added/deleted
- The purpose and scope of the changes
- Any breaking changes or important updates

Generate a commit message following conventional commit format:
- **Type:** feat, fix, docs, style, refactor, test, chore, ci, perf
- **Scope:** The area affected (optional)
- **Subject:** Short description (50 chars max)
- **Body:** Detailed explanation if needed (wrap at 72 chars)
- **Footer:** Breaking changes or issue references

Stage all changes (or confirm what's already staged), create the commit with the generated message, and push to the current branch on the remote repository.

Display the commit SHA and confirm the push was successful.
