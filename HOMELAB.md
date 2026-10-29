# Homelab fork

This fork runs CLIProxyAPI on Eduardo's homelab (`docker-nas`, 192.168.1.16, CT 103 on Proxmox NAS).
Upstream is `router-for-me/CLIProxyAPI`; this repo follows its **release tags** automatically.

## Branches

| Branch | What it is |
|--------|------------|
| `homelab` (default) | Upstream release tags merged in, plus our customizations and the automation. This is what runs. |
| `main` | Untouched mirror of the fork point. Not used. |

Our own changes go on `homelab` as normal commits. Keep them small and in separate commits, so merges stay easy to resolve.

## Automation (`.github/workflows/homelab.yml`)

Runs every 4 hours, on demand, and on every push to `homelab`:

1. `sync.sh` merges the latest upstream release tag (or the one you pass) into `homelab`. If `homelab` already has it, the run stops there.
2. `test-gate.sh` builds and runs `go test ./...`. Upstream's own suite has failing and flaky tests at release tags, so the gate only fails on **new** failures (tests that pass on the upstream tag but fail here, after two retries).
3. If the merge conflicts, or a clean merge fails the gate, **Claude Code** runs once (`claude -p`, prompt in `.github/homelab/claude-prompt.md`, auth from the `CLAUDE_CODE_OAUTH_TOKEN` secret). It resolves the conflicts, makes the gate pass and stages the result; the workflow commits it and runs the gate again. Its summary goes to the run summary and its transcript to the `claude-transcript` artifact. Claude never runs on your own pushes: if your push breaks the gate, the run just fails.
4. The image is built and pushed to `ghcr.io/eduagarcia/cliproxyapi:<tag>-hl.<sha>` (and `:latest`).
5. The workflow bumps the `image:` line in `deploy/homelab/docker-compose.yml` and pushes with `[skip ci]`. Portainer polls that file and redeploys.

Any failure opens an issue in this repo and deploys nothing; production keeps the previous image.

Secrets: `HOMELAB_PUSH_TOKEN` (fine-grained PAT for this repo with Contents, Workflows and Issues write; `GITHUB_TOKEN` can't push upstream's workflow changes) and `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`).
Upstream's own workflows (release, Docker Hub, PR guards) are disabled in this fork's Actions settings.

## Common operations

```bash
R=eduagarcia/CLIProxyAPI
gh workflow run homelab.yml -R $R                      # update now to the latest upstream release
gh workflow run homelab.yml -R $R -f tag=v8.0.48       # merge a specific upstream tag
gh workflow run homelab.yml -R $R -f rebuild=true      # rebuild/redeploy without a new release
gh run list -R $R -w homelab.yml -L 5                  # recent runs
gh run view -R $R --log-failed <run-id>                # why a run failed
```

Change the schedule by editing the `cron:` line in the workflow.

**Roll back:** edit `deploy/homelab/docker-compose.yml` to an older tag (list them with
`gh api /user/packages/container/cliproxyapi/versions --jq '.[].metadata.container.tags[]'`) and commit with `[skip ci]` in the message. Portainer picks it up within 5 minutes.
To stop following upstream for a while, disable the workflow: `gh workflow disable homelab.yml -R $R`.

## Runtime on the NAS

- Portainer stack `cliproxyapi` on `https://192.168.1.16:9443`, from this repo (`homelab` branch, `deploy/homelab/docker-compose.yml`), GitOps polling every 5 minutes.
- Data on `/mnt/nas_app/cliproxyapi/`: `config.yaml` (client API keys, management key), `auths/` (OAuth tokens of the logged-in accounts), `logs/`, `plugins/`. None of it is in git.
- API: `http://192.168.1.16:8317` (LAN and tailnet). Management panel: `http://192.168.1.16:8317/management.html`.
- Logging in an account: `docker exec -it cli-proxy-api ./CLIProxyAPI --claude-login --no-browser` (or `--codex-login`, etc.), or use the management panel. The OAuth redirect goes to `localhost:<port>` on the machine with the browser, so tunnel it first: `ssh -L 54545:localhost:54545 root@192.168.1.16` (Claude 54545, Codex 1455, Antigravity 51121).
