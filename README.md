# Approvals Widget

A macOS menu bar app that shows what's pending **your** approval across
Campfire, NetSuite, and Ramp — bill, journal entry, and reimbursement
approvals, with amount and how long each has been sitting - one tap opens
it in the browser.

<img width="360" alt="menu bar dropdown" src="docs/screenshot.png" />

## How it works

There's no plain API key for Campfire or NetSuite on a normal laptop, and
scripting Ramp's MCP connector the same way is the simplest way to keep one
codepath for all three. So a background job runs headless `claude -p`
(the Claude Code CLI, non-interactively) every 5 minutes to call each
service's MCP tools and write a JSON snapshot (`state.json`). The menu bar
app (SwiftUI) just reads that file and re-renders every 60 seconds - it has
no network access or credentials of its own.

```
launchd (every 5 min)
   -> refresh.sh
        -> claude -p (headless, using YOUR Claude Code login + YOUR
                       connected MCP connectors)
             -> Campfire get_approvals
             -> NetSuite SuiteQL (pending journal entries)
             -> Ramp bills/reimbursements pending your approval
        -> writes state.json (atomic, never overwrites good data on failure)
   -> ApprovalsWidget.app reads state.json, shows it in the menu bar
```

## Install (new machine, new person)

**Prerequisites:**
- macOS 13+
- Xcode Command Line Tools (for `swift`) - install with `xcode-select --install` if `swift --version` fails
- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/overview) installed and logged in (run `claude` once and follow `/login`)

**Steps:**

```sh
git clone <this-repo-url> approvals-widget
cd approvals-widget
./install.sh
```

`install.sh` builds the app, installs the 5-minute background refresh job
(`launchd`), and prints next steps. It's safe to re-run after a `git pull`.

Then, **connect your own data sources** - this is the one manual step, and
it matters who runs it (see "Personal vs. org-wide" below):

```sh
claude
# inside the interactive session:
/mcp
# connect: Campfire, NetSuite, Ramp
```

Each connection is your own OAuth login to that service - nothing is
shared between users, and no credentials live in this repo.

Finally:

```sh
./ctl.sh run              # do one fetch now instead of waiting 5 min
open ApprovalsWidget.app  # launch it
```

Add it to **Login Items** (System Settings → General → Login Items → `+`)
so it starts automatically, pointing at `ApprovalsWidget.app` inside your
clone of this repo.

## Personal vs. org-wide (read this before trusting the numbers)

Not every source is scoped to "just you":

| Source | Scoped to you? | Why |
|---|---|---|
| **Ramp** (bills, reimbursements) | ✅ Yes | Ramp's `_for_approval` tools are explicitly "only items where the authenticated user is the next required approver." |
| **NetSuite** (journal entries) | ❌ No - org-wide | There's no `nextApprover`/approver field exposed via SuiteQL for this account (confirmed: the Employee record lookup 403s under this role, and no approver field appears in the journal entry schema). The widget shows *every* unapproved JE, not just yours. |
| **Campfire** (draft/approval queue) | ❌ No - org-wide | `get_approvals` has no per-approver filter, just an org-wide pending-drafts queue. |

Practically: two people running this will see identical NetSuite/Campfire
rows, but each will see only their own Ramp rows. If your NetSuite role
later gets access to an approval-routing field, tighten the SuiteQL query
in `fetch_prompt.txt` (step 2) to filter on it.

## Control

```sh
./ctl.sh status   # is the job loaded, when did it last succeed, what's pending
./ctl.sh run      # fetch once, right now
./ctl.sh log [n]  # tail refresh.log (last n lines, default 40)
./ctl.sh stop     # unload the launchd job
./ctl.sh start    # (re)load the launchd job
```

## Customizing

- **Refresh interval:** edit `StartInterval` (seconds) in
  `~/Library/LaunchAgents/com.approvals-widget.refresh.plist`, then
  `./ctl.sh stop && ./ctl.sh start`.
- **What's fetched:** `fetch_prompt.txt` is the actual instructions given to
  the headless `claude -p` call each run; `refresh.sh`'s `--allowedTools`
  list must include any new MCP tool you reference there.
- **App icon:** replace `AppIcon.icns` and re-run `./build_app.sh`.
- **Look:** `MenuBarApp/Sources/ApprovalsWidget/ContentView.swift` (SwiftUI,
  glass/vibrancy style) and `Model.swift` (data + formatting).

## Known limitations

- NetSuite deep links use the generic `system.netsuite.com/...` redirect
  pattern (this account's role can't query its own account-id subdomain via
  SuiteQL). Should redirect fine if you're already logged into NetSuite in
  your browser; open an issue if it 404s for your account.
- Campfire currently contributes 0 items whenever nothing is pending, since
  there was nothing pending to sample a real deep-link URL from when this
  was built - `url` will be `null` for Campfire rows until that's verified
  against a live one.
- The refresh job depends on your `claude` CLI session staying logged in.
  If `./ctl.sh status` shows stale data, run `claude` interactively and
  check `/login`.
