#!/bin/bash
# Test event sender for Agent Halo socket
# Usage: ./test-event.sh [event_type]
# Sends a test event to verify the socket pipeline works end-to-end

SOCKET="$HOME/.agent-halo/run/agent-halo.sock"
SESSION_ID="test-$(date +%s)"
TIMESTAMP=$(python3 -c "import time; print(time.time())")

EVENT_TYPE="${1:-PreToolUse}"

case "$EVENT_TYPE" in
  session-start)
    PAYLOAD="{\"type\":\"SessionStart\",\"sessionId\":\"$SESSION_ID\",\"timestamp\":$TIMESTAMP,\"agent\":\"claude\",\"payload\":{\"title\":\"Claude Code\",\"terminalApp\":\"Terminal\",\"workingDirectory\":\"$(pwd)\"}}"
    ;;
  session-end)
    PAYLOAD="{\"type\":\"SessionEnd\",\"sessionId\":\"$SESSION_ID\",\"timestamp\":$TIMESTAMP,\"agent\":\"claude\",\"payload\":{\"status\":\"done\"}}"
    ;;
  *)
    PAYLOAD="{\"type\":\"PreToolUse\",\"sessionId\":\"$SESSION_ID\",\"timestamp\":$TIMESTAMP,\"agent\":\"claude\",\"payload\":{\"tool\":\"Bash\",\"command\":\"npm test\",\"workingOn\":\"Bash: npm test\"}}"
    ;;
esac

if [ ! -S "$SOCKET" ]; then
  echo "ERROR: Socket not found at $SOCKET"
  echo "Is AINotchIsland running?"
  exit 1
fi

echo "$PAYLOAD" | nc -U "$SOCKET"
echo "Sent $EVENT_TYPE event (session: $SESSION_ID)"
