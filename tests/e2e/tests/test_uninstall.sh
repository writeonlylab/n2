#!/usr/bin/env bash
# E2E test: uninstallation via tmux
# Installs n2 in playground mode, then runs uninstall.sh and verifies that
# N2 entrance blocks are removed from all dotfiles.

set -euo pipefail

N2_DIR=${N2_DIR:-/n2}
SESSION=n2_uninstall_test
PASS=0
FAIL=0

pass() { echo "PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }

cleanup() {
    tmux kill-session -t "$SESSION" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== test_uninstall.sh ==="

# Start a detached tmux session
tmux new-session -d -s "$SESSION" -x 220 -y 50

# Step 1: Install n2 in playground mode with auto-confirm
tmux send-keys -t "$SESSION" "PLAYGROUND=yes AUTO_CONFIRM=yes bash '$N2_DIR/install.sh' 2>&1; echo 'INSTALL_EXIT_CODE:'\$?" Enter

# Allow time for install to complete
sleep 8

# Capture install output to extract playground directory
INSTALL_OUTPUT=$(tmux capture-pane -t "$SESSION" -p -S -)

echo "--- install output ---"
echo "$INSTALL_OUTPUT"
echo "--- end install output ---"

# Verify install succeeded
if ! echo "$INSTALL_OUTPUT" | grep -q "INSTALL_EXIT_CODE:0"; then
    fail "Install did not exit cleanly"
    echo "Exit status: $FAIL failures out of $((PASS + FAIL)) tests"
    exit 1
fi

# Extract the playground directory
PLAYGROUND_DIR=$(echo "$INSTALL_OUTPUT" | grep -o "Installed to playground dir: [^[:space:]]*" | awk '{print $NF}' | tail -1)

if [ -n "$PLAYGROUND_DIR" ] && [ -d "$PLAYGROUND_DIR" ]; then
    pass "Install: playground directory exists: $PLAYGROUND_DIR"
else
    fail "Install: could not determine playground directory (got: '$PLAYGROUND_DIR')"
    echo "Exit status: $FAIL failures out of $((PASS + FAIL)) tests"
    exit 1
fi

# Verify N2 entrance block is present in .bashrc before uninstall
if grep -q "N2 ENTRANCE BEGIN" "$PLAYGROUND_DIR/.bashrc" 2>/dev/null; then
    pass "Pre-uninstall: .bashrc contains N2 entrance block"
else
    fail "Pre-uninstall: .bashrc missing N2 entrance block (install may have failed)"
    exit 1
fi

# Step 2: Run uninstall with AUTO_CONFIRM=yes
tmux send-keys -t "$SESSION" "AUTO_CONFIRM=yes bash '$N2_DIR/uninstall.sh' 2>&1; echo 'UNINSTALL_EXIT_CODE:'\$?" Enter

# Allow time for uninstall to complete
sleep 5

# Capture full pane output (includes both install and uninstall)
OUTPUT=$(tmux capture-pane -t "$SESSION" -p -S -)

echo "--- uninstall output ---"
echo "$OUTPUT"
echo "--- end uninstall output ---"

# 1. Completion banner appeared
if echo "$OUTPUT" | grep -q "N2 uninstall complete"; then
    pass "Uninstall completion banner appeared"
else
    fail "Uninstall completion banner not found"
fi

# 2. Uninstall exited cleanly
if echo "$OUTPUT" | grep -q "UNINSTALL_EXIT_CODE:0"; then
    pass "Uninstall exited with code 0"
else
    fail "Uninstall did not exit cleanly"
fi

# 3. Verify N2 entrance blocks are removed from all dotfiles
for dotfile in .bashrc .bash_profile .vimrc .tmux.conf .gitconfig; do
    filepath="$PLAYGROUND_DIR/$dotfile"
    if [ ! -f "$filepath" ]; then
        # File was removed entirely — acceptable when content was only the N2 block
        pass "$dotfile: removed (was empty after N2 block removal)"
    elif grep -q "N2 ENTRANCE BEGIN" "$filepath" 2>/dev/null; then
        fail "$dotfile: still contains N2 entrance block after uninstall"
    else
        pass "$dotfile: N2 entrance block removed"
    fi
done

# 4. If .bashrc still exists, it must be non-empty
if [ -f "$PLAYGROUND_DIR/.bashrc" ]; then
    if [ -s "$PLAYGROUND_DIR/.bashrc" ]; then
        pass ".bashrc exists and is non-empty after uninstall"
    else
        fail ".bashrc exists but is empty after uninstall (should have been removed)"
    fi
fi

echo
echo "Results: $PASS passed, $FAIL failed"

[ "$FAIL" -eq 0 ] || exit 1
echo "All uninstall tests passed!"
