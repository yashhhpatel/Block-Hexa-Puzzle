#!/usr/bin/env bash
# Auto-commit and push every change made in this project.
# Called by Claude Code hooks (see .claude/settings.json).

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0

# Name the changed file in the commit message when the hook payload has one.
payload="$(cat 2>/dev/null)"
file="$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
file="${file##*[\\/]}"

git add -A
git diff --cached --quiet && exit 0

if [ -n "$file" ]; then
  msg="Auto: update $file"
else
  msg="Auto: update project files"
fi

git commit -q -m "$msg" || exit 0
git push -q -u origin HEAD 2>&1 || echo "auto-commit: push failed" >&2
exit 0
