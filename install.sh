#!/bin/zsh
# One-shot installer: builds the menu bar app and installs the background
# refresh job for whoever runs this, on whatever Mac they're on. Safe to
# re-run (idempotent) after a git pull to pick up code changes.
set -uo pipefail
HERE="${0:A:h}"
cd "$HERE" || exit 1

LABEL="com.approvals-widget.refresh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "==> Approvals Widget installer"
echo "    project dir: $HERE"
echo ""

# --- prerequisite checks --------------------------------------------------
ok=1

if ! command -v swift >/dev/null 2>&1; then
  echo "MISSING: Swift toolchain. Run 'xcode-select --install' (Xcode Command Line Tools), then re-run this script."
  ok=0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "MISSING: Claude Code CLI. Install it (see https://docs.claude.com/en/docs/claude-code/overview), run 'claude' once to log in, then re-run this script."
  ok=0
fi

if (( ok == 0 )); then
  echo ""
  echo "Fix the above and re-run ./install.sh"
  exit 1
fi

# A logged-out CLI still exists on disk, so probe it directly rather than
# just checking the binary is present.
if ! claude -p "Reply with exactly the word PONG and nothing else." --output-format text 2>/tmp/approvals_install_authcheck.$$ | grep -q "PONG"; then
  echo "WARNING: 'claude' does not appear to be logged in yet."
  echo "         Run 'claude' interactively and follow the /login flow, then come back."
  cat /tmp/approvals_install_authcheck.$$ 2>/dev/null
fi
rm -f /tmp/approvals_install_authcheck.$$

# --- build the app ---------------------------------------------------------
echo ""
echo "==> Building ApprovalsWidget.app"
./build_app.sh

# --- install the launchd refresh job ---------------------------------------
echo ""
echo "==> Installing background refresh job ($LABEL, every 5 min)"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HERE/refresh.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HERE/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>$HERE/launchd.err.log</string>
</dict>
</plist>
PLIST

launchctl unload -w "$PLIST" >/dev/null 2>&1 || true
launchctl load -w "$PLIST"

echo ""
echo "==> Done."
echo ""
echo "Next steps:"
echo "  1. In a terminal, run 'claude' then '/mcp' and connect Campfire, NetSuite, and Ramp"
echo "     (each person authorizes their OWN connection - see README.md for what's"
echo "     personal vs org-wide per source)."
echo "  2. First data fetch: ./ctl.sh run"
echo "  3. Open the widget:  open ApprovalsWidget.app"
echo "  4. Add it to Login Items: System Settings > General > Login Items > +"
echo "     and select $HERE/ApprovalsWidget.app"
echo ""
echo "Check status any time with: ./ctl.sh status"
