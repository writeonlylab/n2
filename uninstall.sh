#!/usr/bin/env bash

set -euo pipefail

N2_DIR=$(cd "$(dirname "$0")"; pwd)
INSTALLED_FILES="$N2_DIR/volatile/INSTALLED_FILES"

AUTO_CONFIRM=${AUTO_CONFIRM:-no}

fmt() {
    local p="$1"
    while read -r line; do
        echo -e "\033[${p}m$line\033[0m"
    done
}

confirm() {
    local prompt="$1"
    local default="${2:-Y}"

    if [ "$AUTO_CONFIRM" = yes ]; then
        return 0
    fi

    while :; do
        read -re -p "$prompt [Y/n] [$default] "
        [ -z "$REPLY" ] && REPLY="$default"
        case "$REPLY" in
            Y | y | "") return 0 ;;
            N | n)       return 1 ;;
            *)           echo "Please enter Y or N." ;;
        esac
    done
}

strip_n2_blocks() {
    local file="$1"
    # Matches both bash-style (# === N2 ENTRANCE BEGIN ===)
    # and vim-style (" === N2 ENTRANCE BEGIN ===) markers.
    sed '/[#"] === N2 ENTRANCE BEGIN ===/,/[#"] === N2 ENTRANCE END ===/d' "$file"
}

uninstall_file() {
    local file="$1"

    if [ ! -e "$file" ]; then
        echo "  Skipping (not found): $file"
        return
    fi

    local stripped
    stripped=$(strip_n2_blocks "$file")

    if grep -qF '=== N2 ENTRANCE BEGIN ===' "$file" 2>/dev/null; then
        echo
        echo "File: $(fmt 1 <<< "$file")"
    else
        echo "  No N2 block found, skipping: $file"
        return
    fi

    # Back up before modifying
    local backup="${file}.n2-bak"
    cp "$file" "$backup"
    echo "  Backed up to: $backup"

    if [ -z "$(echo "$stripped" | tr -d '[:space:]')" ]; then
        # File would be empty — remove it
        echo "  File will be empty after cleanup." | fmt 33
        if confirm "  Remove $file entirely?"; then
            rm -f "$file"
            echo "  Removed: $file" | fmt 33
        else
            echo "$stripped" > "$file"
            echo "  Stripped N2 block, kept (now empty/whitespace): $file" | fmt 33
        fi
    else
        echo "$stripped" > "$file"
        echo "  Stripped N2 block from: $file" | fmt 33
    fi
}

main() {
    echo
    echo "-------------------------------------------"
    echo "-- N2 Uninstaller                        --"
    echo "-------------------------------------------"
    echo

    if [ ! -f "$INSTALLED_FILES" ]; then
        echo "No INSTALLED_FILES record found at: $INSTALLED_FILES"
        echo "Nothing to uninstall."
        echo
        exit 0
    fi

    echo "Files modified by N2 install:"
    while read -r line; do
        echo "  * $line"
    done < "$INSTALLED_FILES"

    echo
    confirm "Proceed with automatic cleanup?" || { echo "Aborted."; exit 0; }

    while read -r file; do
        uninstall_file "$file"
    done < "$INSTALLED_FILES"

    # Clear the installed files record
    > "$INSTALLED_FILES"
    echo
    echo "Cleared: $INSTALLED_FILES"

    echo
    if confirm "Remove the N2 directory itself ($N2_DIR)?"; then
        rm -rf "$N2_DIR"
        echo "Removed: $N2_DIR" | fmt 33
    fi

    echo
    echo "-------------------------------------------"
    echo "-- N2 uninstall complete.                --"
    echo "-------------------------------------------"
    echo
}

main
