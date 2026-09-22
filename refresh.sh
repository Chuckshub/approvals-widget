#!/bin/zsh
# Approvals widget snapshot fetcher.
# Campfire/NetSuite have no plain API key on this machine, so headless
# `claude -p` is the only way to reach those MCP connectors from a
# non-interactive script (same architecture as ~/campfire-orderform/monitor).
set -uo pipefail
HERE="${0:A:h}"
cd "$HERE" || exit 1
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
LOG="$HERE/refresh.log"
LOCK="$HERE/.lock"
STATE="$HERE/state.json"
LASTSUCCESS="$HERE/.last_success"

say() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG" }

# single instance
if [[ -d "$LOCK" ]]; then
  if [[ -f "$LOCK/pid" ]] && kill -0 "$(<"$LOCK/pid")" 2>/dev/null; then
    say "SKIP: previous run still active"; exit 0
  fi
  rm -rf "$LOCK"
fi
mkdir "$LOCK" 2>/dev/null || { say "SKIP: could not acquire lock"; exit 0 }
print -r -- $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT INT TERM

say "--- run start ---"

# Ramp connected 2026-09-22 (charlie ran /mcp). Bills-for-approval + bill
# details (for real created_date/bill_url), plus reimbursements-for-approval
# + a reimbursement search (for the reimbursement_link field).
FETCH_OUT="$(mktemp -t approvals_fetch)"
claude -p "$(cat "$HERE/fetch_prompt.txt")" \
      --allowedTools "mcp__claude_ai_Campfire__get_approvals,mcp__claude_ai_NetSuite__ns_runCustomSuiteQL,mcp__claude_ai_Ramp__ramp_get_bills_for_approval,mcp__claude_ai_Ramp__ramp_get_bill_details,mcp__claude_ai_Ramp__ramp_get_reimbursements_for_approval,mcp__claude_ai_Ramp__ramp_search_reimbursements,Bash(date:*)" \
      --output-format text > "$FETCH_OUT" 2>&1
FETCH_RC=$?

# claude -p exits 0 even on failure or empty output, so never trust the exit
# code alone - grep for the literal success sentinel the prompt is told to
# print only as its last line.
if grep -qiE 'OAuth session expired|Failed to authenticate|Invalid API key|run /login' "$FETCH_OUT"; then
  say "ERROR: claude CLI is not authenticated - run 'claude' interactively and /login"
  cat "$FETCH_OUT" >> "$LOG"
  rm -f "$FETCH_OUT"
  exit 1
fi
if grep -q 'AnonymousUser' "$FETCH_OUT"; then
  say "ERROR: a connector lost authorisation ('AnonymousUser') - reauthorise it in claude.ai connector settings"
  cat "$FETCH_OUT" >> "$LOG"
  rm -f "$FETCH_OUT"
  exit 1
fi
if (( FETCH_RC != 0 )) || ! grep -q 'SNAPSHOT_OK' "$FETCH_OUT"; then
  say "ERROR: fetch session failed or missing SNAPSHOT_OK sentinel (exit $FETCH_RC) - leaving state.json untouched"
  cat "$FETCH_OUT" >> "$LOG"
  rm -f "$FETCH_OUT"
  exit 1
fi

# Everything before the sentinel line is the JSON payload.
JSON_TEXT="$(sed '/SNAPSHOT_OK/,$d' "$FETCH_OUT")"

if ! print -r -- "$JSON_TEXT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>>"$LOG"; then
  say "ERROR: fetch output did not parse as valid JSON - leaving state.json untouched"
  cat "$FETCH_OUT" >> "$LOG"
  rm -f "$FETCH_OUT"
  exit 1
fi

TMP_STATE="$(mktemp -t approvals_state)"
print -r -- "$JSON_TEXT" > "$TMP_STATE"
mv -f "$TMP_STATE" "$STATE"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$LASTSUCCESS"
rm -f "$FETCH_OUT"

N_ITEMS="$(python3 -c 'import json; print(len(json.load(open("'"$STATE"'")).get("items", [])))' 2>/dev/null || echo '?')"
say "OK: wrote state.json with $N_ITEMS item(s)"
say "--- run end ---"
