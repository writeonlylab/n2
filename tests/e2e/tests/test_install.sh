#!/usr/bin/env bash
# E2E test: installation interaction via tmux
# Tests that install.sh runs interactively, accepts 'A' to auto-confirm all,
# and successfully writes dotfiles to a PLAYGROUND home directory.

set -euo pipefail

N2_DIR=${N2_DIR:-/n2}
SESSION=n2_install_test
PASS=0
FAIL=0

pass() { echo "PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }

cleanup() {
    tmux kill-session -t "$SESSION" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== test_install.sh ==="

# Helper: wait for a string to appear in the tmux pane
wait_for() {
    local pattern=$1
    local timeout=${2:-30}
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if tmux capture-pane -t "$SESSION" -p -S - | grep -q "$pattern"; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "TIMEOUT waiting for: $pattern (after ${timeout}s)"
    return 1
}

# Start a detached tmux session
tmux new-session -d -s "$SESSION" -x 220 -y 50

# Launch install.sh in PLAYGROUND mode (interactive — no AUTO_CONFIRM)
tmux send-keys -t "$SESSION" "PLAYGROUND=yes bash '${N2_DIR}/install.sh'" Enter

# Wait for the first confirmation prompt to actually appear
wait_for "Looks good?" 30

# install.sh uses `read -re -i "Y"` which pre-fills "Y" via readline.
# Give readline extra time to become ready before sending input, then
# send Ctrl-U to clear the pre-filled default and type "A" to auto-confirm all.
sleep 2
tmux send-keys -t "$SESSION" C-u
sleep 0.5
tmux send-keys -t "$SESSION" "A" Enter

# Wait for the install completion banner (not the marker in the typed command).
# "N2 installation complete" appears at the very end of install.sh output.
wait_for "N2 installation complete" 60

# Capture the full pane output
OUTPUT=$(tmux capture-pane -t "$SESSION" -p -S -)

echo "--- captured output ---"
echo "$OUTPUT"
echo "--- end of output ---"

# 1. Banner appeared
if echo "$OUTPUT" | grep -q "N2 installation complete"; then
    pass "Installation banner appeared"
else
    fail "Installation banner not found"
fi

# 2. Playground mode was active
if echo "$OUTPUT" | grep -q "playground mode"; then
    pass "Playground mode banner shown"
else
    fail "Playground mode banner not found"
fi

# 3. Extract the playground directory from the output
PLAYGROUND_DIR=$(echo "$OUTPUT" | grep -o "Installed to playground dir: [^[:space:]]*" | awk '{print $NF}' | tail -1)

if [ -n "$PLAYGROUND_DIR" ] && [ -d "$PLAYGROUND_DIR" ]; then
    pass "Playground directory exists: $PLAYGROUND_DIR"
else
    fail "Could not determine playground directory (got: '$PLAYGROUND_DIR')"
    echo "Exit status: $FAIL failures out of $((PASS + FAIL)) tests"
    exit 1
fi

# 4. Verify each expected dotfile was written
for dotfile in .bashrc .bash_profile .vimrc .tmux.conf .gitconfig; do
    if [ -f "$PLAYGROUND_DIR/$dotfile" ]; then
        pass "$dotfile created in playground dir"
    else
        fail "$dotfile not found in playground dir"
    fi
done

# 5. Verify the N2 entrance markers are present in .bashrc
if grep -q "N2 ENTRANCE BEGIN" "$PLAYGROUND_DIR/.bashrc" 2>/dev/null; then
    pass ".bashrc contains N2 entrance marker"
else
    fail ".bashrc missing N2 entrance marker"
fi

# 6. Verify .bash_profile sources n2's bash/profile
if grep -q "bash/profile" "$PLAYGROUND_DIR/.bash_profile" 2>/dev/null; then
    pass ".bash_profile references bash/profile"
else
    fail ".bash_profile does not reference bash/profile"
fi

echo
echo "Results: $PASS passed, $FAIL failed"

[ "$FAIL" -eq 0 ] || exit 1
echo "All install tests passed!"
