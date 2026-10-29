#!/usr/bin/env bash
# Merge an upstream CLIProxyAPI release tag into the current branch (homelab).
# Usage: sync.sh [tag]   (default: the latest upstream release)
# Writes tag, changed and conflict to $GITHUB_OUTPUT. A conflicted merge is left
# in progress (MERGE_HEAD set) so it can be resolved and committed afterwards.
set -euo pipefail
UPSTREAM_REPO="${UPSTREAM_REPO:-router-for-me/CLIProxyAPI}"
out() { echo "$1=$2" >> "${GITHUB_OUTPUT:-/dev/stdout}"; }

tag="${1:-}"
[[ -n "$tag" ]] || tag="$(gh api "repos/$UPSTREAM_REPO/releases/latest" --jq .tag_name)"
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "https://github.com/$UPSTREAM_REPO.git"
git fetch --quiet upstream "+refs/tags/$tag:refs/tags/$tag"
out tag "$tag"

if git merge-base --is-ancestor "$tag" HEAD; then
  echo "homelab already contains $tag"
  out changed false; out conflict false
  exit 0
fi

out changed true
if git merge --no-ff --no-edit -m "chore(sync): merge upstream $tag" "$tag"; then
  out conflict false
else
  echo "::warning::Merging $tag has conflicts in:"
  git diff --name-only --diff-filter=U
  out conflict true
fi
