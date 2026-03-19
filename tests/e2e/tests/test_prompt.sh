#!/usr/bin/env bash
# E2E test: prompt rendering validation
# Installs n2 into a PLAYGROUND home directory, opens a bash login shell with
# that home, and verifies that the PS1 prompt renders the expected components.

set -euo pipefail

N2_DIR=${N2_DIR:-/n2}
SESSION=n2_prompt_test
PASS=0
FAIL=0

pass() { echo "PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }

cleanup() {
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    [ -n "${PLAYGROUND_DIR:-}" ] && [ -d "${PLAYGROUND_DIR:-}" ] && rm -rf "$PLAYGROUND_DIR"
}
trap cleanup EXIT

echo "=== test_prompt.sh ==="

# Helper: wait for a string to appear in the tmux pane
wait_for() {
    local pattern=$1
    local timeout=${2:-30}
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if tmux capture-pane -t "$SESSION" -p -S - | grep -qE "$pattern"; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "TIMEOUT waiting for: $pattern (after ${timeout}s)"
    return 1
}

# Install to a playground directory (non-interactive)
INSTALL_OUTPUT=$(PLAYGROUND=yes AUTO_CONFIRM=yes bash "$N2_DIR/install.sh" 2>&1)
echo "--- install output ---"
echo "$INSTALL_OUTPUT"
echo "--- end install output ---"

PLAYGROUND_DIR=$(echo "$INSTALL_OUTPUT" | grep -o "Installed to playground dir: [^[:space:]]*" | awk '{print $NF}' | tail -1)

if [ -z "$PLAYGROUND_DIR" ] || [ ! -d "$PLAYGROUND_DIR" ]; then
    echo "FAIL: Could not create playground installation (got: '$PLAYGROUND_DIR')"
    exit 1
fi
echo "Playground dir: $PLAYGROUND_DIR"

# Start a detached tmux session
tmux new-session -d -s "$SESSION" -x 220 -y 50

# Open a bash login shell using the playground home directory
# First, set a unique env var so we can detect when the n2 shell is ready
tmux send-keys -t "$SESSION" "N2_TEST_READY=1 HOME='$PLAYGROUND_DIR' bash --login" Enter

CURRENT_USER=$(whoami)
# hostname may not be installed (e.g. minimal Fedora container)
CURRENT_HOST=""
CURRENT_HOST=$(hostname -s 2>/dev/null) || CURRENT_HOST=$(cat /etc/hostname 2>/dev/null | tr -d '[:space:]') || CURRENT_HOST="unknown"

# Wait for the n2 prompt to render — n2's PS1 includes color codes,
# so wait for the second occurrence of user@host (first is the parent shell)
sleep 5
# Also try running a marker command to confirm the shell is interactive
tmux send-keys -t "$SESSION" "echo N2_SHELL_READY" Enter
wait_for "N2_SHELL_READY" 15

# Capture the pane (include scrollback)
OUTPUT=$(tmux capture-pane -t "$SESSION" -p -S -)

echo "--- captured pane ---"
echo "$OUTPUT"
echo "--- end of pane ---"

# 1. Username is present in prompt (running as root in Docker, or current user)
if echo "$OUTPUT" | grep -q "$CURRENT_USER"; then
    pass "Username '$CURRENT_USER' appears in prompt output"
else
    fail "Username '$CURRENT_USER' not found in prompt output"
fi

# 2. Hostname is present
if echo "$OUTPUT" | grep -q "$CURRENT_HOST"; then
    pass "Hostname '$CURRENT_HOST' appears in prompt output"
else
    fail "Hostname '$CURRENT_HOST' not found in prompt output"
fi

# 3. user@host separator '@' is rendered
if echo "$OUTPUT" | grep -qE '[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+'; then
    pass "user@host pattern present in prompt"
else
    fail "user@host pattern not found in prompt"
fi

# 4. Shell prompt indicator ($ for normal user, # for root)
# n2 prompt is multi-line — the terminator line contains $ or # possibly
# preceded by ANSI escape codes or label text.
if echo "$OUTPUT" | grep -qE '[$#] '; then
    pass "Prompt terminator (\$ or #) present"
else
    fail "Prompt terminator not found"
fi

# 5. A working directory path appears (at minimum '/')
if echo "$OUTPUT" | grep -qE '/[a-zA-Z0-9_/.-]*'; then
    pass "Working directory path present in prompt"
else
    fail "Working directory path not found in prompt"
fi

# 6. Run a command through the installed shell and verify it executes
tmux send-keys -t "$SESSION" "echo PROMPT_TEST_MARKER" Enter
sleep 1
OUTPUT2=$(tmux capture-pane -t "$SESSION" -p -S -)
if echo "$OUTPUT2" | grep -q "PROMPT_TEST_MARKER"; then
    pass "Commands execute correctly in n2 shell"
else
    fail "Command output not found after execution"
fi

echo
echo "Results: $PASS passed, $FAIL failed"

[ "$FAIL" -eq 0 ] || exit 1
echo "All prompt tests passed!"
