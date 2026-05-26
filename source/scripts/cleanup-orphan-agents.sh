#!/bin/bash
# cleanup-orphan-agents.sh
#
# Find and (optionally) terminate orphaned AI agent CLI processes that
# have been adopted by launchd (ppid == 1) after their owning terminal
# closed. These processes typically pile up over weeks of usage, holding
# memory and occasionally network sockets, without the user knowing.
#
# This is the standalone version of the same logic that AINotchIsland's
# OrphanAgentCleaner runs once per day. You can invoke it manually any
# time to inspect or force-clean.
#
# Usage:
#   cleanup-orphan-agents.sh                # dry-run, list candidates
#   cleanup-orphan-agents.sh --force        # actually kill (SIGTERM → SIGKILL)
#   cleanup-orphan-agents.sh --min-age 60   # only kill if alive > 60 minutes
#   cleanup-orphan-agents.sh --json         # machine-readable output

set -u

FORCE=0
MIN_AGE_MIN=60   # don't kill anything younger than this — a freshly-launched
                 # daemon agent (e.g. hermes gateway) should not be reaped
JSON=0

usage() {
  cat <<EOF
Usage: $0 [--force] [--min-age MINUTES] [--json]

  --force            actually terminate matched processes (default is dry-run)
  --min-age N        skip processes whose elapsed time < N minutes (default 60)
  --json             emit results as JSON instead of human text
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift;;
    --min-age) MIN_AGE_MIN=$2; shift 2;;
    --json) JSON=1; shift;;
    -h|--help) usage 0;;
    *) echo "Unknown arg: $1" >&2; usage 1;;
  esac
done

# Process-name patterns per agent. Mirror the registry the app uses so
# both sides agree on what counts as an "agent".
patterns=(
  '\bclaude\b'
  '/claude($| )'
  'node .*/\.npm-global/bin/claude'
  '\bcodex\b'
  '\bmimo\b'
  'node .*/\.npm-global/bin/mimo'
  'hermes_cli'
  '/hermes($| )'
  'kiro-cli'
  'kiro_cli'
  'openclaw'
  '\baider\b'
  '\bgemini\b'
)

# Build one big regex. macOS ps + bash regex use BRE/ERE — we feed grep -E.
joined_pattern=$(IFS='|'; echo "${patterns[*]}")

# `ps` columns: pid ppid etime command. etime is [[dd-]hh:]mm:ss.
candidates=$(ps -eo pid=,ppid=,etime=,command= | grep -E "$joined_pattern" | grep -v 'grep -E' || true)

# Exclude things that are NOT real agent CLIs:
# - our own bridges (short-lived, harmless)
# - the app itself
# - helper / electron / extension processes
exclude_re='agent-halo-bridge|AINotch Island|Helper|helper|app-server|extension-host|Gemini Helper|Cursor Helper|Chrome|Electron Framework|tui\.js|kiro_cli_desktop|sourcekit-lsp|Sparkle'
candidates=$(echo "$candidates" | grep -vE "$exclude_re" || true)

# Service-mode processes are intentionally long-running daemons (hermes
# gateway, codex app-server, mimo MCP server). They look like "orphans"
# (ppid == 1) but are actively used. Identify them by tell-tale CLI flags
# and skip them — killing these would break running tools.
service_re='gateway run|--listen stdio|--listen tcp|--port [0-9]|--daemon|gateway --|app-server|--replace|^openclaw|openclaw-gateway|hermes_cli.*gateway|hermes.*gateway'

# Convert etime "dd-hh:mm:ss" / "hh:mm:ss" / "mm:ss" → seconds.
etime_to_sec() {
  local e=$1
  local d=0 h=0 m=0 s=0
  if [[ $e == *-* ]]; then
    d=${e%%-*}; e=${e#*-}
  fi
  IFS=: read -r -a parts <<<"$e"
  case ${#parts[@]} in
    3) h=${parts[0]}; m=${parts[1]}; s=${parts[2]};;
    2) m=${parts[0]}; s=${parts[1]};;
    1) s=${parts[0]};;
  esac
  # strip leading zeros so bash arithmetic doesn't treat them as octal
  d=$((10#$d)); h=$((10#$h)); m=$((10#$m)); s=$((10#$s))
  echo $(( d*86400 + h*3600 + m*60 + s ))
}

min_age_sec=$((MIN_AGE_MIN * 60))
declare -a victims=()
declare -a victim_meta=()

while IFS= read -r line; do
  [[ -z $line ]] && continue
  # Parse: pid ppid etime command (command may contain spaces)
  read -r pid ppid etime cmd <<< "$line"
  # Re-extract command — bash read with default IFS handles this if we add
  # enough fields, but commands have spaces; use parameter expansion:
  rest=${line#*$etime }
  cmd=$rest

  # ORPHAN test: ppid == 1 (launchd-adopted).
  [[ $ppid -eq 1 ]] || continue

  # SERVICE-MODE skip: looks like a daemon the user wants kept alive.
  if [[ $cmd =~ $service_re ]]; then
    continue
  fi

  age_sec=$(etime_to_sec "$etime")
  if [[ $age_sec -lt $min_age_sec ]]; then
    continue
  fi

  victims+=("$pid")
  victim_meta+=("$pid|$etime|$cmd")
done <<< "$candidates"

count=${#victims[@]}

if [[ $JSON -eq 1 ]]; then
  printf '{"count":%d,"force":%s,"victims":[' "$count" "$([[ $FORCE -eq 1 ]] && echo true || echo false)"
  first=1
  for meta in "${victim_meta[@]}"; do
    IFS='|' read -r pid etime cmd <<< "$meta"
    [[ $first -eq 1 ]] || printf ','
    first=0
    cmd_escaped=${cmd//\"/\\\"}
    printf '{"pid":%d,"etime":"%s","command":"%s"}' "$pid" "$etime" "$cmd_escaped"
  done
  printf ']}\n'
else
  if [[ $count -eq 0 ]]; then
    echo "No orphan agents found (min age: ${MIN_AGE_MIN}m)."
    exit 0
  fi
  echo "Found $count orphan agent process(es) older than ${MIN_AGE_MIN}m:"
  for meta in "${victim_meta[@]}"; do
    IFS='|' read -r pid etime cmd <<< "$meta"
    printf "  pid=%-7s age=%-14s %s\n" "$pid" "$etime" "$cmd"
  done
fi

[[ $FORCE -eq 1 ]] || { [[ $JSON -eq 0 ]] && echo "" && echo "(dry-run: pass --force to actually terminate)"; exit 0; }

# Two-stage termination: SIGTERM first (graceful), then SIGKILL for holdouts.
for pid in "${victims[@]}"; do
  kill -TERM "$pid" 2>/dev/null || true
done
sleep 3
for pid in "${victims[@]}"; do
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null || true
  fi
done

# Final report
if [[ $JSON -eq 0 ]]; then
  killed=0
  for pid in "${victims[@]}"; do
    if ! kill -0 "$pid" 2>/dev/null; then
      killed=$((killed+1))
    fi
  done
  echo ""
  echo "Terminated $killed / $count (survivors may need manual intervention)."
fi
