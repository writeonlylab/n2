#!/bin/bash

set -euo pipefail

N2_DIR=$(cd "$(dirname "$0")"; pwd)
INSTALLED_FILES="$N2_DIR/volatile/INSTALLED_FILES"

N2_ENTRANCE_BEGIN="=== N2 ENTRANCE BEGIN ==="
N2_ENTRANCE_END="=== N2 ENTRANCE END ==="

AUTO_CONFIRM=${AUTO_CONFIRM:-no}

red()  { echo -e "\033[1;31m$1\033[0m"; }
bold() { echo -e "\033[1m$1\033[0m"; }

confirm() {
    if [ "$AUTO_CONFIRM" = yes ]; then
        return 0
    fi
    local prompt="$1"
    read -rp "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Remove lines between N2 ENTRANCE markers (inclusive) from a file.
# Handles both '# ===' (shell/tmux/git) and '" ===' (vim) comment styles.
strip_entrance_block() {
    local file="$1"
    local tmp
    tmp=$(mktemp)

    if ! grep -q "$N2_ENTRANCE_BEGIN" "$file" 2>/dev/null; then
        return 1
    fi

    awk -v begin="$N2_ENTRANCE_BEGIN" -v end="$N2_ENTRANCE_END" '
        index($0, begin) { skip=1; next }
        index($0, end)   { skip=0; next }
        !skip { print }
    ' "$file" > "$tmp"

    # Remove trailing blank lines left behind
    if [ -s "$tmp" ]; then
        # Keep file content but trim trailing newlines to one
        sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp" > "${tmp}.clean"
        mv "${tmp}.clean" "$tmp"
    fi

    mv "$tmp" "$file"
    return 0
}

echo
bold "N2 Uninstaller"
echo

if [ ! -f "$INSTALLED_FILES" ]; then
    echo "No installation record found at: $INSTALLED_FILES"
    echo "N2 may not be installed, or the volatile directory was removed."
    exit 1
fi

# Show what will be cleaned
echo "The following files have N2 entrance blocks:"
echo
modified=()
while read -r file; do
    if [ -f "$file" ] && grep -q "$N2_ENTRANCE_BEGIN" "$file" 2>/dev/null; then
        echo "  * $file"
        modified+=("$file")
    fi
done < "$INSTALLED_FILES"

if [ ${#modified[@]} -eq 0 ]; then
    echo "  (none — entrance blocks already removed)"
    echo
else
    echo
    if ! confirm "Remove N2 entrance blocks from these files?"; then
        echo "Aborted."
        exit 0
    fi

    echo
    for file in "${modified[@]}"; do
        if strip_entrance_block "$file"; then
            echo "  ✓ Cleaned $file"
        fi
    done
    echo
    echo "Entrance blocks removed."
fi

# Offer to remove the N2 directory itself
echo
echo "N2 directory: $N2_DIR"
if confirm "Remove the N2 directory entirely?"; then
    rm -rf "$N2_DIR"
    echo
    bold "N2 has been fully uninstalled."
else
    echo
    echo "N2 entrance blocks removed. Directory kept at: $N2_DIR"
    echo "To finish removal later: rm -rf $N2_DIR"
fi
