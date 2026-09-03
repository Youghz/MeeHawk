#!/usr/bin/env bash
# Pre-commit gate for MeeHawk.
#
# Invoked by the PreToolUse hook in .claude/settings.json whenever a Bash
# command starts with "git commit". Runs, from the repo root:
#   1. flutter analyze   (app/)
#   2. flutter test      (app/) — includes the Dart side of the parity golden
#   3. pytest            (annotator/) — Dart↔Python parity + helpers
# Exits 2 on failure to block the commit; exits 0 to let it through.
#
# Step 3 is what makes the "keep the Python port in sync" rule enforceable:
# a Dart rule change that was not ported fails here, not in production.
#
# Stdin is ignored — the `if` filter in settings.json already gates us to
# git-commit commands.

set -u

# Locate the repo root regardless of the session cwd.
if [[ -d "app" && -f "app/pubspec.yaml" ]]; then
  repo_root="$PWD"
elif [[ -f "pubspec.yaml" && -d "../app" ]]; then
  repo_root="$(cd .. && pwd)"
else
  echo "❌ pre-commit-check: cannot find repo root (expected app/pubspec.yaml)" >&2
  exit 2
fi

fail() {
  local title="$1"
  local output="$2"
  {
    echo ""
    echo "❌ Commit blocked: $title"
    echo "───────────────────────────────────────────────────────────────"
    echo "$output"
    echo "───────────────────────────────────────────────────────────────"
    echo "Fix the issues above, then re-run your git commit."
  } >&2
  exit 2
}

run() {
  local title="$1"
  shift
  local output
  if ! output=$("$@" 2>&1); then
    fail "$title" "$output"
  fi
}

run "flutter analyze found lint issues" \
  env -C "$repo_root/app" flutter analyze
run "flutter test failed" \
  env -C "$repo_root/app" flutter test

# The Python port only exists on branches that ship annotator/.
if [[ -d "$repo_root/annotator/tests" ]]; then
  if command -v uv >/dev/null 2>&1; then
    run "pytest failed — the Python port drifted from the Dart source of truth (see parity/README.md)" \
      env -C "$repo_root" uv run --quiet pytest -q
  else
    echo "⚠️  uv not found — skipping the Dart↔Python parity test." >&2
  fi
fi

echo "✅ pre-commit gate: flutter analyze + flutter test + pytest passed" >&2
exit 0
