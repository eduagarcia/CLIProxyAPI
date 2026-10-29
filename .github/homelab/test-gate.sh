#!/usr/bin/env bash
# Upstream's own test suite has failing and flaky tests at release tags, so the
# gate is "no new failures": it fails only on tests that pass on the upstream
# tag but fail here, after retrying each of them twice to filter out flakes.
# Usage: test-gate.sh <upstream-tag>
set -uo pipefail
base_tag="$1"
work="${RUNNER_TEMP:-/tmp}/homelab-gate"
module="$(go list -m)"

echo "== go build ./..."
go build ./... || { echo "::error::build failed"; exit 1; }

# Prints "<package> <TopLevelTest>" per failure, or "<package> -" for a package
# that failed without a failing test (build error, panic, vet).
failures() {
  (cd "$1" && go test -count=1 -json ./... 2>/dev/null) \
    | jq -r 'select(.Action=="fail") | "\(.Package) \((.Test // "-") | split("/")[0])"' \
    | sort -u \
    | awk '{n[$1]++; l[NR]=$0; p[NR]=$1; t[NR]=$2} END {for (i=1;i<=NR;i++) if (t[i]!="-" || n[p[i]]==1) print l[i]}' \
    | sort -u
}

rm -rf "$work"; mkdir -p "$work"
git worktree remove --force "$work/base" 2>/dev/null || true
git worktree add --quiet --detach "$work/base" "$base_tag"
echo "== baseline: tests on $base_tag"
failures "$work/base" > "$work/base.txt"
git worktree remove --force "$work/base"
echo "== tests on HEAD"
failures . > "$work/head.txt"
echo "upstream $base_tag failures: $(wc -l < "$work/base.txt"), HEAD failures: $(wc -l < "$work/head.txt")"

comm -13 "$work/base.txt" "$work/head.txt" > "$work/new.txt"
status=0
while read -r pkg test; do
  [[ -n "$pkg" ]] || continue
  dir="./${pkg#"$module"}"; dir="${dir/#.\/\//./}"
  run=(); [[ "$test" != "-" ]] && run=(-run "^${test}\$")
  ok=0
  for _ in 1 2; do
    if go test -count=1 "${run[@]}" "$dir" >/dev/null 2>&1; then ok=1; break; fi
  done
  if (( ok )); then
    echo "flaky, ignored: $pkg $test"
  else
    echo "::error::new failure: $pkg $test"
    go test -count=1 "${run[@]}" "$dir" 2>&1 | tail -40
    status=1
  fi
done < "$work/new.txt"

(( status == 0 )) && echo "gate passed: no new test failures vs $base_tag"
exit $status
