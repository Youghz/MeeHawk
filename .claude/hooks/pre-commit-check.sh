#!/usr/bin/env bash
# Pre-commit gate for MeeHawk.
#
# Invoked by the PreToolUse hook in .claude/settings.json whenever a Bash
# command starts with "git commit". Runs `flutter analyze` and
# `flutter test` in the Flutter project (app/). Exits 2 on failure to
# block the commit; exits 0 to let it through.
#
# Stdin is ignored — the `if` filter in settings.json already gates us to
# git-commit commands.

set -u

# Locate the Flutter project (app/) regardless of the session cwd.
if [[ -f "pubspec.yaml" ]]; then
  :
elif [[ -d "app" && -f "app/pubspec.yaml" ]]; then
  cd app
else
  echo "❌ pre-commit-check: cannot find Flutter project (expected app/pubspec.yaml)" >&2
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

# flutter analyze
analyze_output=$(flutter analyze 2>&1)
if [[ $? -ne 0 ]]; then
  fail "flutter analyze found lint issues" "$analyze_output"
fi

# flutter test
test_output=$(flutter test 2>&1)
if [[ $? -ne 0 ]]; then
  fail "flutter test failed" "$test_output"
fi

echo "✅ pre-commit gate: flutter analyze + flutter test passed" >&2
exit 0
