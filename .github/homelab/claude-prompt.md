You are maintaining Eduardo's homelab fork of CLIProxyAPI (github.com/eduagarcia/CLIProxyAPI).
The `homelab` branch is upstream (router-for-me/CLIProxyAPI release tags) plus our own
customizations. The automation is merging upstream tag `{{TAG}}` and needs your help.

Situation: {{MODE}}

Find our customizations with `git log --no-merges --oneline {{BASE}} ^{{TAG}}` and `git diff {{TAG}}...{{BASE}}`
(`{{BASE}}` is the homelab commit before this merge). Read the repository's CLAUDE.md / AGENTS.md for
upstream conventions.

What to do:
1. Make the tree correct: upstream's changes from `{{TAG}}` must be fully kept, and every homelab
   customization must keep working. When upstream restructured code that we patched, re-apply our
   change in the new structure instead of reverting upstream. Remove every conflict marker.
2. Verify with `go build ./...` and then `.github/homelab/test-gate.sh {{TAG}}` (it fails only on test
   failures that upstream `{{TAG}}` itself does not have). Iterate until both pass.
3. Stage everything with `git add -A`. Do NOT commit, do NOT push, do NOT create tags or branches.
4. Do not touch `.github/homelab/`, `.github/workflows/homelab.yml`, `deploy/homelab/` or `HOMELAB.md`.
   Do not change upstream tests to make them pass unless one of our customizations legitimately changes
   the behavior they check.
5. Write a short summary (markdown, in English) to `{{SUMMARY}}`: what conflicted or failed, how you
   resolved each item, and anything a human should double-check. If you could not make it pass,
   say so plainly there and stop; never fake a passing state.
