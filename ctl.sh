#!/bin/zsh
# Control the approvals widget's background refresh job.
LABEL="com.approvals-widget.refresh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
HERE="${0:A:h}"
case "${1:-status}" in
  start)   launchctl load -w "$PLIST" && echo "started (every 5 min)";;
  stop)    launchctl unload -w "$PLIST" && echo "stopped";;
  status)  launchctl list | grep -q approvals-widget \
             && { echo "LOADED"; launchctl print gui/$(id -u)/$LABEL 2>/dev/null | grep -Ei 'state =|runs =|run interval'; } \
             || echo "NOT LOADED"
           echo ""
           if [[ -f "$HERE/state.json" ]]; then
             python3 -c "
import json, datetime
d = json.load(open('$HERE/state.json'))
items = d.get('items', [])
gen = d.get('generated_at', '?')
try:
    age_min = (datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(gen.replace('Z','+00:00'))).total_seconds() / 60
    age_str = f'{age_min:.0f} min ago'
except Exception:
    age_str = 'unknown age'
print(f'state.json: {len(items)} pending item(s), generated {gen} ({age_str})')
for it in items:
    print(f\"  - [{it.get('source')}] {it.get('title')}  \${it.get('amount') or 0:,.2f}\")
"
           else
             echo "state.json: none yet - run './ctl.sh run' or wait for the launchd job"
           fi
           if [[ -f "$HERE/.last_success" ]]; then
             echo "last successful refresh: $(cat "$HERE/.last_success")"
           fi;;
  run)     echo "running once..."; "$HERE/refresh.sh"; tail -5 "$HERE/refresh.log";;
  log)     tail -${2:-40} "$HERE/refresh.log";;
  *)       echo "usage: ctl.sh {start|stop|status|run|log [n]}";;
esac
